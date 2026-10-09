export interface BrowserHapticPort {
  play(reason: string): Promise<void>;
}

export interface BrowserHapticClock {
  now(): number;
}

/** One-shot gate for browser-owned touch feedback. */
export class BrowserHapticFeedback {
  private readonly port: BrowserHapticPort;
  private readonly clock: BrowserHapticClock;
  private readonly minimumIntervalMs: number;
  private lastAcceptedAtMs: number = Number.NEGATIVE_INFINITY;
  private playing: boolean = false;

  constructor(
    port: BrowserHapticPort,
    clock: BrowserHapticClock,
    minimumIntervalMs: number = 100
  ) {
    this.port = port;
    this.clock = clock;
    this.minimumIntervalMs = Math.max(0, minimumIntervalMs);
  }

  async light(reason: string): Promise<void> {
    const now: number = this.clock.now();
    if (this.playing || now - this.lastAcceptedAtMs < this.minimumIntervalMs) {
      return;
    }
    this.lastAcceptedAtMs = now;
    this.playing = true;
    try {
      await this.port.play(reason);
    } catch (_error) {
      // Haptics are best-effort and must never block the associated action.
    } finally {
      this.playing = false;
    }
  }
}
