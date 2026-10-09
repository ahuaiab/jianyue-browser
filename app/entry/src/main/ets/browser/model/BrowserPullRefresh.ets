export enum BrowserPullRefreshIndicatorMode {
  HIDDEN = 'hidden',
  PULLING = 'pulling',
  READY = 'ready'
}

export interface BrowserPullRefreshContentTranslation {
  x: number;
  y: number;
  z: number;
}

const BROWSER_PULL_REFRESH_DRAG_GAIN: number = 1.08;

/** Slightly compensate finger travel while keeping the blank reveal at bar height. */
export function browserPullRefreshOffset(distance: number, revealHeight: number): number {
  if (!Number.isFinite(distance) || !Number.isFinite(revealHeight) || revealHeight <= 0) {
    return 0;
  }
  return Math.max(0, Math.min(distance * BROWSER_PULL_REFRESH_DRAG_GAIN, revealHeight));
}

/** Move the ArkWeb wrapper without applying a transform directly to NodeContainer. */
export function browserPullRefreshContentTranslation(
  distance: number,
  revealHeight: number
): BrowserPullRefreshContentTranslation {
  return {
    x: 0,
    y: browserPullRefreshOffset(distance, revealHeight),
    z: 0
  };
}

/** Web.onScroll reports an absolute offset from the page top; only zero is at top. */
export function isBrowserWebPageAtTop(verticalScrollOffset: number): boolean {
  return Number.isFinite(verticalScrollOffset) && verticalScrollOffset === 0;
}

/** Only take ownership of a downward pan when the page and browser can refresh. */
export function shouldCaptureBrowserPullGesture(
  canPullToRefresh: boolean,
  pageAtTop: boolean,
  interactionLocked: boolean,
  revealHeight: number
): boolean {
  return canPullToRefresh && pageAtTop && !interactionLocked &&
    Number.isFinite(revealHeight) && revealHeight > 0;
}

/** Convert the revealed distance into a determinate ring percentage. */
export function browserPullRefreshProgressPercent(distance: number, revealHeight: number): number {
  if (!Number.isFinite(distance) || !Number.isFinite(revealHeight) || revealHeight <= 0) {
    return 0;
  }
  return browserPullRefreshOffset(distance, revealHeight) / revealHeight * 100;
}

/** Keep the pull indicator tied to the drag, not the network request lifetime. */
export function browserPullRefreshIndicatorMode(
  distance: number,
  revealHeight: number,
  _isRefreshing: boolean
): BrowserPullRefreshIndicatorMode {
  const offset: number = browserPullRefreshOffset(distance, revealHeight);
  if (offset <= 0) {
    return BrowserPullRefreshIndicatorMode.HIDDEN;
  }
  return offset >= revealHeight
    ? BrowserPullRefreshIndicatorMode.READY
    : BrowserPullRefreshIndicatorMode.PULLING;
}

/** The whole blank reveal must be exposed, and the Web page must be at its top. */
export function shouldRefreshBrowserPageOnPullRelease(
  distance: number,
  revealHeight: number,
  pageAtTop: boolean
): boolean {
  return pageAtTop && revealHeight > 0 &&
    browserPullRefreshOffset(distance, revealHeight) >= revealHeight;
}
