/*
 * KRVibrateModule.kt
 *
 * 安卓侧手机震动 / 触感反馈控制模块（Kuikly 原生 Module 实现）。
 *
 * 与 commonMain 的 [HapticsModule]（moduleName = "HRVibrateModule"）桥接，
 * 在 KuiklyRenderActivity 的 registerExternalModule 中以同名注册。
 *
 * 能力映射：
 *  - vibrate / vibrateWithDuration：VibrationEffect.createOneShot（API26+），低版本回退 vibrate(long)
 *  - haptic：VibrationEffect.createPredefined（API29+），低版本回退短震
 *  - vibratePattern：主线程 Handler 顺序消费 timings，奇数位独立单发、偶数位仅等待（替代 createWaveform，规避厂商 HAL 对 OFF 间隙的合并）
 *  - cancel：Vibrator.cancel()
 *  - isSupported：Vibrator.hasVibrator()
 *  - play：按事件序列构建 createWaveform（API26+），低版本回退 vibrate(long[], int[], int)；sharpness/frequency 忽略
 *  - getCapabilities：探测 hasVibrator / hasAmplitudeControl / 各 API 级别能力
 *
 * 说明：
 *  - 强度 0~1 映射为 amplitude 1~255（DEFAULT_AMPLITUDE = -1 表示按系统默认）。
 *  - 震动力度控制需硬件支持 hasAmplitudeControl()，否则系统忽略 amplitude。
 *
 * 本文件属于独立发布库 KuiklyHapticsPlusAndroid（groupId=com.jlj.kuiklybase）。
 */

package com.jlj.kuiklybase.haptics.android

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import com.tencent.kuikly.core.render.android.export.KuiklyRenderBaseModule
import com.tencent.kuikly.core.render.android.export.KuiklyRenderCallback
import org.json.JSONArray
import org.json.JSONObject

public class KRVibrateModule : KuiklyRenderBaseModule() {

    override fun call(method: String, params: String?, callback: KuiklyRenderCallback?): Any? {
        return try {
            when (method) {
                METHOD_VIBRATE -> {
                    vibrate(params)
                    null
                }
                METHOD_VIBRATE_WITH_DURATION -> {
                    vibrateWithDuration(params, callback)
                    null
                }
                METHOD_HAPTIC -> {
                    haptic(params)
                    null
                }
                METHOD_VIBRATE_PATTERN -> {
                    vibratePattern(params)
                    null
                }
                METHOD_PLAY -> {
                    play(params, callback)
                    null
                }
                METHOD_GET_CAPABILITIES -> {
                    getCapabilities(callback)
                    null
                }
                METHOD_CANCEL -> {
                    cancel()
                    null
                }
                METHOD_IS_SUPPORTED -> {
                    callback?.invoke(mapOf("supported" to if (isSupported()) "1" else "0"))
                    null
                }
                else -> {
                    callback?.invoke(mapOf("code" to -1, "message" to "method not found: $method"))
                    null
                }
            }
        } catch (e: Exception) {
            // P2-4：防止参数解析/震动调用异常导致崩溃
            callback?.invoke(mapOf("code" to -2, "message" to (e.message ?: "unknown error")))
            null
        }
    }

    private fun getVibrator(): Vibrator? {
        val ctx = context ?: return null
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = ctx.getSystemService(VibratorManager::class.java)
            vm?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            ctx.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    private fun vibrate(params: String?) {
        val vibrator = getVibrator() ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(
                VibrationEffect.createOneShot(
                    DEFAULT_DURATION_MS.toLong(),
                    VibrationEffect.DEFAULT_AMPLITUDE
                )
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(DEFAULT_DURATION_MS.toLong())
        }
    }

    private fun vibrateWithDuration(params: String?, callback: KuiklyRenderCallback?) {
        val vibrator = getVibrator() ?: return
        val json = JSONObject(params ?: "{}")
        val duration = json.optLong("duration", DEFAULT_DURATION_MS.toLong())
        val intensity = json.optDouble("intensity", 1.0).toFloat().coerceIn(0f, 1f)
        val usage = if (json.has("usage")) json.optString("usage") else null
        val amplitude = if (intensity <= 0f) {
            VibrationEffect.DEFAULT_AMPLITUDE
        } else {
            (intensity * 255f).toInt().coerceIn(1, 255)
        }
        // P1-2：API33+ 透传 usage 至 VibrationAttributes，低于 S 直接单发
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val effect = VibrationEffect.createOneShot(duration, amplitude)
            val attrs = VibrationAttributes.Builder().setUsage(mapUsage(usage)).build()
            vibrator.vibrate(effect, attrs)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(duration, amplitude))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(duration)
        }
        // completion 近似：主线程延迟 duration 后回调
        if (callback != null) {
            ensureHandler().postDelayed({ callback.invoke(mapOf("completed" to "1")) }, duration)
        }
    }

    private fun mapUsage(usage: String?): Int {
        return when (usage) {
            "alarm" -> VibrationAttributes.USAGE_ALARM
            "media" -> VibrationAttributes.USAGE_MEDIA
            "notification" -> VibrationAttributes.USAGE_NOTIFICATION
            "ringtone" -> VibrationAttributes.USAGE_RINGTONE
            "communication" -> VibrationAttributes.USAGE_COMMUNICATION_REQUEST
            "game" -> gameUsageValue()
            else -> VibrationAttributes.USAGE_TOUCH
        }
    }

    // USAGE_GAME 自 API34 才引入，编译 SDK 为 33 时无该符号，用反射获取以兼容
    private fun gameUsageValue(): Int {
        return try {
            VibrationAttributes::class.java.getField("USAGE_GAME").getInt(null)
        } catch (e: Exception) {
            VibrationAttributes.USAGE_TOUCH
        }
    }

    private fun haptic(params: String?) {
        val vibrator = getVibrator() ?: return
        val json = JSONObject(params ?: "{}")
        val type = json.optString("type", "medium")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val effectId = when (type) {
                "light", "selection" -> VibrationEffect.EFFECT_TICK
                "heavy" -> VibrationEffect.EFFECT_HEAVY_CLICK
                "success", "warning", "error" -> VibrationEffect.EFFECT_DOUBLE_CLICK
                else -> VibrationEffect.EFFECT_CLICK
            }
            vibrator.vibrate(VibrationEffect.createPredefined(effectId))
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(
                VibrationEffect.createOneShot(
                    DEFAULT_DURATION_MS.toLong(),
                    VibrationEffect.DEFAULT_AMPLITUDE
                )
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(DEFAULT_DURATION_MS.toLong())
        }
    }

    // 多段波形调度：用主线程 Handler 逐段消费 timings，奇数位独立单发、偶数位仅等待。
    // 替代 VibrationEffect.createWaveform（其 OFF 间隙常被厂商 HAL 吞掉，多段被捏成一段）。
    @Volatile
    private var patternToken = 0
    private var patternHandler: Handler? = null

    private fun ensureHandler(): Handler {
        if (patternHandler == null) {
            patternHandler = Handler(Looper.getMainLooper())
        }
        return patternHandler!!
    }

    private fun vibratePattern(params: String?) {
        val vibrator = getVibrator() ?: return
        val json = JSONObject(params ?: "{}")
        val timingsJson = json.optJSONArray("timings") ?: JSONArray()
        val intensitiesJson = json.optJSONArray("intensities")
        // 双兼容：commonMain 发送整数 1，旧逻辑用 optBoolean 误判为 false；此处同时兼容整数与布尔
        val repeat = json.optInt("repeat", 0) == 1 || json.optBoolean("repeat", false)
        val usage = if (json.has("usage")) json.optString("usage") else null
        val n = timingsJson.length()
        if (n == 0) return
        val timings = LongArray(n)
        val amplitudes = IntArray(n)
        for (i in 0 until n) {
            timings[i] = timingsJson.optLong(i, 0L)
            val inten = intensitiesJson?.optDouble(i, 1.0)?.toFloat()?.coerceIn(0f, 1f) ?: 1f
            amplitudes[i] = if (inten <= 0f) {
                VibrationEffect.DEFAULT_AMPLITUDE
            } else {
                (inten * 255f).toInt().coerceIn(1, 255)
            }
        }
        // P2-2 守卫：全 0 波形若循环，会以 0ms 间隔连续投递主线程消息（消息风暴），视为无效循环
        val effectiveRepeat = repeat && timings.sum() > 0L
        val myToken = ++patternToken
        val handler = ensureHandler()
        // 清掉上一条波形残留的调度，避免叠加
        handler.removeCallbacksAndMessages(null)

        // 逐段消费：奇数位=震动段（独立单发），偶数位=静默等待段（仅延迟）
        fun step(idx: Int) {
            if (myToken != patternToken) return // 已被 cancel 或新波形顶替
            if (idx >= n) {
                if (effectiveRepeat) handler.postDelayed({ step(0) }, 0)
                return
            }
            val t = timings[idx]
            if (idx % 2 == 1) {
                if (t > 0) playOneShot(vibrator, t, amplitudes[idx], usage)
                handler.postDelayed({ step(idx + 1) }, t)
            } else {
                handler.postDelayed({ step(idx + 1) }, t)
            }
        }
        // 统一派发到主线程：所有 token 读写与 vibrator 调用收敛到主线程，规避跨线程可见性
        handler.post { step(0) }
    }

    // P2-1：由 vibratePattern 内局部函数提为私有方法，避免每次调用重建闭包
    private fun playOneShot(vibrator: Vibrator, duration: Long, amplitude: Int, usage: String?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && usage != null) {
            val effect = VibrationEffect.createOneShot(duration, amplitude)
            val attrs = VibrationAttributes.Builder().setUsage(mapUsage(usage)).build()
            vibrator.vibrate(effect, attrs)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(duration, amplitude))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(duration)
        }
    }

    private fun cancel() {
        // 使任何运行中的波形退出循环（patternToken 变更 → step 闭包自检失败）
        patternToken++
        patternHandler?.removeCallbacksAndMessages(null)
        getVibrator()?.cancel()
    }

    private fun isSupported(): Boolean {
        return getVibrator()?.hasVibrator() ?: false
    }

    private data class PlayEvent(
        val time: Long,
        val duration: Long,
        val intensity: Float
    )

    private fun play(params: String?, callback: KuiklyRenderCallback?) {
        val vibrator = getVibrator() ?: return
        val json = JSONObject(params ?: "{}")
        val eventsJson = json.optJSONArray("events") ?: JSONArray()
        val repeatCount = json.optInt("repeatCount", 0)
        val usage = if (json.has("usage")) json.optString("usage") else null
        val n = eventsJson.length()
        if (n == 0) return

        val events = ArrayList<PlayEvent>(n)
        for (i in 0 until n) {
            val e = eventsJson.optJSONObject(i) ?: JSONObject()
            val intensity = e.optDouble("intensity", 1.0).toFloat().coerceIn(0f, 1f)
            events.add(
                PlayEvent(
                    time = e.optLong("time", 0L),
                    duration = e.optLong("duration", 0L),
                    intensity = intensity
                )
            )
        }
        events.sortBy { it.time }
        if (events.isEmpty()) return

        // 构建 createWaveform 参数：偶数位=静默，奇数位=震动（与 Android 约定一致）。
        // sharpness / frequency 在 Android 无对应能力，优雅忽略。
        val defaultTapMs = 20L
        val timings = ArrayList<Long>(events.size * 2)
        val amplitudes = ArrayList<Int>(events.size * 2)
        var cursor = 0L
        for (ev in events) {
            val gap = ev.time - cursor
            if (gap > 0) {
                timings.add(gap)
                amplitudes.add(VibrationEffect.DEFAULT_AMPLITUDE)
            }
            val dur = if (ev.duration > 0) ev.duration else defaultTapMs
            val amp = if (ev.intensity <= 0f) {
                VibrationEffect.DEFAULT_AMPLITUDE
            } else {
                (ev.intensity * 255f).toInt().coerceIn(1, 255)
            }
            timings.add(dur)
            amplitudes.add(amp)
            cursor = ev.time + dur
        }
        val totalMs = timings.sum()
        // 守卫：空波形或总时长 0 不播放，避免消息风暴
        if (totalMs <= 0L) return

        val useWaveform = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
        val playOnce: () -> Unit = {
            if (useWaveform) {
                val effect = VibrationEffect.createWaveform(
                    timings.toLongArray(),
                    amplitudes.toIntArray(),
                    -1
                )
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && usage != null) {
                    vibrator.vibrate(
                        effect,
                        VibrationAttributes.Builder().setUsage(mapUsage(usage)).build()
                    )
                } else {
                    vibrator.vibrate(effect)
                }
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(timings.toLongArray(), -1)
            }
        }

        if (repeatCount <= 1) {
            playOnce()
            // completion 近似：主线程延迟 totalMs 后回调
            if (callback != null) {
                ensureHandler().postDelayed({ callback.invoke(mapOf("completed" to "1")) }, totalMs)
            }
        } else {
            val myToken = ++patternToken
            val handler = ensureHandler()
            handler.removeCallbacksAndMessages(null)
            val cycle = totalMs
            fun cycleStep(idx: Int) {
                if (myToken != patternToken) return
                if (idx >= repeatCount) {
                    callback?.invoke(mapOf("completed" to "1"))
                    return
                }
                playOnce()
                handler.postDelayed({ cycleStep(idx + 1) }, cycle)
            }
            handler.post { cycleStep(0) }
        }
    }

    private fun getCapabilities(callback: KuiklyRenderCallback?) {
        val vibrator = getVibrator()
        val supported = vibrator?.hasVibrator() ?: false
        val supportsAmplitude = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                vibrator?.hasAmplitudeControl() ?: false
            } catch (e: Exception) {
                false
            }
        } else {
            false
        }
        val caps = mapOf(
            "supported" to if (supported) "1" else "0",
            "supportsAmplitude" to if (supportsAmplitude) "1" else "0",
            "supportsPredefined" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) "1" else "0",
            "supportsPattern" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) "1" else "0",
            "maxDurationMs" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) "60000" else "0"
        )
        callback?.invoke(caps)
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
        const val DEFAULT_DURATION_MS = 80
    }
}
