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
/** The row is exactly the top inset plus the 44vp address capsule. */
export const SAFARI_ADDRESS_ROW_HEIGHT_VP: number = 52;
export const SAFARI_ACTION_TOOLBAR_HEIGHT_VP: number = 48;
export const SAFARI_BOTTOM_CHROME_BASE_HEIGHT_VP: number =
  SAFARI_ADDRESS_ROW_HEIGHT_VP + SAFARI_ACTION_TOOLBAR_HEIGHT_VP;
export const SAFARI_BOTTOM_CHROME_RADIUS_VP: number = HARMONY_RADIUS_FLOATING;
/** Keep the native material surface clear of the physical screen edge. */
export const SAFARI_BOTTOM_CHROME_HORIZONTAL_INSET_VP: number = 8;
export const SAFARI_BOTTOM_CHROME_BOTTOM_GAP_VP: number = 8;
/** Shared opaque light surface token for the floating chrome and start-page panels. */
export const SAFARI_BOTTOM_CHROME_MATERIAL_COLOR: string = '#FFF2F2F7';
/** The fallback surface uses the same token as the native material tint. */
export const SAFARI_BOTTOM_CHROME_FALLBACK_COLOR: string = SAFARI_BOTTOM_CHROME_MATERIAL_COLOR;
/** Semi-transparent base used together with the native material filter. */
export const SAFARI_BOTTOM_CHROME_MATERIAL_BASE_COLOR: string = '#D9F2F2F7';
export const SAFARI_TRANSPARENT_SURFACE_COLOR: string = '#00000000';

/**
 * Native material must see through its host node. Use the opaque surface only
 * on devices that cannot render ImmersiveMaterial.
 */
export function safariChromeSurfaceBackgroundColor(immersiveMaterialSupported: boolean): string {
  return immersiveMaterialSupported
    ? SAFARI_BOTTOM_CHROME_MATERIAL_BASE_COLOR
    : SAFARI_BOTTOM_CHROME_FALLBACK_COLOR;
}
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
/** Side breathing room for independent floating actions. */
export const SAFARI_FLOATING_CONTROL_EDGE_INSET_VP: number = 16;

/** Horizontal placement selected by the system holding-hand state. */
export enum BrowserChromeAnchor {
  START,
  CENTER,
  END
}

/** Normalized smart-reach state used by the browser chrome layout model. */
export enum BrowserChromeHandedness {
  UNKNOWN,
  LEFT,
  RIGHT,
  BOTH
}

/** Operating-hand fallback used when a device does not expose grip sensing. */
export enum BrowserChromeOperatingHand {
  UNKNOWN,
  LEFT,
  RIGHT
}

/**
 * Map the system grip state to a safe chrome anchor. Both hands, no hand, and
 * unknown states stay centered so the fixed-width surface does not jump to a
 * side when the system cannot establish a single reachable edge.
 */
export function browserChromeAnchorForHandedness(
  handedness: BrowserChromeHandedness
): BrowserChromeAnchor {
  if (handedness === BrowserChromeHandedness.LEFT) {
    return BrowserChromeAnchor.START;
  }
  if (handedness === BrowserChromeHandedness.RIGHT) {
    return BrowserChromeAnchor.END;
  }
  return BrowserChromeAnchor.CENTER;
}

/**
 * Use the system's touch-operating hand as a compatibility fallback. This is
 * less precise than grip sensing, but remains available on more devices and
 * keeps the chrome reachable when holding-hand subscription is unsupported.
 */
export function browserChromeAnchorForOperatingHand(
  operatingHand: BrowserChromeOperatingHand
): BrowserChromeAnchor {
  if (operatingHand === BrowserChromeOperatingHand.LEFT) {
    return BrowserChromeAnchor.START;
  }
  if (operatingHand === BrowserChromeOperatingHand.RIGHT) {
    return BrowserChromeAnchor.END;
  }
  return BrowserChromeAnchor.CENTER;
}

export interface BrowserChromeLayoutFrame {
  left: number;
  width: number;
}

function finiteVisualMetric(value: number): number {
  return Number.isFinite(value) ? value : 0;
}

/** The painted material contains only the address row and action toolbar. */
export function safariBottomChromePaintedHeight(): number {
  return SAFARI_BOTTOM_CHROME_BASE_HEIGHT_VP;
}

/**
 * Total layout height, including the dynamic tail after the painted chrome.
 * The fixed position layer contributes one bottom-gap step, so retain one
 * matching step inside the navigation-indicator region rather than placing
 * the material all the way at its upper edge.
 */
export function safariBottomChromeLayoutHeight(bottomInset: number = 0): number {
  const safeInset: number = Math.max(0, finiteVisualMetric(bottomInset));
  const tail: number = Math.max(
    0,
    safeInset - SAFARI_BOTTOM_CHROME_BOTTOM_GAP_VP * 2
  );
  return safariBottomChromePaintedHeight() + tail;
}

/**
 * Transparent tail kept below the material surface for the dynamic navigation
 * indicator avoid area. Keeping it after the painted surface prevents the
 * system gesture pill from being drawn through the material.
 */
export function safariBottomChromeUnpaintedAvoidAreaHeight(bottomInset: number = 0): number {
  const safeInset: number = Math.max(0, finiteVisualMetric(bottomInset));
  return Math.max(
    0,
    safeInset - SAFARI_BOTTOM_CHROME_BOTTOM_GAP_VP * 2
  );
}

/** The painted surface starts at the top of the browser chrome layout. */
export function safariBottomChromeSurfaceTopOffset(bottomInset: number = 0): number {
  // The dynamic avoid area is a bottom tail, not a top spacer. Keeping this
  // zero also keeps the address capsule and toolbar on one contiguous track.
  return 0;
}

/**
 * Height occupied from the painted top to the screen edge. It includes the
 * dynamic transparent tail and the fixed outer edge gap used by the position
 * layer, so page/transition geometry reserves the same region as the chrome.
 */
export function safariBottomChromeVisualHeight(bottomInset: number = 0): number {
  return safariBottomChromeLayoutHeight(bottomInset) + SAFARI_BOTTOM_CHROME_BOTTOM_GAP_VP;
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

/**
 * Return the painted surface inside the fixed browser chrome positioning
 * layer. The 8vp inset mirrors BottomBrowserBar's parent padding exactly, so
 * modal pages can share both the visible width and the smart-reach anchor.
 */
export function browserChromeSurfaceFrame(
  viewportWidth: number,
  leftAvoidInset: number = 0,
  rightAvoidInset: number = 0,
  anchor: BrowserChromeAnchor = BrowserChromeAnchor.CENTER
): BrowserChromeLayoutFrame {
  const frame: BrowserChromeLayoutFrame = browserChromeLayoutFrame(
    viewportWidth,
    leftAvoidInset,
    rightAvoidInset,
    anchor
  );
  return {
    left: frame.left + SAFARI_BOTTOM_CHROME_HORIZONTAL_INSET_VP,
    width: Math.max(1, frame.width - SAFARI_BOTTOM_CHROME_HORIZONTAL_INSET_VP * 2)
  };
}

/** Translate a centered sheet into the same surface frame used by the bottom chrome. */
export function browserChromeSurfaceHorizontalOffset(
  viewportWidth: number,
  leftAvoidInset: number = 0,
  rightAvoidInset: number = 0,
  anchor: BrowserChromeAnchor = BrowserChromeAnchor.CENTER
): number {
  const safeViewportWidth: number = Math.max(1, finiteVisualMetric(viewportWidth));
  const frame: BrowserChromeLayoutFrame = browserChromeSurfaceFrame(
    safeViewportWidth,
    leftAvoidInset,
    rightAvoidInset,
    anchor
  );
  return frame.left - (safeViewportWidth - frame.width) / 2;
}

/**
 * Translate a smaller floating control from its safe-region center to the
 * requested smart-reach edge. The control width is intentionally independent
 * from the 400vp browser chrome width so overview and library actions can
 * follow the same hand without changing their own visual size.
 */
export function browserChromeFloatingControlOffset(
  viewportWidth: number,
  leftAvoidInset: number = 0,
  rightAvoidInset: number = 0,
  controlWidth: number = 1,
  anchor: BrowserChromeAnchor = BrowserChromeAnchor.CENTER
): number {
  const safeViewportWidth: number = Math.max(1, finiteVisualMetric(viewportWidth));
  const requestedLeft: number = Math.max(0, finiteVisualMetric(leftAvoidInset));
  const safeLeft: number = Math.min(requestedLeft, Math.max(0, safeViewportWidth - 1));
  const requestedRight: number = Math.max(0, finiteVisualMetric(rightAvoidInset));
  const safeRight: number = Math.min(
    requestedRight,
    Math.max(0, safeViewportWidth - safeLeft - 1)
  );
  const availableWidth: number = Math.max(1, safeViewportWidth - safeLeft - safeRight);
  const width: number = Math.min(Math.max(1, finiteVisualMetric(controlWidth)), availableWidth);
  const centeredLeft: number = safeLeft + (availableWidth - width) / 2;
  const edgeInset: number = Math.min(
    SAFARI_FLOATING_CONTROL_EDGE_INSET_VP,
    Math.max(0, availableWidth - width)
  );
  let targetLeft: number = centeredLeft;
  if (anchor === BrowserChromeAnchor.START) {
    targetLeft = safeLeft + edgeInset;
  } else if (anchor === BrowserChromeAnchor.END) {
    targetLeft = safeViewportWidth - safeRight - width - edgeInset;
  }
  return targetLeft - centeredLeft;
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
