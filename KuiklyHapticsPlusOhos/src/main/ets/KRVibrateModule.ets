/*
 * KRVibrateModule.ets
 *
 * 鸿蒙侧手机震动控制模块（Kuikly 原生 Module 实现）。
 *
 * 与 commonMain 的 HapticsModule（moduleName = "HRVibrateModule"）桥接，
 * 在 KuiklyViewDelegate 的 getCustomRenderModuleCreatorRegisterMap 中以同名注册。
 *
 * 能力映射（基于 @ohos.vibrator，适配 HarmonyOS NEXT / API 12+）：
 *  - vibrate             -> startVibration({type:'time', duration:30}, {usage})
 *  - vibrateWithDuration-> startVibration({type:'time', duration}, {usage})
 *  - haptic             -> startVibration({type:'preset', effectId}, {usage})
 *  - vibratePattern     -> startVibration({type:'pattern', pattern}, {usage})
 *  - cancel             -> stopVibration()
 *  - isSupported        -> 回调 {supported:"1"}（鸿蒙标准设备均支持基础震动）
 *  - play              -> 解析 events 构建 VibratorPattern（intensity/frequency 生效），repeatCount>0 循环
 *  - getCapabilities    -> 回调设备触感能力 {supported/supportsAmplitude/supportsPredefined/supportsPattern/maxDurationMs}
 *
 * 说明：
 *  - 鸿蒙 time 型震动不支持直接指定强度，故 vibrateWithDuration 忽略 intensity，仅按 duration 震动。
 *  - usage 透传至 VibrateAttribute.usage（字符串联合类型，见 resolveUsage）。
 *  - 自定义震动统一用 VibratorPatternBuilder 构造（addContinuousEvent，单位 ms）。
 */

import { common } from '@kit.AbilityKit';
import { KuiklyRenderBaseModule, KuiklyRenderCallback, KTAny } from '@kuikly-open/render';
import vibrator from '@ohos.vibrator';
import { BusinessError } from '@ohos.base';

export class KRVibrateModule extends KuiklyRenderBaseModule {
  static readonly MODULE_NAME = "HRVibrateModule";
  static readonly METHOD_VIBRATE = "vibrate";
  static readonly METHOD_VIBRATE_WITH_DURATION = "vibrateWithDuration";
  static readonly METHOD_HAPTIC = "haptic";
  static readonly METHOD_VIBRATE_PATTERN = "vibratePattern";
  static readonly METHOD_CANCEL = "cancel";
  static readonly METHOD_IS_SUPPORTED = "isSupported";
  static readonly METHOD_PLAY = "play";
  static readonly METHOD_GET_CAPABILITIES = "getCapabilities";

  private patternTimer?: number;

  syncMode(): boolean {
    return false;
  }

  call(method: string, params: KTAny, callback: KuiklyRenderCallback): KTAny {
    switch (method) {
      case KRVibrateModule.METHOD_VIBRATE:
        this.vibrate(params);
        break;
      case KRVibrateModule.METHOD_VIBRATE_WITH_DURATION:
        this.vibrateWithDuration(params, callback);
        break;
      case KRVibrateModule.METHOD_HAPTIC:
        this.haptic(params);
        break;
      case KRVibrateModule.METHOD_VIBRATE_PATTERN:
        this.vibratePattern(params);
        break;
      case KRVibrateModule.METHOD_CANCEL:
        this.cancel();
        break;
      case KRVibrateModule.METHOD_IS_SUPPORTED:
        this.isSupported(callback);
        break;
      case KRVibrateModule.METHOD_PLAY:
        this.play(params, callback);
        break;
      case KRVibrateModule.METHOD_GET_CAPABILITIES:
        this.getCapabilities(callback);
        break;
      default:
        break;
    }
    return null;
  }

  private resolveUsage(raw: string | undefined): vibrator.Usage {
    const map: Record<string, vibrator.Usage> = {
      'unknown': 'unknown',
      'alarm': 'alarm',
      'ring': 'ring',
      'notification': 'notification',
      'communication': 'communication',
      'touch': 'touch',
      'media': 'media',
      'physicalFeedback': 'physicalFeedback',
      'simulateReality': 'simulateReality'
    };
    // 鸿蒙 vibrator.Usage 不含 'game' 等常见业务语义；未知 usage 打告警并降级 touch（静默降级不透明问题修复）。
    const fallback: vibrator.Usage = 'touch';
    if (!raw) {
      return fallback;
    }
    const resolved = map[raw];
    if (!resolved) {
      console.warn("[KRVibrateModule] unknown usage '" + raw + "', fallback to '" + fallback + "'");
      return fallback;
    }
    return resolved;
  }

  private parseParams(params: KTAny): Record<string, Object> {
    if (!params) {
      return {};
    }
    try {
      return JSON.parse(params as string) as Record<string, Object>;
    } catch (e) {
      return {};
    }
  }

  private vibrate(params: KTAny): void {
    const p = this.parseParams(params);
    const usage: vibrator.Usage = this.resolveUsage(p["usage"] as string);
    const effect: vibrator.VibrateEffect = { type: 'time', duration: 30 };
    const attr: vibrator.VibrateAttribute = { id: 0, usage: usage };
    this.startVibrationWithRetry(effect, attr, 3, 50);
  }

  private vibrateWithDuration(params: KTAny, callback: KuiklyRenderCallback): void {
    const p = this.parseParams(params);
    const duration = (p["duration"] as number) ?? 30;
    const usage: vibrator.Usage = this.resolveUsage(p["usage"] as string);
    const effect: vibrator.VibrateEffect = { type: 'time', duration: duration };
    const attr: vibrator.VibrateAttribute = { id: 0, usage: usage };
    this.startVibrationWithRetry(effect, attr, 3, 50);
    if (callback) {
      setTimeout(() => {
        callback({ completed: "1" });
      }, duration);
    }
  }

  private haptic(params: KTAny): void {
    const p = this.parseParams(params);
    const type = (p["type"] as string) ?? "medium";
    // haptic 语义即 UI 触感反馈；usage 透传调用方（缺省 touch），仍受「触感开关」管控。
    const usage: vibrator.Usage = this.resolveUsage(p["usage"] as string);
    const attr: vibrator.VibrateAttribute = { id: 0, usage: usage };
    const effectId = this.presetEffectId(type);
    const effect: vibrator.VibrateEffect = { type: 'preset', effectId: effectId };
    // 优先尝试系统 preset 原始触感；部分设备/固件不支持特定 preset，会返回 14600101
    // （Device operation failed：HDI 异常或设备被占用）。此时回退到 time 短震（沿用同一 usage）。
    // 注意：preset 失败后立即在同线程发起 time 短震，常被 HDI 判为「设备被占用」而再次 14600101，
    // 故回退走 startVibrationWithRetry 做延迟重试（官方对该错误码的建议正是「间隔一段时间重试」）。
    vibrator.startVibration(effect, attr, (err: BusinessError | null) => {
      if (err) {
        console.warn("[KRVibrateModule] preset haptic '" + effectId + "' failed (" + err.message + "), fallback to time vibration");
        const fbEffect: vibrator.VibrateEffect = { type: 'time', duration: this.hapticFallbackMs(type) };
        this.startVibrationWithRetry(fbEffect, attr, 3, 50);
      }
    });
  }

  private presetEffectId(type: string): string {
    switch (type) {
      case "light": return 'haptic.light';
      case "medium": return 'haptic.medium';
      case "heavy": return 'haptic.heavy';
      case "success": return 'haptic.success';
      case "warning": return 'haptic.warning';
      case "error": return 'haptic.failure';
      case "selection": return 'haptic.selection';
      default: return 'haptic.default';
    }
  }

  private hapticFallbackMs(type: string): number {
    switch (type) {
      case "light": return 20;
      case "medium": return 40;
      case "heavy": return 90;
      case "selection": return 15;
      case "success": return 60;
      case "warning": return 80;
      case "error": return 100;
      default: return 30;
    }
  }

  // 通用 startVibration 重试：应对 14600101（Device operation failed，官方成因含「设备被占用」）。
  // 失败按指数退避（delayMs, delayMs*2, ...）最多 attempts 次；成功或最终失败仅打日志，不抛异常。
  // 三个入口（vibrate / vibrateWithDuration / haptic 回退）统一复用，避免各路径在设备忙时一次性失败无回退。
  private startVibrationWithRetry(effect: vibrator.VibrateEffect, attr: vibrator.VibrateAttribute, attempts: number, delayMs: number): void {
    vibrator.startVibration(effect, attr, (err: BusinessError | null) => {
      if (err && attempts > 1) {
        console.warn("[KRVibrateModule] startVibration failed (" + err.message + "), retry after " + delayMs + "ms, left " + (attempts - 1));
        setTimeout(() => {
          this.startVibrationWithRetry(effect, attr, attempts - 1, delayMs * 2);
        }, delayMs);
      } else if (err) {
        console.error("[KRVibrateModule] startVibration failed: " + err.message);
      }
    });
  }

  private buildCurve(duration: number, intensityGain: number, frequencyOffset: number): Array<vibrator.VibratorCurvePoint> {
    // VibratorCurvePoint: time(相对事件起点的 ms), intensity([0,1] 增益，乘上事件强度), frequency([-100,100] 相对事件频率的偏移)
    // 调节点最少 4 个、最多 16 个；此处用 4 点恒定增益覆盖整段 duration
    const d = Math.max(1, duration);
    return [
      { time: 0, intensity: intensityGain, frequency: frequencyOffset },
      { time: Math.round(d * 0.33), intensity: intensityGain, frequency: frequencyOffset },
      { time: Math.round(d * 0.66), intensity: intensityGain, frequency: frequencyOffset },
      { time: d, intensity: intensityGain, frequency: frequencyOffset }
    ];
  }

  private buildPattern(timings: Array<number>, intensities: Array<number>): vibrator.VibratorPattern {
    const builder: vibrator.VibratorPatternBuilder = new vibrator.VibratorPatternBuilder();
    let startTime = 0; // ms
    const n = timings.length;
    for (let i = 0; i < n; i++) {
      const t = timings[i];
      const inten = intensities.length > i ? intensities[i] : 1.0;
      if (i % 2 === 1 && t > 0) {
        // 奇数位 = 震动段（与 Android createWaveform(timings, amplitudes) 语义一致：偶数=静默，奇数=震动）
        const duration = Math.min(5000, Math.max(1, t)); // 单段持续时长上限 5000ms
        const opts: vibrator.ContinuousParam = {
          intensity: Math.max(0, Math.min(100, Math.round(inten * 100))),
          frequency: 55, // 器件谐振频率附近，振动量最大
          index: 0,
          points: this.buildCurve(duration, 1.0, 0)
        };
        builder.addContinuousEvent(startTime, duration, opts);
      }
      startTime += t;
    }
    return builder.build();
  }

  private vibratePattern(params: KTAny): void {
    const p = this.parseParams(params);
    const timings = (p["timings"] as Array<number>) ?? [];
    const intensities = (p["intensities"] as Array<number>) ?? [];
    const repeat = (p["repeat"] as boolean) ?? false;
    if (timings.length === 0) {
      return;
    }
    const effect: vibrator.VibrateEffect = { type: 'pattern', pattern: this.buildPattern(timings, intensities) };
    const attr: vibrator.VibrateAttribute = { id: 0, usage: 'touch' };
    const fire = () => {
      this.startVibrationWithRetry(effect, attr, 2, 50);
    };
    fire();
    if (repeat) {
      const totalMs = timings.reduce((a, b) => a + b, 0);
      if (this.patternTimer !== undefined) {
        clearInterval(this.patternTimer);
        this.patternTimer = undefined;
      }
      this.patternTimer = setInterval(fire, totalMs);
    }
  }

  private cancel(): void {
    if (this.patternTimer !== undefined) {
      clearInterval(this.patternTimer);
      this.patternTimer = undefined;
    }
    try {
      vibrator.stopVibration();
    } catch (e) {
      console.error("[KRVibrateModule] cancel error: " + (e as Error).message);
    }
  }

  private isSupported(callback: KuiklyRenderCallback): void {
    // 鸿蒙标准设备均支持基础震动
    callback({ supported: "1" });
  }

  private play(params: KTAny, callback: KuiklyRenderCallback): void {
    const p = this.parseParams(params);
    const events = (p["events"] as Array<Record<string, Object>>) ?? [];
    const repeatCount = (p["repeatCount"] as number) ?? 0;
    if (events.length === 0) {
      callback({ completed: "1" });
      return;
    }
    const builder: vibrator.VibratorPatternBuilder = new vibrator.VibratorPatternBuilder();
    let totalMs = 0;
    for (const e of events) {
      const timeMs = (e["time"] as number) ?? 0;
      let durationMs = (e["duration"] as number) ?? 0;
      if (durationMs <= 0) {
        durationMs = 20; // 瞬态点触默认 20ms
      }
      durationMs = Math.min(5000, Math.max(1, durationMs)); // 单段持续时长上限 5000ms
      const intensity = (e["intensity"] as number) ?? 1.0;
      const clampedIntensity = Math.max(0, Math.min(1, intensity));
      const opts: vibrator.ContinuousParam = {
        intensity: Math.round(clampedIntensity * 100),
        frequency: 55, // 器件谐振频率附近，振动量最大
        index: 0,
        points: this.buildCurve(durationMs, 1.0, 0)
      };
      builder.addContinuousEvent(timeMs, durationMs, opts);
      const endMs = timeMs + durationMs;
      if (endMs > totalMs) {
        totalMs = endMs;
      }
    }
    const pattern: vibrator.VibratorPattern = builder.build();
    const effect: vibrator.VibrateEffect = { type: 'pattern', pattern: pattern };
    const attr: vibrator.VibrateAttribute = { id: 0, usage: 'touch' };
    const fire = () => {
      this.startVibrationWithRetry(effect, attr, 2, 50);
    };
    fire();
    if (repeatCount <= 1) {
      setTimeout(() => {
        callback({ completed: "1" });
      }, totalMs);
    } else {
      if (this.patternTimer !== undefined) {
        clearInterval(this.patternTimer);
        this.patternTimer = undefined;
      }
      this.patternTimer = setInterval(fire, totalMs);
      setTimeout(() => {
        if (this.patternTimer !== undefined) {
          clearInterval(this.patternTimer);
          this.patternTimer = undefined;
        }
        callback({ completed: "1" });
      }, totalMs * repeatCount);
    }
  }

  private getCapabilities(callback: KuiklyRenderCallback): void {
    callback({
      supported: "1",
      supportsAmplitude: "1",    // 鸿蒙 pattern 支持 intensity
      supportsPredefined: "1",   // 鸿蒙支持 preset 效果
      supportsPattern: "1",      // 鸿蒙支持自定义 pattern（API12+）
      maxDurationMs: "0"         // 未知
    });
  }
}
