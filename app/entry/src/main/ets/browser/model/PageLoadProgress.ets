import { TabId } from './BrowserTypes';

export const PAGE_LOAD_MIN_VISIBLE_MS: number = 1000;
export const PAGE_LOAD_COMPLETION_HOLD_MS: number = 500;
export const PAGE_LOAD_FADE_MS: number = 250;

interface PageLoadProgressState {
  progress: number;
  firstVisibleAt: number | undefined;
  completedAt: number | undefined;
  fading: boolean;
}

/** Real ArkWeb progress with a brief, transient completion presentation. */
export class PageLoadProgressStore {
  private readonly states: Map<TabId, PageLoadProgressState> = new Map();

  begin(tabId: TabId, url: string): boolean {
    if (!/^https?:\/\//i.test(url.trim())) {
      return this.finish(tabId);
    }
    const changed: boolean = !this.states.has(tabId) || this.progressFor(tabId) !== 0;
    this.states.set(tabId, {
      progress: 0, firstVisibleAt: undefined, completedAt: undefined, fading: false
    });
    return changed;
  }

  update(tabId: TabId, progress: number, now: number = Date.now()): boolean {
    const state: PageLoadProgressState | undefined = this.states.get(tabId);
    if (state === undefined || state.completedAt !== undefined || !Number.isFinite(progress)) {
      return false;
    }
    const next: number = Math.max(0, Math.min(100, progress));
    if (next === 100) {
      return this.complete(tabId, now);
    }
    if (next === state.progress) {
      return false;
    }
    if (next > 0 && state.firstVisibleAt === undefined) {
      state.firstVisibleAt = now;
    }
    state.progress = next;
    return true;
  }

  complete(tabId: TabId, now: number = Date.now()): boolean {
    const state: PageLoadProgressState | undefined = this.states.get(tabId);
    // The 100% and page-end callbacks share one idempotent completion deadline.
    if (state === undefined || state.completedAt !== undefined) {
      return false;
    }
    state.progress = 100;
    state.firstVisibleAt = state.firstVisibleAt ?? now;
    state.completedAt = now;
    return true;
  }

  progressFor(tabId: TabId): number {
    return this.states.get(tabId)?.progress ?? 0;
  }

  opacityFor(tabId: TabId): number {
    return this.states.get(tabId)?.fading === true ? 0 : 1;
  }

  nextVisibilityDelay(tabId: TabId, now: number = Date.now()): number | undefined {
    const state: PageLoadProgressState | undefined = this.states.get(tabId);
    if (state === undefined || state.completedAt === undefined) {
      return undefined;
    }
    const fadeAt: number = Math.max(
      (state.firstVisibleAt ?? state.completedAt) + PAGE_LOAD_MIN_VISIBLE_MS,
      state.completedAt + PAGE_LOAD_COMPLETION_HOLD_MS
    );
    return Math.max(0, fadeAt + (state.fading ? PAGE_LOAD_FADE_MS : 0) - now);
  }

  advanceVisibility(tabId: TabId, now: number = Date.now()): boolean {
    const state: PageLoadProgressState | undefined = this.states.get(tabId);
    if (state === undefined || state.completedAt === undefined) {
      return false;
    }
    const fadeAt: number = Math.max(
      (state.firstVisibleAt ?? state.completedAt) + PAGE_LOAD_MIN_VISIBLE_MS,
      state.completedAt + PAGE_LOAD_COMPLETION_HOLD_MS
    );
    if (now >= fadeAt + PAGE_LOAD_FADE_MS) {
      return this.finish(tabId);
    }
    if (now < fadeAt || state.fading) {
      return false;
    }
    state.fading = true;
    return true;
  }

  /** Errors, new navigation, and removed tabs clear immediately without a fade. */
  finish(tabId: TabId): boolean {
    return this.states.delete(tabId);
  }

  clear(): void {
    this.states.clear();
  }
}
