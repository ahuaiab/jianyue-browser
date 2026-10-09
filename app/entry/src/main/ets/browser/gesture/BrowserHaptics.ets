import { vibrator } from '@kit.SensorServiceKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  BrowserHapticClock,
  BrowserHapticFeedback,
  BrowserHapticPort
} from '../model/BrowserHapticFeedback';

const HAPTIC_EFFECT_ID: string = 'haptic.effect.soft';
const HAPTIC_LOG_DOMAIN: number = 0x0000;
const HAPTIC_LOG_TAG: string = 'BrowserHaptics';
const HAPTIC_MINIMUM_INTERVAL_MS: number = 100;

interface HapticErrorCode {
  code?: number;
}

class SystemHapticClock implements BrowserHapticClock {
  now(): number {
    return Date.now();
  }
}

class SystemHapticPort implements BrowserHapticPort {
  private softEffectSupported: boolean | undefined = undefined;

  async play(reason: string): Promise<void> {
    let effectSupported: boolean;
    try {
      if (!canIUse('SystemCapability.Sensors.MiscDevice')) {
        this.log(reason, HAPTIC_EFFECT_ID, 'unsupported-capability', 0);
        return;
      }
      if (this.softEffectSupported === undefined) {
        this.softEffectSupported = await vibrator.isSupportEffect(HAPTIC_EFFECT_ID);
      }
      effectSupported = this.softEffectSupported;
    } catch (error) {
      this.log(reason, HAPTIC_EFFECT_ID, 'support-query-failed', this.errorCode(error));
      return;
    }

    const effect: string = effectSupported ? HAPTIC_EFFECT_ID : 'time:15ms';
    try {
      if (effectSupported) {
        await vibrator.startVibration(
          { type: 'preset', effectId: HAPTIC_EFFECT_ID },
          { usage: 'touch' }
        );
      } else {
        await vibrator.startVibration(
          { type: 'time', duration: 15 },
          { usage: 'touch' }
        );
      }
      this.log(reason, effect, 'accepted', 0);
    } catch (error) {
      this.log(reason, effect, 'play-failed', this.errorCode(error));
    }
  }

  private errorCode(error: Object): number {
    const candidate: number | undefined = (error as HapticErrorCode).code;
    return typeof candidate === 'number' ? candidate : -1;
  }

  private log(reason: string, effect: string, result: string, code: number): void {
    hilog.info(
      HAPTIC_LOG_DOMAIN,
      HAPTIC_LOG_TAG,
      'haptic_play reason=%{public}s effect=%{public}s result=%{public}s code=%{public}d',
      reason,
      effect,
      result,
      code
    );
  }
}

const browserHapticFeedback: BrowserHapticFeedback = new BrowserHapticFeedback(
  new SystemHapticPort(),
  new SystemHapticClock(),
  HAPTIC_MINIMUM_INTERVAL_MS
);

export interface BrowserHapticsPort {
  light(reason: string): void;
}

class BrowserHapticsAdapter implements BrowserHapticsPort {
  light(reason: string): void {
    void browserHapticFeedback.light(reason);
  }
}

/** Fire-and-forget entry point used only by committed app-owned interactions. */
export const browserHaptics: BrowserHapticsAdapter = new BrowserHapticsAdapter();
