# KuiklyHapticsPlus

跨端手机震动 / 触感反馈 Kuikly Module，仿 [KuiklySensors](https://github.com/Tencent/KuiklySensors) 的 KMP 多模块发布结构，支持 Android / iOS / 鸿蒙 三端独立发布。

- 库名：`KuiklyHapticsPlus`
- Maven 坐标：`io.github.sofarnobug:kuiklyhapticsplus`（KMP 公共层）/ `io.github.sofarnobug:kuiklyhapticsplusandroid`（Android 原生层）
- 源码包名：`com.jlj.kuiklybase.haptics`（含作者缩写 jlj，与 Maven groupId 解耦）
- 桥接名（四端一致）：`HRVibrateModule`
- 分发：发布到 **Maven Central**，开发者免凭证直接 `implementation` 集成

## 模块构成

| 模块 | 平台 | 产物 | 说明 |
| --- | --- | --- | --- |
| `KuiklyHapticsPlus` | KMP 公共层（android/ios/js） | Maven Central `io.github.sofarnobug:kuiklyhapticsplus` | `HapticsModule` + `LocalHapticsModule` |
| `KuiklyHapticsPlusAndroid` | Android 原生 | Maven Central `io.github.sofarnobug:kuiklyhapticsplusandroid` | `KRVibrateModule`（继承 KuiklyRenderBaseModule） |
| `KuiklyHapticsPlusIOS` | iOS 原生 | CocoaPods `KuiklyHapticsPlusIOS` | `HRVibrateModule.h/.m` |
| `KuiklyHapticsPlusOhos` | 鸿蒙原生 | ohpm `@jlj/kuikly-haptics-plus-ohos` | `KRVibrateModule.ets` |

## 能力 API（commonMain）

```kotlin
val hm = pager.acquireModule<HapticsModule>(HapticsModule.MODULE_NAME)

// —— 基础能力（向后兼容）——
hm.vibrate()                                          // 基础短震动
hm.vibrate(durationMs = 200, intensity = 0.8f, sharpness = 0.5f) // 指定时长 + 强度（iOS/鸿蒙支持 sharpness）
hm.haptic("success")                                  // 语义化反馈（字符串入口）
hm.haptic(HapticType.SUCCESS)                         // 语义化反馈（类型安全枚举入口）
hm.vibratePattern(
    timings = listOf(0, 100, 50, 200),                // 等待/震动 交替（毫秒）
    intensities = listOf(0f, 1f, 0f, 0.6f),
    repeat = false
)
hm.cancel()                                           // 停止震动
hm.isSupported { result -> /* {supported:"1"/"0"} */ }

// —— 高级自定义波形引擎 ——
// 每段事件可独立指定 timeMs / durationMs / intensity / sharpness / frequencyHz；
// iOS 通过 Core Haptics 充分释放硬件能力，Android / 鸿蒙按自身能力优雅降级。
hm.play(
    events = listOf(
        HapticEvent.tap(0L, intensity = 0.3f, sharpness = 0.4f),
        HapticEvent.continuous(120L, 200L, intensity = 0.9f, sharpness = 0.2f, frequencyHz = 180f)
    ),
    repeatCount = 0,
    usage = HapticUsage.TOUCH,
    completion = { /* 播放完成回调（iOS 精确，Android / 鸿蒙近似）*/ }
)

// —— 内置罐头触感库（跨端预设，无需调参）——
hm.play(HapticPresets.success)
hm.play(HapticPresets.heartbeat, repeatCount = 3)
hm.play(HapticPresets.sos, repeatCount = 2)

// —— 能力查询 ——
hm.getCapabilities { raw ->
    val caps = HapticCapabilities.fromRaw(raw)
    // caps.supported / caps.supportsAmplitude / caps.supportsPredefined / caps.supportsPattern / caps.maxDurationMs
}
```

Compose 中使用 `LocalHapticsModule`（在容器 Pager 的 `setContent` 内通过 `CompositionLocalProvider` 注入）：

```kotlin
val haptics = LocalHapticsModule.current
haptics.haptic("light")
```

### 内置罐头触感库 `HapticPresets`

跨端一致的命名预设，直接 `haptics.play(HapticPresets.xxx)` 调用，无需自行调参：

`button` / `toggle` / `selection` / `success` / `warning` / `error` / `heartbeat` / `typing` / `notification` / `sos`

> 说明：`play(...)` 的 `completion` 回调为「尽力而为」—— iOS 精确，Android / 鸿蒙为近似（按波形总时长 `postDelayed` / `setTimeout` 触发）。`sharpness` / `frequencyHz` 仅在 iOS / 鸿蒙生效，Android 自动忽略。

## 集成方式

已发布到 **Maven Central**，无需任何 token，直接在依赖处添加 `mavenCentral()` 源即可。

### Android（Maven Central）

`shared/build.gradle.kts`（KMP 公共层，提供 API）：

```kotlin
dependencies {
    implementation("io.github.sofarnobug:kuiklyhapticsplus:0.0.2-2.1.21")
}
```

`androidApp/build.gradle.kts`（Android 原生实现）：

```kotlin
dependencies {
    implementation("io.github.sofarnobug:kuiklyhapticsplusandroid:0.0.2-2.1.21")
}
```

仓库源（通常新建工程已默认包含 `mavenCentral()`）：

```kotlin
dependencyResolutionManagement {
    repositories { mavenCentral() }
}
```

本地验证可先发布到 `mavenLocal`，坐标不变。

### iOS（CocoaPods）

```ruby
pod 'KuiklyHapticsPlusIOS'
```

### 鸿蒙（ohpm）

```bash
ohpm install @jlj/kuikly-haptics-plus-ohos
```

并在 `KuiklyViewDelegate` 的 `getCustomRenderModuleCreatorRegisterMap` 中注册 `KRVibrateModule`。

## 发布

```bash
# 发布到 Maven Central（默认，需 CENTRAL_USERNAME / CENTRAL_PASSWORD 环境变量）
TARGET=central ./publish-maven.sh

# 或发布到 GitHub Packages（自用兜底）
TARGET=github MAVEN_USERNAME=xxx MAVEN_PASSWORD=xxx ./publish-maven.sh
```

iOS Pod / 鸿蒙 HAR 按 `publish-maven.sh` 顶部说明单独发布。

## 桥接契约

`MODULE_NAME = "HRVibrateModule"` 在四端必须完全一致：

- Android 原生类名 / 注册名：`KRVibrateModule` 以同名注册
- iOS 原生类名：`HRVibrateModule`（Kuikly 运行时按类名动态创建）
- 鸿蒙注册名：`KRVibrateModule` 以同名注册

## 许可

MIT
