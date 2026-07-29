# KuiklyHapticsPlus 示例

最小可运行的集成示例，演示 `HapticsModule` / `LocalHapticsModule` 的全部能力。

## 依赖

已在 Maven Central 发布，无需任何 token：

```kotlin
// shared / KMP 公共层（提供 API）
implementation("io.github.sofarnobug:kuiklyhapticsplus:0.0.2-2.1.21")

// androidApp / Android 原生实现
implementation("io.github.sofarnobug:kuiklyhapticsplusandroid:0.0.2-2.1.21")
```

仓库源（新建工程默认已包含 `mavenCentral()`）：

```kotlin
dependencyResolutionManagement {
    repositories { mavenCentral() }
}
```

## 在 Kuikly 页面中使用

震动能力通过 `LocalHapticsModule` 提供。宿主 Pager 的 `setContent` 内注入后即可在任意 Composable 获取：

```kotlin
@Page("VibrateDemo")
class VibrateDemoPager : ComposeContainer() {
    override fun willInit() {
        super.willInit()
        setContent {
            CompositionLocalProvider(
                LocalHapticsModule provides HapticsModule(this)
            ) {
                HapticsExample()   // 见 src/.../sample/HapticsExample.kt
            }
        }
    }
}
```

## API 速览

```kotlin
val hm = pager.acquireModule<HapticsModule>(HapticsModule.MODULE_NAME)

hm.vibrate()                                  // 基础短震动
hm.vibrate(durationMs = 200, intensity = 0.8f)// 指定时长 + 强度
hm.haptic("success")                          // 语义化反馈：light/medium/heavy/soft/rigid/selection/success/warning/error
hm.vibratePattern(
    timings = listOf(0, 100, 50, 200),        // 等待/震动 交替（毫秒）
    intensities = listOf(0f, 1f, 0f, 0.6f),
    repeat = false
)
hm.cancel()                                   // 停止震动
hm.isSupported { result -> /* {supported:"1"/"0"} */ }
```

完整示例见 [`src/commonMain/kotlin/com/jlj/kuiklybase/haptics/sample/HapticsExample.kt`](src/commonMain/kotlin/com/jlj/kuiklybase/haptics/sample/HapticsExample.kt)。

## 桥接契约

`MODULE_NAME = "HRVibrateModule"` 在四端必须完全一致。各平台原生层已内置注册，无需手动接线。
