/*
 * HapticsExample.kt
 *
 * KuiklyHapticsPlus 用法示例（commonMain）。
 *
 * 该文件为「示例代码片段」，演示 HapticsModule / LocalHapticsModule 的全部能力。
 * 直接在 Kuikly Compose 页面的 setContent 作用域内调用即可，无需自行注册 Module
 * （桥接名 HRVibrateModule 已在四端原生层完成注册）。
 */

package com.jlj.kuiklybase.haptics.sample

import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import com.jlj.kuiklybase.haptics.HapticCapabilities
import com.jlj.kuiklybase.haptics.HapticEvent
import com.jlj.kuiklybase.haptics.HapticModule
import com.jlj.kuiklybase.haptics.HapticPresets
import com.jlj.kuiklybase.haptics.HapticType
import com.jlj.kuiklybase.haptics.LocalHapticsModule
import com.tencent.kuikly.compose.foundation.clickable
import com.tencent.kuikly.compose.foundation.layout.Box
import com.tencent.kuikly.compose.foundation.layout.Column
import com.tencent.kuikly.compose.foundation.layout.fillMaxSize
import com.tencent.kuikly.compose.foundation.layout.fillMaxWidth
import com.tencent.kuikly.compose.foundation.layout.padding
import com.tencent.kuikly.compose.material3.Text
import com.tencent.kuikly.compose.ui.Alignment
import com.tencent.kuikly.compose.ui.Modifier
import com.tencent.kuikly.compose.ui.unit.dp

/**
 * 最小可运行示例：在一个 Compose 容器内展示几类震动触发。
 *
 * 用法：
 * 1) 在 shared（KMP 公共层）依赖 `io.github.sofarnobug:kuiklyhapticsplus`
 * 2) 在 Android 原生层依赖 `io.github.sofarnobug:kuiklyhapticsplusandroid`
 * 3) 宿主 Pager 的 setContent 内通过 CompositionLocalProvider 注入 LocalHapticsModule
 *    （参见 sample/README.md 的接入说明）
 */
@Composable
fun HapticsExample() {
    val haptics = LocalHapticsModule.current
    val capText = remember { mutableStateOf("点击「查询能力」") }

    Column(modifier = Modifier.fillMaxSize()) {
        // 1) 基础短震
        HapticsButton("基础短震") { haptics.vibrate() }

        // 2) 语义化触感（字符串入口）
        HapticsButton("成功反馈(String)") { haptics.haptic("success") }
        // 2.1) 语义化触感（类型安全枚举入口）
        HapticsButton("错误反馈(HapticType)") { haptics.haptic(HapticType.ERROR) }

        // 3) 指定时长 + 强度
        HapticsButton("打字按键 (60ms / 0.8)") { haptics.vibrate(durationMs = 60, intensity = 0.8f) }

        // 4) 自定义波形（等待/震动交替，单位 ms）
        HapticsButton("短信通知") {
            haptics.vibratePattern(timings = listOf(0, 90, 130, 90))
        }

        // 5) 高级自定义波形引擎：逐段 intensity / sharpness / frequency
        HapticsButton("自定义渐强波形") {
            haptics.play(
                events = listOf(
                    HapticEvent.tap(0L, intensity = 0.3f, sharpness = 0.4f),
                    HapticEvent.continuous(120L, 200L, intensity = 0.9f, sharpness = 0.2f, frequencyHz = 180f)
                )
            )
        }

        // 6) 内置罐头触感库（跨端预设，无需自行调参）
        HapticsButton("预设：成功") { haptics.play(HapticPresets.success) }
        HapticsButton("预设：心跳 x3") { haptics.play(HapticPresets.heartbeat, repeatCount = 3) }
        HapticsButton("预设：SOS 循环") { haptics.play(HapticPresets.sos, repeatCount = 2) }

        // 7) 循环震动（repeat = true 时需调用 cancel 停止）
        HapticsButton("来电震动(循环)") {
            haptics.vibratePattern(timings = listOf(0, 400, 200, 400), repeat = true)
        }

        // 8) 能力查询（类型安全解析）
        HapticsButton("查询能力") {
            haptics.getCapabilities { raw ->
                val caps = HapticCapabilities.fromRaw(raw)
                capText.value =
                    "supported=${caps.supported} amplitude=${caps.supportsAmplitude} " +
                    "predefined=${caps.supportsPredefined} pattern=${caps.supportsPattern}"
            }
        }
        Text(text = capText.value, modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp))

        // 9) 停止全部震动
        HapticsButton("停止震动") { haptics.cancel() }
    }
}

@Composable
private fun HapticsButton(text: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clickable { onClick() }
            .padding(vertical = 14.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(text = text)
    }
}

/**
 * 非 Compose 上下文（如原生回调、ViewModel）中，可通过 pager 获取 Module：
 *
 * ```kotlin
 * val hm = pager.acquireModule<HapticModule>(HapticModule.MODULE_NAME)
 * hm.vibrate()
 * hm.haptic("success")
 * hm.play(HapticPresets.success)
 * ```
 */
