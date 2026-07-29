/*
 * HapticCapabilities.kt
 *
 * 设备触感能力描述（[HapticsModule.getCapabilities] 回调结果，纯数据，无平台代码）。
 *
 * 原生侧探测后回调 JSON / Map，业务侧可用 [fromRaw] 解析为类型安全对象。
 *
 * 本文件属于独立发布库 KuiklyHapticsPlus（groupId=com.jlj.kuiklybase）。
 */

package com.jlj.kuiklybase.haptics

import com.tencent.kuikly.core.nvi.serialization.json.JSONObject

/**
 * 设备触感能力描述。
 *
 * @param supported 设备是否支持震动 / 触感。
 * @param supportsAmplitude 是否支持按强度调节振幅（Android hasAmplitudeControl）。
 * @param supportsPredefined 是否支持预定义语义效果（Android createPredefined / iOS generator / 鸿蒙 preset）。
 * @param supportsPattern 是否支持自定义波形（波形 API）。
 * @param maxDurationMs 单次震动建议最大时长（毫秒），0 表示未知。
 */
public data class HapticCapabilities(
    val supported: Boolean = false,
    val supportsAmplitude: Boolean = false,
    val supportsPredefined: Boolean = false,
    val supportsPattern: Boolean = false,
    val maxDurationMs: Long = 0L
) {
    public companion object {
        /**
         * 从原生回调的原始结果解析能力（尽力而为）。
         *
         * 兼容 `Map<*, *>` 与 Kuikly `JSONObject` 两种运行时形态（Kuikly 各端回调通常二选一）。
         */
        fun fromRaw(raw: Any?): HapticCapabilities {
            if (raw == null) return HapticCapabilities()
            val get: (String) -> Any? = when {
                raw is Map<*, *> -> { key -> raw[key] }
                raw is JSONObject -> { key -> raw.opt(key) }
                else -> { _ -> null }
            }
            fun bool(key: String): Boolean = when (val v = get(key)) {
                is Boolean -> v
                is Number -> v.toInt() != 0
                is String -> v == "1" || v == "true"
                else -> false
            }
            fun long(key: String): Long = when (val v = get(key)) {
                is Number -> v.toLong()
                is String -> v.toLongOrNull() ?: 0L
                else -> 0L
            }
            return HapticCapabilities(
                supported = bool(KEY_SUPPORTED),
                supportsAmplitude = bool(KEY_SUPPORTS_AMPLITUDE),
                supportsPredefined = bool(KEY_SUPPORTS_PREDEFINED),
                supportsPattern = bool(KEY_SUPPORTS_PATTERN),
                maxDurationMs = long(KEY_MAX_DURATION_MS)
            )
        }

        const val KEY_SUPPORTED = "supported"
        const val KEY_SUPPORTS_AMPLITUDE = "supportsAmplitude"
        const val KEY_SUPPORTS_PREDEFINED = "supportsPredefined"
        const val KEY_SUPPORTS_PATTERN = "supportsPattern"
        const val KEY_MAX_DURATION_MS = "maxDurationMs"
    }
}
