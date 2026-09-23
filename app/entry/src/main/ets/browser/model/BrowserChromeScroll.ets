/**
 * Direction of the global Web page scroll used by the browser chrome.
 *
 * Web.onScroll reports the page's absolute yOffset. Increasing yOffset means
 * the page is moving upward under the user's finger; decreasing yOffset means
 * the user is moving back toward the top of the page.
 */
export enum BrowserChromeScrollDirection {
  NONE,
  PAGE_UP,
  PAGE_DOWN
}

/** Ignore tiny yOffset changes so the floating chrome does not chatter. */
export const BROWSER_CHROME_SCROLL_THRESHOLD_VP: number = 6;

function finiteScrollOffset(value: number): number {
  return Number.isFinite(value) ? value : 0;
}

export function browserChromeScrollDirection(
  previousOffset: number | undefined,
  currentOffset: number,
  threshold: number = BROWSER_CHROME_SCROLL_THRESHOLD_VP
): BrowserChromeScrollDirection {
  if (previousOffset === undefined || !Number.isFinite(previousOffset)) {
    return BrowserChromeScrollDirection.NONE;
  }
  const delta: number = finiteScrollOffset(currentOffset) - previousOffset;
  const safeThreshold: number = Math.max(1, finiteScrollOffset(threshold));
  if (delta >= safeThreshold) {
    return BrowserChromeScrollDirection.PAGE_UP;
  }
  if (delta <= -safeThreshold) {
    return BrowserChromeScrollDirection.PAGE_DOWN;
  }
  return BrowserChromeScrollDirection.NONE;
}

/**
 * Resolve the next hidden state from one absolute Web yOffset sample.
 * Reaching the page top always reveals the chrome, while a first sample only
 * establishes a baseline and never causes a surprise hide animation.
 */
export function bottomChromeHiddenForScroll(
  currentlyHidden: boolean,
  previousOffset: number | undefined,
  currentOffset: number
): boolean {
  const boundedCurrentOffset: number = Math.max(0, finiteScrollOffset(currentOffset));
  if (boundedCurrentOffset <= 0) {
    return false;
  }
  const direction: BrowserChromeScrollDirection = browserChromeScrollDirection(
    previousOffset,
    boundedCurrentOffset
  );
  if (direction === BrowserChromeScrollDirection.PAGE_UP) {
    return true;
  }
  if (direction === BrowserChromeScrollDirection.PAGE_DOWN) {
    return false;
  }
  return currentlyHidden;
}
