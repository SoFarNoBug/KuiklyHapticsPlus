/*
 * HapticType.kt
 *
 * 语义化触感类型（类型安全封装）。
 *
 * 与现有 [HapticsModule.haptic] 的字符串入口一一对应，提供枚举入口以避免拼写错误；
 * 同时保留原字符串入口（向后兼容）。
 *
 * 本文件属于独立发布库 KuiklyHapticsPlus（groupId=com.jlj.kuiklybase）。
 */

package com.jlj.kuiklybase.haptics

/**
 * 语义化触感类型。
 *
 * 取值映射原生语义反馈（与 [HapticsModule.haptic] 的字符串入参一致）：
 *  - LIGHT / MEDIUM / HEAVY / SOFT / RIGID：Impact 类（强度/锐度不同）
 *  - SELECTION：选择刻度反馈
 *  - SUCCESS / WARNING / ERROR：Notification 类
 */
public enum class HapticType {
    LIGHT,
    MEDIUM,
    HEAVY,
    SOFT,
    RIGID,
    SELECTION,
    SUCCESS,
    WARNING,
    ERROR;

    /** 映射为 [HapticsModule.haptic] 接受的字符串。 */
    fun toApiString(): String = when (this) {
        LIGHT -> "light"
        MEDIUM -> "medium"
        HEAVY -> "heavy"
        SOFT -> "soft"
        RIGID -> "rigid"
        SELECTION -> "selection"
        SUCCESS -> "success"
        WARNING -> "warning"
        ERROR -> "error"
    }

    public companion object {
        /** 由字符串反查枚举（不区分大小写，未知值回退 [MEDIUM]）。 */
        fun fromApiString(value: String?): HapticType = when (value?.lowercase()) {
            "light" -> LIGHT
            "medium" -> MEDIUM
            "heavy" -> HEAVY
            "soft" -> SOFT
            "rigid" -> RIGID
            "selection" -> SELECTION
            "success" -> SUCCESS
            "warning" -> WARNING
            "error" -> ERROR
            else -> MEDIUM
        }
    }
}
