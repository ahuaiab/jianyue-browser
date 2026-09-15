/** Return the lower edge of an avoid-area rectangle in its source unit. */
export function avoidRectBottom(top: number, height: number): number {
  if (!Number.isFinite(top) || !Number.isFinite(height)) {
    return 0;
  }
  return Math.max(0, top + height);
}

/**
 * Use the lower edge of the larger top avoid area.  The caller supplies raw
 * window pixels; conversion to vp belongs to the window/UI owner.
 */
export function topContentInsetFromAvoidRects(
  systemTop: number,
  systemHeight: number,
  cutoutTop: number,
  cutoutHeight: number
): number {
  return Math.max(
    avoidRectBottom(systemTop, systemHeight),
    avoidRectBottom(cutoutTop, cutoutHeight)
  );
}

/** Keep a WebView frame positive while subtracting one top inset exactly once. */
export function availableContentHeight(viewportHeight: number, topContentInset: number): number {
  if (!Number.isFinite(viewportHeight) || viewportHeight <= 0) {
    return 1;
  }
  const safeInset: number = Number.isFinite(topContentInset) ? Math.max(0, topContentInset) : 0;
  return Math.max(1, viewportHeight - safeInset);
}

/**
 * Return the portion of the page that remains visible above bottom chrome.
 * All arguments use the same vp unit as the browser scene geometry.
 */
export function visibleContentHeight(
  viewportHeight: number,
  topContentInset: number,
  bottomContentInset: number
): number {
  const contentHeight: number = availableContentHeight(viewportHeight, topContentInset);
  const safeBottomInset: number = Number.isFinite(bottomContentInset)
    ? Math.max(0, bottomContentInset)
    : 0;
  return Math.max(1, contentHeight - safeBottomInset);
}
