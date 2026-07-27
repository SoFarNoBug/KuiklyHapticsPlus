/*
 * LocalHapticsModule.kt
 *
 * 把 [HapticsModule] 以 CompositionLocal 形式提供给 Compose 子树，
 * 便于页面内通过 LocalHapticsModule.current 直接调用震动能力，
 * 无需每次 acquireModule。
 *
 * 注入示例（请在容器 Pager 的 setContent 内）：
 *   CompositionLocalProvider(LocalHapticsModule provides hapticsModule) {
 *       Content()
 *   }
 * 其中 hapticsModule 在 created() 之后通过
 *   val hapticsModule = pager.acquireModule(HapticsModule.MODULE_NAME)
 * 获取。
 *
 * 本文件属于独立发布库 KuiklyHapticsPlus（groupId=com.jlj.kuiklybase）。
 */

package com.jlj.kuiklybase.haptics

import androidx.compose.runtime.compositionLocalOf

public val LocalHapticsModule = compositionLocalOf<HapticsModule> {
    error("LocalHapticsModule 未提供：请在容器 Pager 的 setContent 中通过 CompositionLocalProvider 注入 HapticsModule。")
}
