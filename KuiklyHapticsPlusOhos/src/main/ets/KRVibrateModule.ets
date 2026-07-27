/*
 * KRVibrateModule.ets
 *
 * 鸿蒙侧手机震动控制模块（Kuikly 原生 Module 实现）。
 *
 * 与 commonMain 的 HapticsModule（moduleName = "HRVibrateModule"）桥接，
 * 在 KuiklyViewDelegate 的 getCustomRenderModuleCreatorRegisterMap 中以同名注册。
 *
 * 能力映射（基于 @ohos.vibrator）：
 *  - vibrate            -> startVibration({type:'time', duration:30}, {usage})
 *  - vibrateWithDuration-> startVibration({type:'time', duration}, {usage})
 *  - haptic             -> startVibration({type:'preset', effectId, count:1}, {usage})
 *  - vibratePattern     -> startVibration({type:'pattern', pattern:{events:[...]}})（API12+）
 *  - cancel             -> stopVibration()
 *  - isSupported        -> 回调 {supported:"1"/"0"}（探测 vibrator 模块能力，标准设备视为支持）
 *
 * 说明：
 *  - 鸿蒙 time 型震动不支持直接指定强度，故 vibrateWithDuration 忽略 intensity，仅按 duration 震动。
 *  - usage 透传至 VibrateAttribute.usage（如 'touch'/'notification'/'alarm' 等）。
 *  - vibratePattern 的事件 schema 随 API 版本略有差异，已按 API12 结构实现，联调时按需微调。
 *
 * 注意：本文件属于独立发布库 KuiklyHapticsPlusOhos（待联调，无本地鸿蒙编译环境）。
 */

import { common } from '@kit.AbilityKit';
import { KuiklyRenderBaseModule } from '@kuikly-open/render';
import { KuiklyRenderCallback } from '@kuikly-open/render';
import vibrator from '@ohos.vibrator';

export class KRVibrateModule extends KuiklyRenderBaseModule {
  static readonly MODULE_NAME = "HRVibrateModule";
  static readonly METHOD_VIBRATE = "vibrate";
  static readonly METHOD_VIBRATE_WITH_DURATION = "vibrateWithDuration";
  static readonly METHOD_HAPTIC = "haptic";
  static readonly METHOD_VIBRATE_PATTERN = "vibratePattern";
  static readonly METHOD_CANCEL = "cancel";
  static readonly METHOD_IS_SUPPORTED = "isSupported";

  private patternTimer?: number;

  syncMode(): boolean {
    return false;
  }

  call(method: string, params: KRAny, callback: KuiklyRenderCallback): KRAny {
    switch (method) {
      case KRVibrateModule.METHOD_VIBRATE:
        this.vibrate(params);
        break;
      case KRVibrateModule.METHOD_VIBRATE_WITH_DURATION:
        this.vibrateWithDuration(params);
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
      default:
        break;
    }
    return null;
  }

  private parseParams(params: KRAny): Record<string, Object> {
    if (!params) {
      return {};
    }
    try {
      return JSON.parse(params as string) as Record<string, Object>;
    } catch (e) {
      return {};
    }
  }

  private vibrate(params: KRAny): void {
    const p = this.parseParams(params);
    const usage = (p["usage"] as string) ?? "touch";
    try {
      vibrator.startVibration({ type: 'time', duration: 30 }, { usage: usage });
    } catch (e) {
      console.error("[KRVibrateModule] vibrate error: " + (e as Error).message);
    }
  }

  private vibrateWithDuration(params: KRAny): void {
    const p = this.parseParams(params);
    const duration = (p["duration"] as number) ?? 30;
    const usage = (p["usage"] as string) ?? "touch";
    try {
      vibrator.startVibration({ type: 'time', duration: duration }, { usage: usage });
    } catch (e) {
      console.error("[KRVibrateModule] vibrateWithDuration error: " + (e as Error).message);
    }
  }

  private haptic(params: KRAny): void {
    const p = this.parseParams(params);
    const type = (p["type"] as string) ?? "medium";
    const usage = (p["usage"] as string) ?? "touch";
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
    try {
      vibrator.startVibration({ type: 'preset', effectId: effectId, count: 1 }, { usage: usage });
    } catch (e) {
      console.error("[KRVibrateModule] haptic error: " + (e as Error).message);
    }
  }

  private vibratePattern(params: KRAny): void {
    const p = this.parseParams(params);
    const timings = (p["timings"] as Array<number>) ?? [];
    const intensities = (p["intensities"] as Array<number>) ?? [];
    const repeat = (p["repeat"] as boolean) ?? false;
    if (timings.length === 0) {
      return;
    }
    const events: Array<object> = [];
    let startTime = 0; // 微秒（μs）
    const n = timings.length;
    for (let i = 0; i < n; i++) {
      const t = timings[i];
      const inten = intensities.length > i ? intensities[i] : 1.0;
      if (i % 2 === 1) {
        // 奇数位 = 震动段（与 Android createWaveform(timings, amplitudes) 语义一致：偶数=静默，奇数=震动）
        if (t > 0) {
          events.push({
            duration: t * 1000,           // ms -> μs
            intensity: Math.round(inten * 100),
            startTime: startTime * 1000,  // μs
            frequency: 0
          });
        }
      }
      // 无论静默或震动段，时间轴始终向前推进
      startTime += t;
    }
    if (events.length === 0) {
      return;
    }
    try {
      vibrator.startVibration({ type: 'pattern', pattern: { events: events } } as object);
      if (repeat) {
        // 鸿蒙 pattern 无内建无限循环，按整段时长轮询触发（cancel 时由 stopVibration 停止）
        const totalMs = timings.reduce((a, b) => a + b, 0);
        this.patternTimer = setInterval(() => {
          try {
            vibrator.startVibration({ type: 'pattern', pattern: { events: events } } as object);
          } catch (e) {
            console.error("[KRVibrateModule] vibratePattern loop error: " + (e as Error).message);
          }
        }, totalMs);
      }
    } catch (e) {
      console.error("[KRVibrateModule] vibratePattern error: " + (e as Error).message);
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
    let supported = "0";
    try {
      // P2-1：鸿蒙标准设备均支持基础震动，以 vibrator 模块 API 可用性近似探测
      if (vibrator && vibrator.startVibration) {
        supported = "1";
      }
    } catch (e) {
      supported = "0";
    }
    callback({ supported: supported });
  }
}
