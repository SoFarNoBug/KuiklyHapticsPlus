/*
 * HapticUsage.kt
 *
 * 震动场景类型（类型安全封装）。
 *
 * 透传至原生 VibrationAttributes（Android API33+）/ VibrateAttribute（鸿蒙），
 * iOS 忽略该字段。提供枚举入口以避免拼写错误，同时保留原字符串入口。
 *
 * 本文件属于独立发布库 KuiklyHapticsPlus（groupId=com.jlj.kuiklybase）。
 */

package com.jlj.kuiklybase.haptics

/**
 * 震动场景（类型安全封装）。
 *
 * 透传至原生震动属性（usage），用于区分触摸、闹钟、通知等场景以适配系统策略。
 */
public enum class HapticUsage {
    TOUCH,
    ALARM,
    MEDIA,
    NOTIFICATION,
    RINGTONE,
    COMMUNICATION,
    GAME;

    /** 映射为原生接受的 usage 字符串。 */
    fun toApiString(): String = when (this) {
        TOUCH -> "touch"
        ALARM -> "alarm"
        MEDIA -> "media"
        NOTIFICATION -> "notification"
        RINGTONE -> "ringtone"
        COMMUNICATION -> "communication"
        GAME -> "game"
    }

    public companion object {
        /** 由字符串反查枚举（不区分大小写，未知值回退 [TOUCH]）。 */
        fun fromApiString(value: String?): HapticUsage = when (value?.lowercase()) {
            "alarm" -> ALARM
            "media" -> MEDIA
            "notification" -> NOTIFICATION
            "ringtone" -> RINGTONE
            "communication" -> COMMUNICATION
            "game" -> GAME
            else -> TOUCH
        }
    }
}
