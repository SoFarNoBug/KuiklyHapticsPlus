# @jlj/kuikly-haptics-plus-ohos

Kuikly 跨平台触感 / 震动反馈模块的 **鸿蒙（OpenHarmony / HarmonyOS NEXT）** 原生实现，
与 Kotlin `commonMain` 侧 `HapticsModule`（`moduleName = "HRVibrateModule"`）通过同名 Kuikly Module 桥接，
三端（Android / iOS / OHOS）行为一致。

- 包名：`@jlj/kuikly-haptics-plus-ohos`
- 版本：`2026.7.29-1`
- Module 桥接名：`HRVibrateModule`
- 依赖：`@kuikly-open/render: 2.7.0`
- 适配：HarmonyOS NEXT / API 12+

## 特性

- 基于系统 `@ohos.vibrator`，无需额外权限即可触发基础震动与预设触感。
- 四种能力形态：默认震动、定时长震动、预设触感（haptic）、自定义强弱波形。
- `play` 支持事件驱动的自定义波形（`intensity` / `frequency` 生效），可循环播放。
- `getCapabilities` 返回设备触感能力，便于上层做能力降级。
- 与 Android `Vibrator`、iOS `UIImpactFeedbackGenerator` 三端统一 API。

## 能力映射

所有方法接收 JSON 字符串参数（由 Kuikly Module 机制透传）。

| 方法 | 参数（JSON） | 说明 |
| --- | --- | --- |
| `vibrate` | `{ usage?: string }` | 默认 30ms 震动；`usage` 透传震动场景 |
| `vibrateWithDuration` | `{ duration: number, intensity?: number, usage?: string }` | 指定时长震动（毫秒）。**注意**：鸿蒙 time 型不支持强度，仅按 duration 震动；完成后回调 `{completed:"1"}` |
| `haptic` | `{ type?: string, usage?: string }` | 预设触感（默认 `medium`）：`light` / `medium` / `heavy` / `success` / `warning` / `error` / `selection` |
| `vibratePattern` | `{ timings: number[], intensities?: number[], repeat?: boolean }` | 自定义强弱序列：奇数位=震动段、偶数位=静默段（与 Android 语义一致）；`repeat=true` 循环 |
| `play` | `{ events: {time,duration,intensity,frequency}[], repeatCount?: number }` | 事件驱动波形，单位 ms；`repeatCount>1` 循环，结束后回调 `{completed:"1"}` |
| `cancel` | — | 停止当前震动（含循环定时器） |
| `isSupported` | — | 回调 `{supported:"1"}`（鸿蒙标准设备均支持基础震动） |
| `getCapabilities` | — | 回调 `{supported, supportsAmplitude, supportsPredefined, supportsPattern, maxDurationMs}` |

### `usage` 取值

`unknown` / `alarm` / `ring` / `notification` / `communication` / `touch`（默认）/ `media` / `physicalFeedback` / `simulateReality`

## 集成

### 1. 安装依赖

```bash
ohpm install @jlj/kuikly-haptics-plus-ohos
```

### 2. 注册 Module

在 `KuiklyViewDelegate` 的 `getCustomRenderModuleCreatorRegisterMap` 中以 `"HRVibrateModule"` 为 key 注册：

```typescript
import { KRVibrateModule } from '@jlj/kuikly-haptics-plus-ohos';

getCustomRenderModuleCreatorRegisterMap(): Map<string, () => KuiklyRenderBaseModule> {
  const map = new Map<string, () => KuiklyRenderBaseModule>();
  map.set("HRVibrateModule", () => new KRVibrateModule());
  return map;
}
```

### 3. 业务侧调用（Kotlin commonMain）

Kotlin 侧封装与 API 详见主库
[KuiklyHapticsPlus](https://github.com/SoFarNoBug/KuiklyHapticsPlus)：

```kotlin
HapticsModule.vibrate()                 // 默认 30ms
HapticsModule.haptic(HapticType.Medium) // 预设触感
HapticsModule.play(events)              // 自定义波形
```

## 注意事项

- 鸿蒙 `time` 型震动不接收强度参数，`vibrateWithDuration` 的 `intensity` 会被忽略。
- 自定义波形（`pattern` / `play`）需 API 12+；低版本设备 `supportsPattern` 为 `"0"`。
- 循环震动必须调用 `cancel` 释放，否则定时器持续占用。

## 许可

MIT © 2026 jlj
