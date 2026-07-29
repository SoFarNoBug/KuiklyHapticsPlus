/*
 * HapticEvent.kt
 *
 * 高级波形引擎 [HapticsModule.play] 的基本事件单元（纯数据，无平台代码）。
 *
 * 三端统一表达，原生侧按自身能力降级：
 *  - Android 仅使用 timeMs / durationMs / intensity（映射 amplitude），忽略 sharpness / frequency。
 *  - iOS / 鸿蒙 使用全部字段（sharpness / frequency 生效）。
 *
 * 本文件属于独立发布库 KuiklyHapticsPlus（groupId=com.jlj.kuiklybase）。
 */

package com.jlj.kuiklybase.haptics

import com.tencent.kuikly.core.nvi.serialization.json.JSONObject

/**
 * 单个触感事件。
 *
 * @param timeMs 相对起始时间（毫秒），事件在时间轴上的起点。
 * @param durationMs 震动持续时长（毫秒）。0 表示瞬态点触（tap），>0 表示持续段。
 * @param intensity 归一化强度 0~1（默认 1）。
 * @param sharpness 锐度 0~1（默认 0.5），仅 iOS / 鸿蒙有效，Android 忽略。
 * @param frequencyHz 频率（Hz），仅 iOS / 鸿蒙有效，Android 忽略；0 表示使用默认频率。
 */
public data class HapticEvent(
    val timeMs: Long = 0L,
    val durationMs: Long = 0L,
    val intensity: Float = 1f,
    val sharpness: Float = 0.5f,
    val frequencyHz: Float = 0f
) {
    /** 序列化为原生侧约定的 JSON（字段 time / duration / intensity / sharpness / frequency）。 */
    fun toJson(): JSONObject = JSONObject().apply {
        put(KEY_TIME, timeMs)
        put(KEY_DURATION, durationMs)
        put(KEY_INTENSITY, intensity)
        put(KEY_SHARPNESS, sharpness)
        put(KEY_FREQUENCY, frequencyHz)
    }

    public companion object {
        const val KEY_TIME = "time"
        const val KEY_DURATION = "duration"
        const val KEY_INTENSITY = "intensity"
        const val KEY_SHARPNESS = "sharpness"
        const val KEY_FREQUENCY = "frequency"

        /** 便捷构造瞬态点触（tap）。 */
        fun tap(
            timeMs: Long,
            intensity: Float = 1f,
            sharpness: Float = 0.5f,
            frequencyHz: Float = 0f
        ): HapticEvent = HapticEvent(
            timeMs = timeMs,
            durationMs = 0L,
            intensity = intensity,
            sharpness = sharpness,
            frequencyHz = frequencyHz
        )

        /** 便捷构造持续震动段。 */
        fun continuous(
            timeMs: Long,
            durationMs: Long,
            intensity: Float = 1f,
            sharpness: Float = 0.5f,
            frequencyHz: Float = 0f
        ): HapticEvent = HapticEvent(
            timeMs = timeMs,
            durationMs = durationMs,
            intensity = intensity,
            sharpness = sharpness,
            frequencyHz = frequencyHz
        )
    }
}
