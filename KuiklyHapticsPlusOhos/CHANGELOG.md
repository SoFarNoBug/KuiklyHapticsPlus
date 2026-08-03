# Changelog

## 2026.7.29-1
- 发布日期：2026-07-29
- 初始鸿蒙 HAR 发布（源码型，artifactType=original）。
- 桥接名 `HRVibrateModule`：`vibrate` / `vibrateWithDuration` / `haptic` / `vibratePattern` / `play` / `cancel` / `isSupported` / `getCapabilities`。

## 0.0.6
- **误判记录（实际为无效改动，已被 0.0.7 取代）**：当时日志中 preset 与回退的 `time` 短震都显示
  `usage:5` / `ret:-1`，误以为 commonMain 的 `haptic()` 传入了 `notification` 用法、在静音下被三态开关拦截，
  故把回退改用 `touch`。但经核对 `commonMain HapticsModule.haptic(type)` **根本不传 usage**，
  OHOS 侧 `resolveUsage(undefined)` 本就解析为 `touch`（NDK 中 `touch` 的枚举值恰为 `5`），
  故 0.0.6 的改动是**空操作**，并未改变运行行为。`usage:5` 即 `touch`，与静音/notification 无关。
- 教训：鸿蒙 NDK 日志的 `usage:N` 是枚举数字，须先确认其枚举映射再下结论；且应读到 commonMain 调用处确认实际传参。

## 0.0.7
- 修复 `haptic()` preset 失败回退的触感丢失问题（真机 Mate 60 Pro / HarmonyOS NEXT 复现）。
- 根因（核华为官方 `errorcode-vibrator`）：preset 与回退的 `time` 短震失败码**均为 `14600101`
  = "Device operation failed"**（NDK 层对 `StartVibratorOnceEnhanced` 记 `ret:-1`，arkts 回调 err.message
  即 "Device operation failed"）。官方定义该错误码成因为 **「HDI 服务异常**或**设备被占用**」**，
  处理建议是「**间隔一段时间重试**」。`haptic()` 在 preset 的错误回调里**立即同线程**发起 `time` 短震，
  常被 HDI 判为「设备被占用」而再次 14600101，导致「preset 失败 + 回退再失败」彻底无触感。
- 修复：回退改用 `vibrateTimeWithRetry`，按指数退避（50/100/200ms）最多重试 3 次；
  `vibrateTime` 增加可选错误回调供重试判断。`haptic` 用法固定 `touch`（语义即 UI 触感反馈）。
- 排查提示：若重试后仍 14600101，则非「设备忙」而是**「触觉管理相关开关被关闭」**（设置>声音和振动>触摸振动/
  系统触感）或 HDF 不可用——属设备设置问题，与应用代码无关；可单独点「基础短震」(`vibrate()`) 验证
  time 短震是否本身可用以区分。

## 0.0.8
- 落实审核 P2 优化（无行为回归，纯重构 + 可配置性）：
  - **P2-1 抽通用重试**：将 `vibrateTimeWithRetry` 泛化为 `startVibrationWithRetry(effect, attr, attempts, delayMs)`，
    `vibrate` / `vibrateWithDuration` / `haptic` 回退三处统一复用，避免各入口在设备忙时一次性失败无回退。
  - **P2-2 haptic usage 可配置**：`haptic()` 的 preset 与回退统一用 `resolveUsage(p["usage"])`（缺省 `touch`），
    支持调用方显式指定 usage（如 `notification`），回退沿用同一 usage，不再硬编码 `touch`。
  - 删除不再使用的 `vibrateTime` / `vibrateTimeWithRetry`，收敛为单一 `startVibrationWithRetry`。

## 0.0.9
- 修复审核反馈的 P2 可选项（无行为回归）：
  - **P2-1 删死变量**：`vibrateWithDuration` 中未使用的 `intensity` / `strength`（鸿蒙 time 型忽略强度）已删除，消除误导。
  - **P2-2 resolveUsage 健壮性**：未知 usage（如 demo 的 `game`，鸿蒙 `vibrator.Usage` 无此枚举）改打 `console.warn` 并降级 `touch`，避免静默降级不透明。
  - **P2-3 全入口重试**：`vibratePattern` / `play` 的 `fire()` 也接入 `startVibrationWithRetry`（2 次、50ms），四入口（vibrate / vibrateWithDuration / haptic 回退 / pattern·play）统一具备设备忙重试能力。

## 0.1.0
- 对齐鸿蒙渲染器版本：依赖 `@kuikly-open/render` 由 `2.7.0` 升到 `2.23.0`，与 shared（KMP core `2.23.0-2.1.21`）主线版本严格一致（官方要求所有平台渲染器版本号必须等于 KMP core 主线版本号，否则运行期崩溃/编译异常）。
- 版本号 `0.0.9` → `0.1.0`（ohpm 已发布版本不可覆盖，故升 minor 后重新打包）；`@jlj/kuikly-haptics-plus-ohos` 消费端（entry）同步切到 `file:./libs/kuikly-haptics-plus-ohos-0.1.0.tgz`。
- 无业务行为变化，仅渲染器基线对齐。
