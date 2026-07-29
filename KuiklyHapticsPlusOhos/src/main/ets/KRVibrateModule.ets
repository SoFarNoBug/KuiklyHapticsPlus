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
 *  - 自定义震动统一用 VibratorPatternBuilder 构造（addContinuousEvent，单位 μs）。
 */

import { common } from '@kit.AbilityKit';
import { KuiklyRenderBaseModule, KuiklyRenderCallback, KTAny } from '@kuikly-open/render';
import vibrator from '@ohos.vibrator';

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
    return map[raw ?? 'touch'] ?? 'touch';
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
    const attr: vibrator.VibrateAttribute = { usage: usage };
    try {
      vibrator.startVibration(effect, attr);
    } catch (e) {
      console.error("[KRVibrateModule] vibrate error: " + (e as Error).message);
    }
  }

  private vibrateWithDuration(params: KTAny, callback: KuiklyRenderCallback): void {
    const p = this.parseParams(params);
    const duration = (p["duration"] as number) ?? 30;
    const intensity = (p["intensity"] as number) ?? 1.0;
    const usage: vibrator.Usage = this.resolveUsage(p["usage"] as string);
    const strength = Math.max(1, Math.min(100, Math.round(intensity * 100)));
    const effect: vibrator.VibrateEffect = { type: 'time', duration: duration };
    const attr: vibrator.VibrateAttribute = { usage: usage };
    try {
      vibrator.startVibration(effect, attr);
    } catch (e) {
      console.error("[KRVibrateModule] vibrateWithDuration error: " + (e as Error).message);
    }
    if (callback) {
      setTimeout(() => {
        callback({ completed: "1" });
      }, duration);
    }
  }

  private haptic(params: KTAny): void {
    const p = this.parseParams(params);
    const type = (p["type"] as string) ?? "medium";
    const usage: vibrator.Usage = this.resolveUsage(p["usage"] as string);
    let effectId: string = 'haptic.default';
    switch (type) {
      case "light":
        effectId = 'haptic.light';
        break;
      case "medium":
        effectId = 'haptic.medium';
        break;
      case "heavy":
        effectId = 'haptic.heavy';
        break;
      case "success":
        effectId = 'haptic.success';
        break;
      case "warning":
        effectId = 'haptic.warning';
        break;
      case "error":
        effectId = 'haptic.failure';
        break;
      case "selection":
        effectId = 'haptic.selection';
        break;
      default:
        effectId = 'haptic.default';
        break;
    }
    const effect: vibrator.VibrateEffect = { type: 'preset', effectId: effectId };
    const attr: vibrator.VibrateAttribute = { usage: usage };
    try {
      vibrator.startVibration(effect, attr);
    } catch (e) {
      console.error("[KRVibrateModule] haptic error: " + (e as Error).message);
    }
  }

  private buildPattern(timings: Array<number>, intensities: Array<number>): vibrator.VibratorPattern {
    const builder: vibrator.VibratorPatternBuilder = new vibrator.VibratorPatternBuilder();
    let startTime = 0; // μs
    const n = timings.length;
    for (let i = 0; i < n; i++) {
      const t = timings[i];
      const inten = intensities.length > i ? intensities[i] : 1.0;
      if (i % 2 === 1 && t > 0) {
        // 奇数位 = 震动段（与 Android createWaveform(timings, amplitudes) 语义一致：偶数=静默，奇数=震动）
        const opts: vibrator.ContinuousParam = {
          intensity: Math.round(inten * 100),
          frequency: 0
        };
        builder.addContinuousEvent(startTime * 1000, t * 1000, opts);
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
    const attr: vibrator.VibrateAttribute = { usage: 'touch' };
    const fire = () => {
      try {
        vibrator.startVibration(effect, attr);
      } catch (e) {
        console.error("[KRVibrateModule] vibratePattern error: " + (e as Error).message);
      }
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
      const intensity = (e["intensity"] as number) ?? 1.0;
      const clampedIntensity = Math.max(0, Math.min(1, intensity));
      const frequency = (e["frequency"] as number) ?? 0;
      const opts: vibrator.ContinuousParam = {
        intensity: Math.round(clampedIntensity * 100),
        frequency: frequency
      };
      builder.addContinuousEvent(timeMs * 1000, durationMs * 1000, opts);
      const endMs = timeMs + durationMs;
      if (endMs > totalMs) {
        totalMs = endMs;
      }
    }
    const pattern: vibrator.VibratorPattern = builder.build();
    const effect: vibrator.VibrateEffect = { type: 'pattern', pattern: pattern };
    const attr: vibrator.VibrateAttribute = { usage: 'touch' };
    const fire = () => {
      try {
        vibrator.startVibration(effect, attr);
      } catch (e) {
        console.error("[KRVibrateModule] play error: " + (e as Error).message);
      }
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
