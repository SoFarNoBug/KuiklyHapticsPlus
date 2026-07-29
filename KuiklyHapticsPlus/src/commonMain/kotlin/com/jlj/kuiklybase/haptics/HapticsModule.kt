/*
 * HapticsModule.kt
 *
 * 手机震动 / 触感反馈控制模块（跨端）。
 *
 * 设计目标：按 Kuikly Module 机制提供统一的震动控制 API，向业务侧屏蔽
 * Android / iOS / 鸿蒙三端原生震动实现的差异。所有触发类方法均为
 * fire-and-forget（异步、无回调），查询类方法（isSupported）通过异步
 * 回调返回结果。
 *
 * 能力面（取三端官方 API 并集）：
 *  - 基础短震动
 *  - 指定时长 + 强度震动
 *  - 语义化 Haptic 反馈
 *  - 自定义波形节奏（支持循环）
 *  - 停止震动（三端真实停止）
 *  - 设备震动能力查询
 *
 * 约定：
 *  - MODULE_NAME 必须等于各端原生注册名 / 类名（iOS 类名须精确等于 moduleName）。
 *  - 参数统一以 JSONObject / JSONArray 序列化字符串透传，原生侧按同名 JSON key 解析。
 *  - commonMain 禁止书写平台相关代码，禁用 JVM-only API（如 String.format）。
 *
 * 本文件属于独立发布库 KuiklyHapticsPlus（groupId=com.jlj.kuiklybase）。
 */

package com.jlj.kuiklybase.haptics

import com.tencent.kuikly.core.base.toInt
import com.tencent.kuikly.core.module.CallbackFn
import com.tencent.kuikly.core.module.Module
import com.tencent.kuikly.core.nvi.serialization.json.JSONArray
import com.tencent.kuikly.core.nvi.serialization.json.JSONObject

/**
 * 手机震动 / 触感反馈控制模块。
 *
 * 通过 [moduleName] 与原生侧同名 Module 桥接（Android [HRVibrateModule]、
 * iOS [HRVibrateModule]、鸿蒙 [HRVibrateModule]）。
 */
public class HapticsModule : Module() {

    override fun moduleName(): String = MODULE_NAME

    /**
     * 基础短震动：触发系统默认一次短震动（三端行为一致）。
     */
    fun vibrate() {
        callNativeMethod(METHOD_VIBRATE, null)
    }

    /**
     * 指定时长 + 强度震动。
     *
     * @param durationMs 震动时长（毫秒）
     * @param intensity 归一化强度 0~1（默认 1）。
     *  Android 映射 amplitude 1~255；iOS 走 Core Haptics continuous 精确时长；
     *  鸿蒙 time 型目前忽略 intensity（仅按 duration 震动）。
     * @param usage 震动场景（默认 "touch"）：透传至鸿蒙 [VibrateAttribute.usage]
     *  与 Android [VibrationAttributes]（API33+），iOS 忽略。
     */
    fun vibrate(
        durationMs: Int,
        intensity: Float = 1f,
        usage: String = "touch",
        sharpness: Float = 0.5f,
        completion: CallbackFn? = null
    ) {
        val params = JSONObject().apply {
            put(KEY_DURATION, durationMs)
            put(KEY_INTENSITY, intensity)
            put(KEY_USAGE, usage)
            put(KEY_SHARPNESS, sharpness)
        }
        callNativeMethod(METHOD_VIBRATE_WITH_DURATION, params, completion)
    }

    /**
     * 语义化 Haptic 反馈。
     *
     * @param type 取值：light | medium | heavy | soft | rigid | success | warning | error | selection。
     *  三端各自映射到原生语义反馈（Android 预定义效果 / iOS 反馈生成器 / 鸿蒙 preset 效果）。
     */
    fun haptic(type: String) {
        val params = JSONObject().apply {
            put(KEY_TYPE, type)
        }
        callNativeMethod(METHOD_HAPTIC, params)
    }

    /**
     * 语义化 Haptic 反馈（类型安全重载）。
     *
     * @param type [HapticType] 枚举，等价于 [haptic] 的字符串入口，避免拼写错误。
     */
    fun haptic(type: HapticType) {
        haptic(type.toApiString())
    }

    /**
     * 自定义波形节奏。
     *
     * @param timings [等待, 震动, 等待, 震动, ...] 毫秒序列（与 Android 约定一致）。
     * @param intensities 逐段强度 0~1，可选；缺失或不足时该段按默认强度 1 处理。
     * @param repeat 是否循环（默认 false）。
     * @param usage 震动场景（默认 "touch"）。
     */
    fun vibratePattern(
        timings: List<Int>,
        intensities: List<Float>? = null,
        repeat: Boolean = false,
        usage: String = "touch"
    ) {
        val timingArray = JSONArray()
        timings.forEach { timingArray.put(it) }
        val intensityArray = JSONArray()
        if (intensities != null) {
            intensities.forEach { intensityArray.put(it) }
        }
        val params = JSONObject().apply {
            put(KEY_TIMINGS, timingArray)
            put(KEY_INTENSITIES, intensityArray)
            put(KEY_REPEAT, repeat.toInt())
            put(KEY_USAGE, usage)
        }
        callNativeMethod(METHOD_VIBRATE_PATTERN, params)
    }

    /**
     * 停止震动。三端均真实停止当前震动（Android cancel / iOS engine stop / 鸿蒙 stopVibration）。
     */
    fun cancel() {
        callNativeMethod(METHOD_CANCEL, null)
    }

    /**
     * 设备是否支持震动，异步回调结果 {supported:"1"/"0"}。
     */
    fun isSupported(callbackFn: CallbackFn) {
        callNativeMethod(METHOD_IS_SUPPORTED, null, callbackFn)
    }

    /**
     * 高级自定义波形：按 [HapticEvent] 序列精确编排触感。
     *
     * 每段事件可独立指定 timeMs / durationMs / intensity / sharpness / frequencyHz；
     * iOS 通过 Core Haptics 充分释放硬件能力，Android / 鸿蒙按自身能力优雅降级
     * （忽略 sharpness / frequency 等不支持字段）。
     *
     * @param events 事件序列（相对时间轴，毫秒）。
     * @param repeatCount 循环次数（默认 0 = 仅播放一次；>0 表示重复 N 次）。
     * @param usage 震动场景（默认 [HapticUsage.TOUCH]）。
     * @param completion 播放完成回调（尽力而为：iOS 精确，Android / 鸿蒙为近似）。
     */
    fun play(
        events: List<HapticEvent>,
        repeatCount: Int = 0,
        usage: HapticUsage = HapticUsage.TOUCH,
        completion: CallbackFn? = null
    ) {
        val eventArray = JSONArray()
        events.forEach { eventArray.put(it.toJson()) }
        val params = JSONObject().apply {
            put(KEY_EVENTS, eventArray)
            put(KEY_REPEAT_COUNT, repeatCount)
            put(KEY_USAGE, usage.toApiString())
        }
        callNativeMethod(METHOD_PLAY, params, completion)
    }

    /**
     * 查询设备触感能力，异步回调原始结果（JSON / Map）。
     *
     * 可用 [HapticCapabilities.fromRaw] 解析为类型安全对象，例如：
     * ```kotlin
     * hm.getCapabilities { raw -> val caps = HapticCapabilities.fromRaw(raw) }
     * ```
     */
    fun getCapabilities(callbackFn: CallbackFn) {
        callNativeMethod(METHOD_GET_CAPABILITIES, null, callbackFn)
    }

    private fun callNativeMethod(methodName: String, data: JSONObject?) {
        toNative(false, methodName, data?.toString(), null, false)
    }

    private fun callNativeMethod(methodName: String, data: JSONObject?, callbackFn: CallbackFn?) {
        toNative(false, methodName, data?.toString(), callbackFn, false)
    }

    companion object {
        const val MODULE_NAME = "HRVibrateModule"
        const val METHOD_VIBRATE = "vibrate"
        const val METHOD_VIBRATE_WITH_DURATION = "vibrateWithDuration"
        const val METHOD_HAPTIC = "haptic"
        const val METHOD_VIBRATE_PATTERN = "vibratePattern"
        const val METHOD_CANCEL = "cancel"
        const val METHOD_IS_SUPPORTED = "isSupported"
        const val METHOD_PLAY = "play"
        const val METHOD_GET_CAPABILITIES = "getCapabilities"

        const val KEY_DURATION = "duration"
        const val KEY_INTENSITY = "intensity"
        const val KEY_USAGE = "usage"
        const val KEY_TYPE = "type"
        const val KEY_TIMINGS = "timings"
        const val KEY_INTENSITIES = "intensities"
        const val KEY_REPEAT = "repeat"
        const val KEY_EVENTS = "events"
        const val KEY_REPEAT_COUNT = "repeatCount"
        const val KEY_SHARPNESS = "sharpness"
    }
}
