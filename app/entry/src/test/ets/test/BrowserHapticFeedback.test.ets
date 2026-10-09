import { describe, expect, it } from '@ohos/hypium';
import {
  BrowserHapticClock,
  BrowserHapticFeedback,
  BrowserHapticPort
} from '../../../main/ets/browser/model/BrowserHapticFeedback';

class FakeHapticClock implements BrowserHapticClock {
  private currentTimeMs: number = 1000;

  now(): number {
    return this.currentTimeMs;
  }

  advance(milliseconds: number): void {
    this.currentTimeMs += milliseconds;
  }
}

class FakeHapticPort implements BrowserHapticPort {
  attempts: Array<string> = [];
  failNext: boolean = false;
  private pendingResolve: (() => void) | undefined = undefined;

  play(reason: string): Promise<void> {
    this.attempts.push(reason);
    if (this.pendingResolve !== undefined) {
      return new Promise<void>((resolve: () => void) => {
        this.pendingResolve = resolve;
      });
    }
    if (this.failNext) {
      this.failNext = false;
      return Promise.reject(new Error('synthetic haptic failure'));
    }
    return Promise.resolve();
  }

  holdNextPlayback(): void {
    this.pendingResolve = () => {};
  }

  finishPlayback(): void {
    const finish: (() => void) | undefined = this.pendingResolve;
    this.pendingResolve = undefined;
    if (finish !== undefined) {
      finish();
    }
  }
}

export default function browserHapticFeedbackTest() {
  describe('BrowserHapticFeedback', () => {
    it('drops repeated requests inside the minimum interval', 0, async () => {
      const clock: FakeHapticClock = new FakeHapticClock();
      const port: FakeHapticPort = new FakeHapticPort();
      const feedback: BrowserHapticFeedback = new BrowserHapticFeedback(port, clock, 100);

      await feedback.light('tab-switch');
      clock.advance(40);
      await feedback.light('tab-switch');
      expect(port.attempts.length).assertEqual(1);

      clock.advance(60);
      await feedback.light('tab-switch');
      expect(port.attempts.length).assertEqual(2);
    });

    it('drops requests while playback is active without queueing them', 0, async () => {
      const clock: FakeHapticClock = new FakeHapticClock();
      const port: FakeHapticPort = new FakeHapticPort();
      const feedback: BrowserHapticFeedback = new BrowserHapticFeedback(port, clock, 100);
      port.holdNextPlayback();

      const first: Promise<void> = feedback.light('overview-open');
      clock.advance(100);
      await feedback.light('tab-create');
      expect(port.attempts.length).assertEqual(1);
      port.finishPlayback();
      await first;
      clock.advance(100);
      await feedback.light('tab-create');
      expect(port.attempts.length).assertEqual(2);
      expect(port.attempts[1]).assertEqual('tab-create');
    });

    it('allows a later action after a playback failure', 0, async () => {
      const clock: FakeHapticClock = new FakeHapticClock();
      const port: FakeHapticPort = new FakeHapticPort();
      const feedback: BrowserHapticFeedback = new BrowserHapticFeedback(port, clock, 100);
      port.failNext = true;

      await feedback.light('bookmark-delete');
      clock.advance(100);
      await feedback.light('bookmark-edit');
      expect(port.attempts.length).assertEqual(2);
      expect(port.attempts[1]).assertEqual('bookmark-edit');
    });
  });
}
