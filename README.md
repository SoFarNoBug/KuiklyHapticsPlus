# KuiklyHapticsPlus

跨端手机震动 / 触感反馈 Kuikly Module，仿 [KuiklySensors](https://github.com/Tencent/KuiklySensors) 的 KMP 多模块发布结构，支持 Android / iOS / 鸿蒙 三端独立发布。

- 库名：`KuiklyHapticsPlus`
- groupId：`com.jlj.kuiklybase`（包名含作者缩写 jlj）
- 公共层包：`com.jlj.kuiklybase.haptics`
- 桥接名（四端一致）：`HRVibrateModule`

## 模块构成

| 模块 | 平台 | 产物 | 说明 |
| --- | --- | --- | --- |
| `KuiklyHapticsPlus` | KMP 公共层（android/ios/js） | Maven `com.jlj.kuiklybase:KuiklyHapticsPlus` | `HapticsModule` + `LocalHapticsModule` |
| `KuiklyHapticsPlusAndroid` | Android 原生 | Maven `com.jlj.kuiklybase:KuiklyHapticsPlusAndroid` | `KRVibrateModule`（继承 KuiklyRenderBaseModule） |
| `KuiklyHapticsPlusIOS` | iOS 原生 | CocoaPods `KuiklyHapticsPlusIOS` | `HRVibrateModule.h/.m` |
| `KuiklyHapticsPlusOhos` | 鸿蒙原生 | ohpm `@jlj/kuikly-haptics-plus-ohos` | `KRVibrateModule.ets` |

## 能力 API（commonMain）

```kotlin
val hm = pager.acquireModule<HapticsModule>(HapticsModule.MODULE_NAME)

hm.vibrate()                                  // 基础短震动
hm.vibrate(durationMs = 200, intensity = 0.8f)// 指定时长 + 强度
hm.haptic("success")                          // 语义化反馈：light/medium/heavy/soft/rigid/success/warning/error/selection
hm.vibratePattern(
    timings = listOf(0, 100, 50, 200),        // 等待/震动 交替（毫秒）
    intensities = listOf(0f, 1f, 0f, 0.6f),
    repeat = false
)
hm.cancel()                                   // 停止震动
hm.isSupported { result -> /* {supported:"1"/"0"} */ }
```

Compose 中使用 `LocalHapticsModule`（在容器 Pager 的 `setContent` 内通过 `CompositionLocalProvider` 注入）：

```kotlin
val haptics = LocalHapticsModule.current
haptics.haptic("light")
```

## 集成方式

### Android（Maven）

`shared/build.gradle.kts`（KMP 公共层，提供 API）：

```kotlin
dependencies {
    implementation("com.jlj.kuiklybase:KuiklyHapticsPlus:0.0.1-2.1.21")
}
```

`androidApp/build.gradle.kts`（Android 原生实现）：

```kotlin
dependencies {
    implementation("com.jlj.kuiklybase:KuiklyHapticsPlusAndroid:0.0.1-2.1.21")
}
```

本地验证可先发布到 `mavenLocal`，依赖改为 `mavenLocal()` 源，坐标不变。

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
./publish-maven.sh   # 发布 KMP 公共层 + Android 原生层到 MAVEN_REPO_URL
```

iOS Pod / 鸿蒙 HAR 按 `publish-maven.sh` 顶部说明单独发布。

## 桥接契约

`MODULE_NAME = "HRVibrateModule"` 在四端必须完全一致：

- Android 原生类名 / 注册名：`KRVibrateModule` 以同名注册
- iOS 原生类名：`HRVibrateModule`（Kuikly 运行时按类名动态创建）
- 鸿蒙注册名：`KRVibrateModule` 以同名注册

## 许可

MIT
