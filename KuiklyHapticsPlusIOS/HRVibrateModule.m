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
#import <AVFoundation/AVFoundation.h>

@interface HRVibrateModule ()
@property (nonatomic, strong, nullable) CHHapticEngine *hapticEngine;
@property (nonatomic, strong, nullable) NSMutableDictionary<NSNumber *, UIImpactFeedbackGenerator *> *impactGenerators;
@property (nonatomic, strong, nullable) UINotificationFeedbackGenerator *notificationGenerator;
@property (nonatomic, strong, nullable) UISelectionFeedbackGenerator *selectionGenerator;
@property (nonatomic, strong, nullable) AVAudioPlayer *silentPlayer; // 静音循环播放，仅用于把音频会话拉到 running 态
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
        // CHHapticEngine 无 supportsHaptics 属性；应通过类方法 capabilitiesForHardware
        // 返回 id<CHHapticDeviceCapability>，其 supportsHaptics 表示硬件是否支持触感播放
        id<CHHapticDeviceCapability> caps = [CHHapticEngine capabilitiesForHardware];
        supported = caps.supportsHaptics;
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
            id<CHHapticAdvancedPatternPlayer> player = [engine createAdvancedPlayerWithPattern:pattern error:&error];
            if (player == nil) {
                if (callback) callback(@{@"completed": @"1"});
                return;
            }
            player.loopEnabled = YES;
            player.loopEnd = total;
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
        id<CHHapticDeviceCapability> hardwareCaps = [CHHapticEngine capabilitiesForHardware];
        supported = hardwareCaps.supportsHaptics;
        caps[@"supportsAmplitude"] = @"1";   // Core Haptics 天然支持强度
        caps[@"supportsPredefined"] = @"1";
        caps[@"supportsPattern"] = @"1";
        // CHHapticDeviceCapability 未暴露最大时长，触感模式无硬性上限，标记为 0（无限制）
        caps[@"maxDurationMs"] = @"0";
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
            // CHHapticEngine 必须在主线程创建（Apple 要求），且底层 AVAudioSession 需已激活。
            // 非主线程时同步切回主线程执行完整创建流程。
            if (![NSThread isMainThread]) {
                __block CHHapticEngine *built = nil;
                dispatch_sync(dispatch_get_main_queue(), ^{
                    built = [self buildAndStartEngine];
                });
                self.hapticEngine = built;
            } else {
                self.hapticEngine = [self buildAndStartEngine];
            }
        }
        return self.hapticEngine;
    }
    return nil;
}

/// 仅在主线程调用：确保音频会话激活 -> 创建并启动 CHHapticEngine
- (CHHapticEngine *)buildAndStartEngine {
    if (@available(iOS 13.0, *)) {
        // Core Haptics 要求底层 AVAudioSession 处于 running 状态（session ID 非 0）。
        // ensureAudioSessionForHaptics 内已启动静音循环播放把会话拉到 running，
        // 但 session ID 的分配是异步的，首次创建可能尚未就绪，故短延迟后最多重试数次。
        [self ensureAudioSessionForHaptics];

        CHHapticEngine *engine = nil;
        NSError *error = nil;
        for (int attempt = 0; attempt < 5 && engine == nil; attempt++) {
            if (attempt > 0) {
                // 让出少量时间，等待音频会话真正 running、session ID 就绪
                [NSThread sleepForTimeInterval:0.03]; // 30ms
            }
            error = nil;
            engine = [[CHHapticEngine alloc] initAndReturnError:&error];
            if (error || engine == nil) {
                NSLog(@"[HRVibrateModule] CHHapticEngine init failed (attempt %d): %@",
                      attempt + 1, error.localizedDescription);
                engine = nil;
            }
        }
        if (engine == nil) {
            return nil;
        }
        __weak typeof(self) weakSelf = self;
        [engine setResetHandler:^{
            // 引擎被系统重置（如音频会话中断恢复）后，需先确保会话激活再重启
            [weakSelf ensureAudioSessionForHaptics];
            NSError *startError = nil;
            [weakSelf.hapticEngine startAndReturnError:&startError];
        }];
        [engine setStoppedHandler:^(CHHapticEngineStoppedReason reason) {
            weakSelf.hapticEngine = nil;
        }];
        [engine startAndReturnError:&error];
        if (error) {
            NSLog(@"[HRVibrateModule] CHHapticEngine start failed: %@", error.localizedDescription);
        }
        return engine;
    }
    return nil;
}

#pragma mark - 音频会话（触感引擎依赖）

- (void)ensureAudioSessionForHaptics {
    // AVAudioSession 的 setActive:/setCategory: 必须在主线程调用，否则可能静默失效，
    // 导致 CHHapticEngine init 仍报 "Invalid audio session ID: 0"。非主线程时同步切回主线程。
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self doEnsureAudioSessionForHaptics];
        });
    } else {
        [self doEnsureAudioSessionForHaptics];
    }
}

- (void)doEnsureAudioSessionForHaptics {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *sessionError = nil;
    // CoreHaptics 的 CHHapticEngine 要求底层 AVAudioSession 持有有效（非 0）的 session ID。
    // 经验证（四轮真机）：
    //  - Ambient 类目不路由硬件音频 → session ID 恒 0；
    //  - Playback + MixWithOthers 在「无其它音频播放」时，系统也不会真正拉起硬件会话 → 同样 ID 0；
    //  - 即便纯 Playback + setActive:YES，若**没有任何真实音频在渲染**，HAL 仍不分配 session ID（setActive 成功只是假象）。
    // 故：类目设为纯 Playback（不加 MixWithOthers），并启动一段静音循环播放（ensureSilentAudio）把会话
    // 真正拉到 running 态，CoreHaptics 才能拿到非 0 的 session ID。已是 Playback（如 KREcho 在播）则不动类目。
    if (session.category == nil ||
        [session.category isEqualToString:AVAudioSessionCategorySoloAmbient] ||
        [session.category isEqualToString:AVAudioSessionCategoryAmbient]) {
        [session setCategory:AVAudioSessionCategoryPlayback error:&sessionError];
        if (sessionError) {
            NSLog(@"[HRVibrateModule] setCategory error: %@", sessionError.localizedDescription);
        }
        sessionError = nil;
        [session setActive:YES error:&sessionError];
    }
    // 关键：用静音音频把会话拉到 running 态（否则 session ID 恒 0）
    [self ensureSilentAudio];
    NSLog(@"[HRVibrateModule] ensureAudioSession done: category=%@ setActiveError=%@ silentPlaying=%d",
          session.category, sessionError.localizedDescription, (int)_silentPlayer.isPlaying);
}

/// 生成一段静音 WAV 并循环播放，唯一目的是把 AVAudioSession 真正拉到 running 态，
/// 使 CoreHaptics 能拿到非 0 的 session ID。音量设为 0，无任何 audible 输出。
/// 仅在纯触感（无其它音频在播）场景下有意义；KREcho 已在播时本会话本就 running，静音循环无副作用。
- (void)ensureSilentAudio {
    @synchronized (self) {
        if (_silentPlayer != nil) {
            if (![_silentPlayer isPlaying]) [_silentPlayer play];
            return;
        }
        // 16-bit 单声道 8kHz，0.2s 静音
        NSUInteger sampleRate = 8000;
        NSUInteger numSamples = sampleRate / 5;
        NSUInteger bytesPerSample = 2;
        NSUInteger dataSize = numSamples * bytesPerSample;
        NSUInteger wavSize = 44 + dataSize;
        unsigned char header[44] = {0};
        uint32_t riffSize = (uint32_t)(wavSize - 8);
        uint32_t fmtSize = 16;
        uint16_t audioFormat = 1; // PCM
        uint16_t channels = 1;
        uint32_t srate = (uint32_t)sampleRate;
        uint32_t byteRate = (uint32_t)(sampleRate * channels * bytesPerSample);
        uint16_t blockAlign = (uint16_t)(channels * bytesPerSample);
        uint16_t bits = 16;
        uint32_t dsize = (uint32_t)dataSize;
        memcpy(header, "RIFF", 4);
        memcpy(header + 4, &riffSize, 4);
        memcpy(header + 8, "WAVE", 4);
        memcpy(header + 12, "fmt ", 4);
        memcpy(header + 16, &fmtSize, 4);
        memcpy(header + 20, &audioFormat, 2);
        memcpy(header + 22, &channels, 2);
        memcpy(header + 24, &srate, 4);
        memcpy(header + 28, &byteRate, 4);
        memcpy(header + 32, &blockAlign, 2);
        memcpy(header + 34, &bits, 2);
        memcpy(header + 36, "data", 4);
        memcpy(header + 40, &dsize, 4);

        NSMutableData *wav = [NSMutableData dataWithCapacity:wavSize];
        [wav appendBytes:header length:44];
        [wav appendData:[NSMutableData dataWithLength:dataSize]]; // 全 0 = 静音样本

        NSError *playerError = nil;
        _silentPlayer = [[AVAudioPlayer alloc] initWithData:wav error:&playerError];
        if (_silentPlayer) {
            _silentPlayer.volume = 0.0;
            _silentPlayer.numberOfLoops = -1; // 无限循环，持续保持会话 running
            [_silentPlayer prepareToPlay];
            [_silentPlayer play];
            NSLog(@"[HRVibrateModule] silent player started (volume=0, no audible output)");
        } else {
            NSLog(@"[HRVibrateModule] silent player init failed: %@", playerError.localizedDescription);
        }
    }
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
                [engine createAdvancedPlayerWithPattern:pattern error:&error];
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
            [self.hapticEngine stopWithCompletionHandler:^(NSError * _Nullable error) {}];
            self.hapticEngine = nil;
        }
    }
}

@end
