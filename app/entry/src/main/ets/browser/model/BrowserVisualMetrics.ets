/**
 * HarmonyOS-native corner rhythm shared by the browser surfaces.
 *
 * These values keep custom containers on the same 4vp steps used by native
 * mobile surfaces. Interactive pills use ButtonType.Capsule so their final
 * radius is still calculated by ArkUI from the control bounds.
 */
export const HARMONY_RADIUS_TINY: number = 4;
export const HARMONY_RADIUS_COMPACT: number = 8;
export const HARMONY_RADIUS_CONTROL: number = 12;
export const HARMONY_RADIUS_CARD: number = 16;
export const HARMONY_RADIUS_FLOATING: number = 20;
export const HARMONY_RADIUS_SHEET: number = 24;
export const HARMONY_RADIUS_PROGRESS: number = 2;

/** Modal sheets must cover the shared address transition layer (z=40). */
export const BROWSER_MODAL_Z_INDEX: number = 50;
/** Shared motion tokens for the Safari-style overview and bottom sheets. */
export const BROWSER_OVERVIEW_SCALE: number = 0.92;
export const BROWSER_OVERVIEW_RADIUS: number = 28;
export const BROWSER_OVERVIEW_ANIMATION_DURATION_MS: number = 280;
/**
 * Both directions use one duration and one curve. Keeping this token separate
 * from the host reattach delay makes the entry and reverse expansion visibly
 * symmetric without changing WebView lifecycle timing.
 */
export const BROWSER_OVERVIEW_TRANSITION_DURATION_MS: number = 360;
export const BROWSER_SHEET_ANIMATION_DURATION_MS: number = 280;
export const SAFARI_ADDRESS_PREVIEW_FADE_DURATION_MS: number = 180;
/**
 * The customize sheet uses one deliberately relaxed native spring for both
 * the sheet removal and the bottom-chrome squeeze. The larger response keeps
 * the dismissal visible without replacing the velocity-aware spring with a
 * fixed-duration easing curve.
 */
export const START_PAGE_CUSTOMIZE_DISMISS_SPRING_RESPONSE: number = 1.05;
export const START_PAGE_CUSTOMIZE_DISMISS_SPRING_DAMPING: number = 0.92;
export const START_PAGE_CUSTOMIZE_DISMISS_SPRING_OVERLAP: number = 0.08;
/** Keep the settled plus visible before the handoff animator starts. */
export const SAFARI_ADDRESS_HANDOFF_LEAD_IN_MS: number = 52;
/** Only the plus/placeholder crossfade uses the extended interval. */
export const SAFARI_ADDRESS_HANDOFF_CROSSFADE_DURATION_MS: number = 420;

/** Shared geometry for the split Safari-style bottom chrome. */
export const SAFARI_ADDRESS_ITEM_GAP_VP: number = 10;
export const SAFARI_ADDRESS_ROW_HEIGHT_VP: number = 56;
export const SAFARI_ACTION_TOOLBAR_HEIGHT_VP: number = 48;
export const SAFARI_BOTTOM_CHROME_BASE_HEIGHT_VP: number =
  SAFARI_ADDRESS_ROW_HEIGHT_VP + SAFARI_ACTION_TOOLBAR_HEIGHT_VP;
export const SAFARI_BOTTOM_CHROME_RADIUS_VP: number = HARMONY_RADIUS_FLOATING;
/** Keep the native material surface clear of the physical screen edge. */
export const SAFARI_BOTTOM_CHROME_HORIZONTAL_INSET_VP: number = 8;
export const SAFARI_BOTTOM_CHROME_BOTTOM_GAP_VP: number = 8;
/** Visible base colors for the floating chrome; the material tint stays below full opacity. */
export const SAFARI_BOTTOM_CHROME_FALLBACK_COLOR: string = '#FFF2F2F7';
export const SAFARI_BOTTOM_CHROME_MATERIAL_COLOR: string = '#E6F2F2F7';
/** The lower action row follows the outer surface's corner centers. */
export const SAFARI_BOTTOM_CHROME_RAIL_INSET_VP: number = SAFARI_BOTTOM_CHROME_RADIUS_VP;
/**
 * The address capsule sits 8vp inside the already-inset material surface.
 * Its 12vp corner radius then shares a center with the outer 20vp radius.
 */
export const SAFARI_ADDRESS_ITEM_SURFACE_INSET_VP: number = 8;
export const SAFARI_ADDRESS_ITEM_INSET_VP: number =
  SAFARI_BOTTOM_CHROME_HORIZONTAL_INSET_VP + SAFARI_ADDRESS_ITEM_SURFACE_INSET_VP;
/** Reserve room for the security control before collapsed web-address text. */
export const SAFARI_ADDRESS_LOCK_SAFE_INSET_VP: number = 40;
/** Keep focused address text and the native caret inside the capsule edge. */
export const SAFARI_ADDRESS_EDITOR_SAFE_INSET_VP: number = 16;
export const SAFARI_BOTTOM_CHROME_ACTION_COUNT: number = 5;
/**
 * Ergonomic width of the combined address/toolbar surface. Wide windows keep
 * the portrait reach instead of stretching controls across the whole screen.
 */
export const SAFARI_BROWSER_CHROME_DESIGN_WIDTH_VP: number = 400;

/** Reserved placement policy for a later handedness/grip preference. */
export enum BrowserChromeAnchor {
  START,
  CENTER,
  END
}

export interface BrowserChromeLayoutFrame {
  left: number;
  width: number;
}

function finiteVisualMetric(value: number): number {
  return Number.isFinite(value) ? value : 0;
}

/**
 * Place the fixed-width browser chrome inside the horizontal safe region.
 * Narrow and split windows may shrink it, but a wide/rotated window never
 * stretches it beyond the portrait design width.
 */
export function browserChromeLayoutFrame(
  viewportWidth: number,
  leftAvoidInset: number = 0,
  rightAvoidInset: number = 0,
  anchor: BrowserChromeAnchor = BrowserChromeAnchor.CENTER
): BrowserChromeLayoutFrame {
  const safeViewportWidth: number = Math.max(1, finiteVisualMetric(viewportWidth));
  const requestedLeft: number = Math.max(0, finiteVisualMetric(leftAvoidInset));
  const safeLeft: number = Math.min(requestedLeft, Math.max(0, safeViewportWidth - 1));
  const requestedRight: number = Math.max(0, finiteVisualMetric(rightAvoidInset));
  const safeRight: number = Math.min(
    requestedRight,
    Math.max(0, safeViewportWidth - safeLeft - 1)
  );
  const availableWidth: number = Math.max(1, safeViewportWidth - safeLeft - safeRight);
  const width: number = Math.min(SAFARI_BROWSER_CHROME_DESIGN_WIDTH_VP, availableWidth);
  let left: number = safeLeft + (availableWidth - width) / 2;
  if (anchor === BrowserChromeAnchor.START) {
    left = safeLeft;
  } else if (anchor === BrowserChromeAnchor.END) {
    left = safeViewportWidth - safeRight - width;
  }
  return { left, width };
}

export function safariBottomChromeSurfaceWidth(viewportWidth: number): number {
  return Math.max(1, finiteVisualMetric(viewportWidth) -
    SAFARI_BOTTOM_CHROME_HORIZONTAL_INSET_VP * 2);
}

export interface SafariAddressTrackClipFrame {
  left: number;
  width: number;
  topRadius: number;
}

/**
 * Paint-only bounds for the shared address track.
 *
 * Horizontal tab motion stays inside the floating bottom chrome. During the
 * overview morph the address track instead owns its compact transition frame,
 * so it must be released from the bottom-chrome inset and rounded corners.
 */
export function safariAddressTrackClipFrame(
  layoutWidth: number,
  overviewTransitionActive: boolean
): SafariAddressTrackClipFrame {
  const safeWidth: number = Math.max(1, finiteVisualMetric(layoutWidth));
  if (overviewTransitionActive) {
    return {
      left: 0,
      width: safeWidth,
      topRadius: 0
    };
  }
  return {
    left: SAFARI_BOTTOM_CHROME_HORIZONTAL_INSET_VP,
    width: safariBottomChromeSurfaceWidth(safeWidth),
    topRadius: SAFARI_BOTTOM_CHROME_RADIUS_VP
  };
}

export function safariBottomChromeRailWidth(viewportWidth: number): number {
  return Math.max(1, safariBottomChromeSurfaceWidth(viewportWidth) -
    SAFARI_BOTTOM_CHROME_RAIL_INSET_VP * 2);
}

/** Address field width that aligns both inner and outer top-corner centers. */
export function safariAddressItemWidth(viewportWidth: number): number {
  return Math.max(1, finiteVisualMetric(viewportWidth) - SAFARI_ADDRESS_ITEM_INSET_VP * 2);
}

export function safariBottomChromeActionSlotWidth(viewportWidth: number): number {
  return safariBottomChromeRailWidth(viewportWidth) / SAFARI_BOTTOM_CHROME_ACTION_COUNT;
}

export function safariBottomChromeActionCenter(index: number, viewportWidth: number): number {
  const boundedIndex: number = Math.max(0, Math.min(
    SAFARI_BOTTOM_CHROME_ACTION_COUNT - 1,
    Math.trunc(finiteVisualMetric(index))
  ));
  return SAFARI_BOTTOM_CHROME_HORIZONTAL_INSET_VP + SAFARI_BOTTOM_CHROME_RAIL_INSET_VP +
    safariBottomChromeActionSlotWidth(viewportWidth) * (boundedIndex + 0.5);
}

/** Shared centered width for the library segmented tabs and entry rows. */
export const LIBRARY_CONTENT_WIDTH_PERCENT: number = 80;
