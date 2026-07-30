//
//  HRVibrateModule.m
//  KuiklyHapticsPlusIOS
//
//  手机震动控制模块（iOS 侧 Kuikly 原生 Module 实现）。
//  详细说明见 HRVibrateModule.h。本文件属于独立发布库 KuiklyHapticsPlusIOS（待联调，无本地 iOS 编译环境）。
//

#import "HRVibrateModule.h"
#import <AudioToolbox/AudioToolbox.h>
#import <CoreHaptics/CoreHaptics.h>

@interface HRVibrateModule ()
@property (nonatomic, strong, nullable) CHHapticEngine *hapticEngine;
@property (nonatomic, strong, nullable) NSMutableDictionary<NSNumber *, UIImpactFeedbackGenerator *> *impactGenerators;
@property (nonatomic, strong, nullable) UINotificationFeedbackGenerator *notificationGenerator;
@property (nonatomic, strong, nullable) UISelectionFeedbackGenerator *selectionGenerator;
@end

@implementation HRVibrateModule

#pragma mark - 基础短震动
- (void)vibrate:(NSDictionary *)args {
    [self playTransientWithIntensity:1.0 sharpness:0.5];
}

#pragma mark - 指定时长 + 强度
- (void)vibrateWithDuration:(NSDictionary *)args {
    NSDictionary *params = [args[KR_PARAM_KEY] hr_stringToDictionary];
    NSNumber *d = params[@"duration"];
    NSInteger duration = (d && [d isKindOfClass:[NSNumber class]]) ? [d integerValue] : 30;
    if (duration <= 0) duration = 30;
    NSNumber *i = params[@"intensity"];
    double intensity = (i && [i isKindOfClass:[NSNumber class]]) ? [i doubleValue] : 1.0;
    if (intensity <= 0.0 || intensity > 1.0) intensity = 1.0;
    NSNumber *s = params[@"sharpness"];
    double sharpness = (s && [s isKindOfClass:[NSNumber class]]) ? [s doubleValue] : 0.5;
    if (sharpness < 0.0 || sharpness > 1.0) sharpness = 0.5;
    [self playContinuousWithIntensity:intensity duration:duration / 1000.0 sharpness:sharpness];
}

#pragma mark - 语义反馈
- (void)haptic:(NSDictionary *)args {
    NSDictionary *params = [args[KR_PARAM_KEY] hr_stringToDictionary];
    NSString *type = params[@"type"];
    if (type == nil || [type length] == 0) type = @"medium";

    if (@available(iOS 13.0, *)) {
        if ([type isEqualToString:@"selection"]) {
            [[self selectionGenerator] selectionChanged];
        } else if ([type isEqualToString:@"success"] ||
                   [type isEqualToString:@"warning"] ||
                   [type isEqualToString:@"error"]) {
            UINotificationFeedbackType nType = UINotificationFeedbackTypeSuccess;
            if ([type isEqualToString:@"warning"]) {
                nType = UINotificationFeedbackTypeWarning;
            } else if ([type isEqualToString:@"error"]) {
                nType = UINotificationFeedbackTypeError;
            }
            [[self notificationGenerator] notificationOccurred:nType];
        } else {
            UIImpactFeedbackStyle style = UIImpactFeedbackStyleMedium;
            if ([type isEqualToString:@"light"]) {
                style = UIImpactFeedbackStyleLight;
            } else if ([type isEqualToString:@"heavy"]) {
                style = UIImpactFeedbackStyleHeavy;
            } else if ([type isEqualToString:@"soft"]) {
                style = UIImpactFeedbackStyleSoft;
            } else if ([type isEqualToString:@"rigid"]) {
                style = UIImpactFeedbackStyleRigid;
            } else if ([type isEqualToString:@"medium"]) {
                style = UIImpactFeedbackStyleMedium;
            }
            // P2-2：复用缓存的 generator，避免每次 alloc+prepare 的开销
            [[self impactGeneratorWithStyle:style] impactOccurred];
        }
    } else {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }
}

#pragma mark - 语义反馈生成器缓存
- (UIImpactFeedbackGenerator *)impactGeneratorWithStyle:(UIImpactFeedbackStyle)style {
    if (self.impactGenerators == nil) {
        self.impactGenerators = [NSMutableDictionary dictionary];
    }
    NSNumber *key = @(style);
    UIImpactFeedbackGenerator *gen = self.impactGenerators[key];
    if (gen == nil) {
        gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
        [gen prepare];
        self.impactGenerators[key] = gen;
    }
    return gen;
}

- (UINotificationFeedbackGenerator *)notificationGenerator {
    if (_notificationGenerator == nil) {
        _notificationGenerator = [[UINotificationFeedbackGenerator alloc] init];
        [_notificationGenerator prepare];
    }
    return _notificationGenerator;
}

- (UISelectionFeedbackGenerator *)selectionGenerator {
    if (_selectionGenerator == nil) {
        _selectionGenerator = [[UISelectionFeedbackGenerator alloc] init];
        [_selectionGenerator prepare];
    }
    return _selectionGenerator;
}

#pragma mark - 自定义波形
- (void)vibratePattern:(NSDictionary *)args {
    NSDictionary *params = [args[KR_PARAM_KEY] hr_stringToDictionary];
    NSArray *timings = params[@"timings"];
    NSArray *intensities = params[@"intensities"];
    NSNumber *r = params[@"repeat"];
    BOOL repeat = (r && [r isKindOfClass:[NSNumber class]]) ? [r boolValue] : NO;
    if (timings == nil || ![timings isKindOfClass:[NSArray class]] || timings.count == 0) {
        [self vibrate:args];
        return;
    }

    if (@available(iOS 13.0, *)) {
        NSMutableArray *events = [NSMutableArray array];
        double currentTime = 0.0;
        for (NSUInteger idx = 0; idx < timings.count; idx++) {
            NSNumber *tNum = timings[idx];
            double t = ([tNum isKindOfClass:[NSNumber class]]) ? [tNum doubleValue] : 0.0;
            double inten = 1.0;
            if (intensities && idx < intensities.count) {
                NSNumber *it = intensities[idx];
                if ([it isKindOfClass:[NSNumber class]]) inten = [it doubleValue];
            }
            if (idx % 2 == 1) {
                // 奇数位 = 震动段（与 Android createWaveform(timings, amplitudes) 语义一致：偶数=静默，奇数=震动）
                if (t <= 0) {
                    currentTime += t / 1000.0;
                    continue;
                }
                CHHapticEventParameter *intensityParam =
                    [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity
                                                                  value:(float)inten];
                CHHapticEvent *event =
                    [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous
                                                  parameters:@[intensityParam]
                                                relativeTime:currentTime
                                                   duration:t / 1000.0];
                [events addObject:event];
                currentTime += t / 1000.0;
            } else {
                // 偶数位 = 静默等待段
                currentTime += t / 1000.0;
            }
        }
        if (events.count == 0) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            return;
        }

        NSError *error = nil;
        CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:events parameters:@[] error:&error];
        if (error || pattern == nil) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            return;
        }
        [self playPattern:pattern loop:repeat];
    } else {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }
}

#pragma mark - 停止震动
- (void)cancel:(NSDictionary *)args {
    [self stopHaptics];
}

#pragma mark - 能力查询
- (void)isSupported:(NSDictionary *)args {
    KuiklyRenderCallback callback = args[KR_CALLBACK_KEY];
    BOOL supported = YES;
    if (@available(iOS 13.0, *)) {
        if (self.hapticEngine != nil) {
            supported = self.hapticEngine.supportsHaptics;
        } else {
            CHHapticCapabilities *caps = [CHHapticEngine capabilitiesForHardware];
            supported = caps.supportsHaptics;
        }
    }
    if (callback) {
        callback(@{@"supported": supported ? @"1" : @"0"});
    }
}

#pragma mark - 高级波形引擎

- (CHHapticPattern *)buildPatternFromEvents:(NSArray *)events error:(NSError **)error {
    NSMutableArray *hapticEvents = [NSMutableArray array];
    for (NSDictionary *e in events) {
        double time = [e[@"time"] doubleValue] / 1000.0;        // ms -> s
        double duration = [e[@"duration"] doubleValue] / 1000.0; // ms -> s
        double intensity = [e[@"intensity"] doubleValue];
        if (intensity < 0.0 || intensity > 1.0) intensity = 1.0;
        double sharpness = [e[@"sharpness"] doubleValue];
        if (sharpness < 0.0 || sharpness > 1.0) sharpness = 0.5;

        NSMutableArray *params = [NSMutableArray array];
        [params addObject:[[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:(float)intensity]];
        [params addObject:[[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:(float)sharpness]];

        CHHapticEvent *event;
        if (duration > 0) {
            // 持续段
            event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous
                                                  parameters:params
                                               relativeTime:time
                                                  duration:duration];
        } else {
            // 瞬态点触
            event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticTransient
                                                  parameters:params
                                               relativeTime:time];
        }
        [hapticEvents addObject:event];
    }
    return [[CHHapticPattern alloc] initWithEvents:hapticEvents parameters:@[] error:error];
}

- (void)play:(NSDictionary *)args {
    KuiklyRenderCallback callback = args[KR_CALLBACK_KEY];
    NSDictionary *params = [args[KR_PARAM_KEY] hr_stringToDictionary];
    NSArray *events = params[@"events"];
    if (events == nil || ![events isKindOfClass:[NSArray class]] || events.count == 0) {
        if (callback) callback(@{@"completed": @"1"});
        return;
    }
    NSNumber *rc = params[@"repeatCount"];
    NSInteger repeatCount = (rc && [rc isKindOfClass:[NSNumber class]]) ? [rc integerValue] : 0;

    // 计算波形总时长（秒）
    double total = 0;
    for (NSDictionary *e in events) {
        double end = [e[@"time"] doubleValue] / 1000.0 + [e[@"duration"] doubleValue] / 1000.0;
        if (end > total) total = end;
    }
    if (total <= 0) total = 0.02;

    if (@available(iOS 13.0, *)) {
        CHHapticEngine *engine = [self ensureEngine];
        if (engine == nil) {
            if (callback) callback(@{@"completed": @"1"});
            return;
        }
        NSError *error = nil;
        CHHapticPattern *pattern = [self buildPatternFromEvents:events error:&error];
        if (error || pattern == nil) {
            if (callback) callback(@{@"completed": @"1"});
            return;
        }
        if (repeatCount <= 1) {
            // 单次播放，completion 精确回调
            id<CHHapticPatternPlayer> player = [engine createPlayerWithPattern:pattern error:&error];
            if (player == nil) {
                if (callback) callback(@{@"completed": @"1"});
                return;
            }
            [player startAtTime:0 error:&error];
            if (callback) callback(@{@"completed": @"1"});
        } else {
            // 有限次循环：advanced player 设置 loop，计时停止
            id<CHHapticAdvancedPatternPlayer> player = [engine createAdvancedPatternPlayerWithPattern:pattern error:&error];
            if (player == nil) {
                if (callback) callback(@{@"completed": @"1"});
                return;
            }
            player.loopEnabled = YES;
            player.loopEndTime = total;
            [player startAtTime:0 error:&error];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(total * repeatCount * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                @try { [player stopAtTime:0 error:nil]; } @catch (NSException *e) {}
                if (callback) callback(@{@"completed": @"1"});
            });
        }
    } else {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        if (callback) callback(@{@"completed": @"1"});
    }
}

- (void)getCapabilities:(NSDictionary *)args {
    KuiklyRenderCallback callback = args[KR_CALLBACK_KEY];
    BOOL supported = NO;
    NSMutableDictionary *caps = [NSMutableDictionary dictionary];
    if (@available(iOS 13.0, *)) {
        CHHapticCapabilities *hardwareCaps = [CHHapticEngine capabilitiesForHardware];
        supported = hardwareCaps.supportsHaptics;
        caps[@"supportsAmplitude"] = @"1";   // Core Haptics 天然支持强度
        caps[@"supportsPredefined"] = @"1";
        caps[@"supportsPattern"] = @"1";
        double maxDur = hardwareCaps.maximumDuration;
        caps[@"maxDurationMs"] = [NSString stringWithFormat:@"%lld", (long long)(maxDur * 1000)];
    } else {
        caps[@"supportsAmplitude"] = @"0";
        caps[@"supportsPredefined"] = @"0";
        caps[@"supportsPattern"] = @"0";
        caps[@"maxDurationMs"] = @"0";
    }
    caps[@"supported"] = supported ? @"1" : @"0";
    if (callback) callback(caps);
}

#pragma mark - Core Haptics 内部实现
- (CHHapticEngine *)ensureEngine {
    if (@available(iOS 13.0, *)) {
        if (self.hapticEngine == nil) {
            NSError *error = nil;
            self.hapticEngine = [[CHHapticEngine alloc] initWithConfiguration:nil error:&error];
            if (error || self.hapticEngine == nil) {
                self.hapticEngine = nil;
                return nil;
            }
            __weak typeof(self) weakSelf = self;
            [self.hapticEngine setResetHandler:^{
                NSError *startError = nil;
                [weakSelf.hapticEngine startAndReturnError:&startError];
            }];
            [self.hapticEngine setStoppedHandler:^(CHHapticEngineStoppedReason reason) {
                weakSelf.hapticEngine = nil;
            }];
            [self.hapticEngine startAndReturnError:&error];
        }
        return self.hapticEngine;
    }
    return nil;
}

- (void)playTransientWithIntensity:(double)intensity sharpness:(double)sharpness {
    if (@available(iOS 13.0, *)) {
        CHHapticEngine *engine = [self ensureEngine];
        if (engine == nil) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            return;
        }
        NSError *error = nil;
        CHHapticEventParameter *intensityParam =
            [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity
                                                          value:(float)intensity];
        CHHapticEventParameter *sharpnessParam =
            [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness
                                                          value:(float)sharpness];
        CHHapticEvent *event =
            [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticTransient
                                          parameters:@[intensityParam, sharpnessParam]
                                        relativeTime:0];
        CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&error];
        if (error || pattern == nil) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            return;
        }
        id<CHHapticPatternPlayer> player = [engine createPlayerWithPattern:pattern error:&error];
        if (error || player == nil) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            return;
        }
        [player startAtTime:0 error:&error];
    } else {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }
}

- (void)playContinuousWithIntensity:(double)intensity duration:(double)duration sharpness:(double)sharpness {
    if (@available(iOS 13.0, *)) {
        CHHapticEngine *engine = [self ensureEngine];
        if (engine == nil) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            return;
        }
        NSError *error = nil;
        CHHapticEventParameter *intensityParam =
            [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity
                                                          value:(float)intensity];
        CHHapticEventParameter *sharpnessParam =
            [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness
                                                          value:(float)sharpness];
        CHHapticEvent *event =
            [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous
                                          parameters:@[intensityParam, sharpnessParam]
                                        relativeTime:0
                                           duration:duration];
        CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&error];
        if (error || pattern == nil) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            return;
        }
        id<CHHapticPatternPlayer> player = [engine createPlayerWithPattern:pattern error:&error];
        if (error || player == nil) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            return;
        }
        [player startAtTime:0 error:&error];
    } else {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }
}

- (void)playPattern:(CHHapticPattern *)pattern loop:(BOOL)loop {
    if (@available(iOS 13.0, *)) {
        CHHapticEngine *engine = [self ensureEngine];
        if (engine == nil) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            return;
        }
        NSError *error = nil;
        id<CHHapticPatternPlayer> player;
        if (loop) {
            id<CHHapticAdvancedPatternPlayer> advPlayer =
                [engine createAdvancedPatternPlayerWithPattern:pattern error:&error];
            if (advPlayer != nil) {
                advPlayer.loopEnabled = YES;
            }
            player = advPlayer;
        } else {
            player = [engine createPlayerWithPattern:pattern error:&error];
        }
        if (error || player == nil) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            return;
        }
        [player startAtTime:0 error:&error];
    } else {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }
}

- (void)stopHaptics {
    if (@available(iOS 13.0, *)) {
        if (self.hapticEngine != nil) {
            NSError *error = nil;
            [self.hapticEngine stopWithCompletionHandler:^(NSError * _Nullable error) {}];
            self.hapticEngine = nil;
        }
    }
}

@end
