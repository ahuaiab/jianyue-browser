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

export interface WindowAvoidRect {
  left: number;
  top: number;
  width: number;
  height: number;
}

export interface WindowAvoidAreaRects {
  topRect: WindowAvoidRect;
  bottomRect: WindowAvoidRect;
  leftRect: WindowAvoidRect;
  rightRect: WindowAvoidRect;
}

export interface WindowAvoidInsets {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

function validAvoidRect(rect: WindowAvoidRect): boolean {
  return Number.isFinite(rect.left) && Number.isFinite(rect.top) &&
    Number.isFinite(rect.width) && Number.isFinite(rect.height) &&
    rect.width > 0 && rect.height > 0;
}

function startEdgeInset(start: number, extent: number, dimension: number): number {
  if (!Number.isFinite(start) || !Number.isFinite(extent) || extent <= 0 || dimension <= 0) {
    return 0;
  }
  return Math.max(0, Math.min(dimension, start + extent));
}

function endEdgeInset(start: number, extent: number, dimension: number): number {
  if (!Number.isFinite(start) || !Number.isFinite(extent) || extent <= 0 ||
    !Number.isFinite(dimension) || dimension <= 0 || start < 0 || start >= dimension) {
    return 0;
  }
  return Math.max(0, Math.min(dimension, dimension - start));
}

/**
 * Merge the four window-edge avoid rectangles. Areas overlap, so every edge
 * takes the maximum inset instead of adding system, cutout and navigation
 * regions together. Inputs and results stay in the caller's source unit.
 */
export function safeAreaInsetsFromAvoidAreas(
  windowWidth: number,
  windowHeight: number,
  areas: WindowAvoidAreaRects[]
): WindowAvoidInsets {
  const safeWidth: number = Number.isFinite(windowWidth) ? Math.max(0, windowWidth) : 0;
  const safeHeight: number = Number.isFinite(windowHeight) ? Math.max(0, windowHeight) : 0;
  let left: number = 0;
  let top: number = 0;
  let right: number = 0;
  let bottom: number = 0;
  for (let index: number = 0; index < areas.length; index += 1) {
    const area: WindowAvoidAreaRects = areas[index];
    if (validAvoidRect(area.leftRect)) {
      left = Math.max(left, startEdgeInset(area.leftRect.left, area.leftRect.width, safeWidth));
    }
    if (validAvoidRect(area.topRect)) {
      top = Math.max(top, startEdgeInset(area.topRect.top, area.topRect.height, safeHeight));
    }
    if (validAvoidRect(area.rightRect)) {
      right = Math.max(right, endEdgeInset(area.rightRect.left, area.rightRect.width, safeWidth));
    }
    if (validAvoidRect(area.bottomRect)) {
      bottom = Math.max(bottom, endEdgeInset(area.bottomRect.top, area.bottomRect.height, safeHeight));
    }
  }
  return { left, top, right, bottom };
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
