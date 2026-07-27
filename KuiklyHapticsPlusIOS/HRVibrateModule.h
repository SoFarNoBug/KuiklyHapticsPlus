//
//  HRVibrateModule.h
//  KuiklyHapticsPlusIOS
//
//  手机震动控制模块（iOS 侧 Kuikly 原生 Module 实现）。
//  类名必须精确等于 moduleName（"HRVibrateModule"），Kuikly 运行时按类名动态创建实例，无需显式注册。
//
//  能力映射：
//   - vibrate            -> Core Haptics transient 短震；无 Taptic Engine 时降级 AudioServices 系统短震
//   - vibrateWithDuration-> Core Haptics continuous（精确时长 + 强度）；降级 AudioServices
//   - haptic             -> UIImpact/UINotification/UISelectionFeedbackGenerator 语义反馈；降级 AudioServices
//   - vibratePattern     -> Core Haptics 多事件序列（repeat 时走 AdvancedPatternPlayer 循环）
//   - cancel             -> 停止并释放 CHHapticEngine
//   - isSupported        -> CHHapticEngine.capabilitiesForHardware.supportsHaptics 回调 "1"/"0"
//
//  注意：iOS 12 及以下设备无 Core Haptics，统一降级为 AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)。
//  本文件属于独立发布库 KuiklyHapticsPlusIOS（待联调，无本地 iOS 编译环境）。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <OpenKuiklyIOSRender/KRBaseModule.h>

NS_ASSUME_NONNULL_BEGIN

@interface HRVibrateModule : KRBaseModule

@end

NS_ASSUME_NONNULL_END
