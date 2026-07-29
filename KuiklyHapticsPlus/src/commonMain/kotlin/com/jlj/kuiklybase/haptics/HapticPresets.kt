/*
 * HapticPresets.kt
 *
 * 跨端一致的命名触感预设（内置罐头触感库）。
 *
 * 全部以 [HapticEvent] 序列表达，平台无关；通过 [HapticsModule.play] 播放。
 * 各预设在三端均会按自身能力降级（如 Android 忽略 sharpness / frequency），
 * 但相对时间结构与强度意图保持一致，业务侧无需自行调参。
 *
 * 本文件属于独立发布库 KuiklyHapticsPlus（groupId=com.jlj.kuiklybase）。
 */

package com.jlj.kuiklybase.haptics

/**
 * 跨端一致的命名触感预设。
 *
 * 每个预设为一段 [HapticEvent] 序列，配合 [HapticsModule.play] 使用，例如：
 * ```kotlin
 * haptics.play(HapticPresets.success)
 * haptics.play(HapticPresets.heartbeat, repeatCount = 3)
 * ```
 */
public object HapticPresets {

    /** 通用按钮点按：单次轻点。 */
    val button: List<HapticEvent> = listOf(
        HapticEvent.tap(0L, intensity = 0.5f, sharpness = 0.3f)
    )

    /** 开关切换：双脉冲翻转感。 */
    val toggle: List<HapticEvent> = listOf(
        HapticEvent.tap(0L, intensity = 0.85f, sharpness = 0.7f),
        HapticEvent.tap(70L, intensity = 0.85f, sharpness = 0.7f)
    )

    /** 列表/选择器刻度：尖锐短促 tick。 */
    val selection: List<HapticEvent> = listOf(
        HapticEvent.tap(0L, intensity = 0.4f, sharpness = 0.9f)
    )

    /** 操作成功：上扬双段。 */
    val success: List<HapticEvent> = listOf(
        HapticEvent.tap(0L, intensity = 0.5f, sharpness = 0.4f),
        HapticEvent.tap(120L, intensity = 0.9f, sharpness = 0.3f)
    )

    /** 警告：两声中强。 */
    val warning: List<HapticEvent> = listOf(
        HapticEvent.tap(0L, intensity = 0.7f, sharpness = 0.5f),
        HapticEvent.tap(150L, intensity = 0.7f, sharpness = 0.5f)
    )

    /** 错误：一段低沉持续蜂鸣。 */
    val error: List<HapticEvent> = listOf(
        HapticEvent.continuous(0L, 300L, intensity = 0.8f, sharpness = 0.1f)
    )

    /** 心跳：lub-dub 双跳。 */
    val heartbeat: List<HapticEvent> = listOf(
        HapticEvent.tap(0L, intensity = 0.9f, sharpness = 0.5f),
        HapticEvent.tap(180L, intensity = 0.6f, sharpness = 0.4f)
    )

    /** 打字：快速轻点序列。 */
    val typing: List<HapticEvent> = listOf(
        HapticEvent.tap(0L, intensity = 0.4f, sharpness = 0.9f),
        HapticEvent.tap(80L, intensity = 0.4f, sharpness = 0.9f),
        HapticEvent.tap(160L, intensity = 0.4f, sharpness = 0.9f),
        HapticEvent.tap(240L, intensity = 0.4f, sharpness = 0.9f)
    )

    /** 通知：ring-ring 节奏。 */
    val notification: List<HapticEvent> = listOf(
        HapticEvent.tap(0L, intensity = 0.7f, sharpness = 0.5f),
        HapticEvent.tap(200L, intensity = 0.7f, sharpness = 0.5f),
        HapticEvent.tap(400L, intensity = 0.5f, sharpness = 0.4f)
    )

    /**
     * 紧急 SOS：摩斯电码 ···———···（点=100ms，划=300ms，间隔=100ms）。
     * 适合循环播放：[repeatCount] 传大于 0 的值。
     */
    val sos: List<HapticEvent> = listOf(
        // S: · · ·
        HapticEvent.continuous(0L, 100L, intensity = 0.9f, sharpness = 0.3f),
        HapticEvent.continuous(200L, 100L, intensity = 0.9f, sharpness = 0.3f),
        HapticEvent.continuous(400L, 100L, intensity = 0.9f, sharpness = 0.3f),
        // O: — — —
        HapticEvent.continuous(600L, 300L, intensity = 0.9f, sharpness = 0.3f),
        HapticEvent.continuous(1000L, 300L, intensity = 0.9f, sharpness = 0.3f),
        HapticEvent.continuous(1400L, 300L, intensity = 0.9f, sharpness = 0.3f),
        // S: · · ·
        HapticEvent.continuous(1800L, 100L, intensity = 0.9f, sharpness = 0.3f),
        HapticEvent.continuous(2000L, 100L, intensity = 0.9f, sharpness = 0.3f),
        HapticEvent.continuous(2200L, 100L, intensity = 0.9f, sharpness = 0.3f)
    )
}
