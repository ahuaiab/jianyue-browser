import { BrowserTabRecord } from './BrowserTypes';
import { HARMONY_RADIUS_CARD, HARMONY_RADIUS_CONTROL } from './BrowserVisualMetrics';

/** Shared visual metrics for the Safari-like tab overview and its cards. */
export interface TabOverviewLayoutMetrics {
  columns: number;
  horizontalPadding: number;
  cardHeight: number;
  gap: number;
  cardRadius: number;
}

/** Shared rounded-field metrics for the two Safari-style search controls. */
export interface SearchBarStyleMetrics {
  height: number;
  cornerRadius: number;
  horizontalInset: number;
}

/** The tab overview field is a compact rounded rectangle, not a capsule. */
export const TAB_SEARCH_BAR_STYLE: SearchBarStyleMetrics = {
  height: 42,
  cornerRadius: HARMONY_RADIUS_CONTROL,
  horizontalInset: 12
};

/** The home address field matches the 44vp icon control height. */
export const ADDRESS_SEARCH_BAR_STYLE: SearchBarStyleMetrics = {
  height: 44,
  cornerRadius: TAB_SEARCH_BAR_STYLE.cornerRadius,
  horizontalInset: 12
};

/** Move the address pill down so its 12vp corner centers match the 20vp outer surface. */
export const ADDRESS_SEARCH_BAR_TOP_PADDING: number = 8;

/** Visual tokens for the white overview canvas and its gray pull-down field. */
export const TAB_OVERVIEW_BACKGROUND_COLOR: string = '#FFFFFF';
export const TAB_SEARCH_BAR_BACKGROUND_COLOR: string = '#F2F2F7';
export const TAB_SEARCH_BAR_CONTENT_INSET: number = 13;
export const TAB_SEARCH_REVEAL_ANIMATION_DURATION_MS: number = 240;

/** Native menu actions exposed when a tab card is held. */
export const TAB_CARD_MENU_LABELS: string[] = [
  '新建标签',
  '关闭此标签',
  '关闭所有标签'
];

/** Symbol names kept beside the labels so the native menu remains auditable. */
export const TAB_CARD_MENU_SYMBOL_NAMES: string[] = [
  'sys.symbol.plus',
  'sys.symbol.xmark',
  'sys.symbol.xmark_circle'
];

/** Destructive styling applies to both close actions, not the new-tab action. */
export const TAB_CARD_MENU_DESTRUCTIVE_COLOR: string = '#FF3B30';

export function tabCardMenuItemIsDestructive(index: number): boolean {
  return index === 1 || index === 2;
}

/** Pull distance in vp required to reveal and focus the tab search field. */
export const TAB_SEARCH_PULL_THRESHOLD: number = 72;

export function tabSearchPullProgress(offsetY: number): number {
  if (offsetY <= 0) {
    return 0;
  }
  return Math.min(1, offsetY / TAB_SEARCH_PULL_THRESHOLD);
}

/** Clamp pull distance to the progress used by the reveal animation. */
export function tabSearchVisualProgress(offsetY: number): number {
  return tabSearchPullProgress(offsetY);
}

export const TAB_OVERVIEW_LAYOUT: TabOverviewLayoutMetrics = {
  columns: 2,
  horizontalPadding: 16,
  // Keep the preview card tall enough to match the Safari-style portrait
  // preview while the live page remains uniformly scaled and clipped to it.
  cardHeight: 242,
  gap: 12,
  cardRadius: HARMONY_RADIUS_CARD
};

/**
 * Gesture geometry must use the same height that is rendered by TabCard.
 * Keeping this alias next to the layout contract prevents the close threshold
 * from drifting when the card is tuned against the video reference.
 */
export const TAB_OVERVIEW_GESTURE_CARD_HEIGHT: number = TAB_OVERVIEW_LAYOUT.cardHeight;

/** Keep the card grid out of the foreground until the live page reaches its slot. */
export const TAB_OVERVIEW_PAGE_HANDOFF_START_PROGRESS: number = 0.92;

/**
 * Transfer the selection ring with the grid during its final handoff. The
 * card has fixed bounds while the live clip is still interpolating toward
 * them; leaving the live ring enabled until exactly 1.0 makes its bottom edge
 * visibly extend past the card for the last few frames.
 */
export const TAB_OVERVIEW_BORDER_HANDOFF_PROGRESS: number = 0.98;

/** Height of the title/close row that becomes the card's lower tab label. */
export const TAB_OVERVIEW_CAPTION_HEIGHT: number = 32;

/** Compact title size shared by the settled card and the live transition label. */
export const TAB_OVERVIEW_CAPTION_FONT_SIZE: number = 10;

/** Finish revealing the live label while the page is still close to full size. */
export const TAB_OVERVIEW_CAPTION_FADE_IN_END_PROGRESS: number = 0.22;

/** Native interpolating-spring parameters for the overview release. */
export const TAB_OVERVIEW_SPRING_MASS: number = 1;
export const TAB_OVERVIEW_SPRING_STIFFNESS: number = 228;
export const TAB_OVERVIEW_SPRING_DAMPING: number = 30;
export const TAB_OVERVIEW_SPRING_MAX_NORMALIZED_VELOCITY: number = 3;

/** Case-insensitive title/URL search used by the tab overview search field. */
export function filterTabsByQuery(tabs: BrowserTabRecord[], query: string): BrowserTabRecord[] {
  const normalized: string = query.trim().toLocaleLowerCase();
  if (normalized.length === 0) {
    return tabs.slice();
  }
  return tabs.filter((tab: BrowserTabRecord) => tab.title.toLocaleLowerCase().includes(normalized) ||
    tab.displayUrl.toLocaleLowerCase().includes(normalized) ||
    tab.url.toLocaleLowerCase().includes(normalized));
}

/** Keep overlay controls below whichever top system region is larger. */
export function topContentInset(systemInset: number, cutoutInset: number): number {
  return Math.max(0, systemInset, cutoutInset);
}

/**
 * Return the one top spacer owned by the tab grid.
 *
 * The card itself must not add the same offset again: doing so makes the
 * first row look too low and increases every row's measured height.  Once the
 * pull-to-reveal search field is visible, its own margin already owns the
 * system inset, so the grid only needs a compact separation below it.
 */
export function tabOverviewTopPadding(topInset: number, searchRevealed: boolean): number {
  if (searchRevealed) {
    return 6;
  }
  return Math.max(24, topContentInset(topInset, 0) + 8);
}

/** Interpolate grid spacing while the search field is being pulled in/out. */
export function tabOverviewTopPaddingForProgress(topInset: number, progress: number): number {
  const clamped: number = Math.max(0, Math.min(1, progress));
  const hidden: number = tabOverviewTopPadding(topInset, false);
  const shown: number = tabOverviewTopPadding(topInset, true);
  return hidden + (shown - hidden) * clamped;
}

/** Height reserved above the card grid while the native search field is revealed. */
export function tabOverviewSearchSlotHeightForProgress(topInset: number, progress: number): number {
  const clamped: number = Math.max(0, Math.min(1, progress));
  return (10 + Math.max(0, topInset) + TAB_SEARCH_BAR_STYLE.height + 4) * clamped;
}

/** One shared top coordinate for both the card grid and the live page window. */
export function tabOverviewCardTopForProgress(topInset: number, progress: number): number {
  return tabOverviewSearchSlotHeightForProgress(topInset, progress) +
    tabOverviewTopPaddingForProgress(topInset, progress);
}

/** Calculate one card's width from the two-column grid's measured viewport. */
export function tabOverviewCardWidth(viewportWidth: number): number {
  const available: number = Math.max(0,
    viewportWidth - TAB_OVERVIEW_LAYOUT.horizontalPadding * 2 - TAB_OVERVIEW_LAYOUT.gap);
  return Math.max(1, available / TAB_OVERVIEW_LAYOUT.columns);
}

/** Height reserved by the overview toolbar below the card grid. */
export const TAB_OVERVIEW_BOTTOM_TOOLBAR_HEIGHT: number = 60;

/** Bottom padding included in the Grid content area. */
export const TAB_OVERVIEW_GRID_BOTTOM_PADDING: number = 10;

/**
 * Return the Grid's maximum vertical scroll offset for the current viewport.
 *
 * The active row cannot always be moved to the first visible row: when it is
 * near the end of the tab list, Grid stops at its content end. The live-page
 * transform must use that same clamped offset or it will land above the card
 * that owns its transparent shell.
 */
export function tabOverviewGridMaxScrollOffset(
  tabCount: number,
  viewportHeight: number,
  topInset: number,
  bottomInset: number,
  searchProgress: number = 0
): number {
  if (!Number.isFinite(tabCount) || tabCount <= 0 ||
    !Number.isFinite(viewportHeight) || viewportHeight <= 0) {
    return 0;
  }
  const rowCount: number = Math.ceil(Math.trunc(tabCount) / TAB_OVERVIEW_LAYOUT.columns);
  const contentHeight: number = rowCount * TAB_OVERVIEW_LAYOUT.cardHeight +
    Math.max(0, rowCount - 1) * TAB_OVERVIEW_LAYOUT.gap +
    TAB_OVERVIEW_GRID_BOTTOM_PADDING;
  const gridViewportHeight: number = Math.max(0,
    viewportHeight - tabOverviewSearchSlotHeightForProgress(topInset, searchProgress) -
    TAB_OVERVIEW_BOTTOM_TOOLBAR_HEIGHT - Math.max(0, Number.isFinite(bottomInset) ? bottomInset : 0) -
    tabOverviewTopPaddingForProgress(topInset, searchProgress));
  return Math.max(0, contentHeight - gridViewportHeight);
}

/**
 * Calculate the active row's requested scroll offset, clamped to Grid's
 * actual content range when the active tab is near the end of the list.
 */
export function tabOverviewActiveCardScrollOffset(
  activeIndex: number,
  maxScrollOffset: number = Number.POSITIVE_INFINITY
): number {
  if (!Number.isFinite(activeIndex) || activeIndex < 0) {
    return 0;
  }
  const row: number = Math.floor(Math.trunc(activeIndex) / TAB_OVERVIEW_LAYOUT.columns);
  const requested: number = row * (TAB_OVERVIEW_LAYOUT.cardHeight + TAB_OVERVIEW_LAYOUT.gap);
  return Number.isFinite(maxScrollOffset)
    ? Math.min(requested, Math.max(0, maxScrollOffset))
    : requested;
}

/**
 * Convert the live page's top avoid inset into the card's scaled coordinate.
 * BrowserTransitionScene applies this inset before the page-to-card scale;
 * static thumbnails need the same offset inside their card window.
 */
export function tabOverviewThumbnailTopOffset(topInset: number, viewportWidth: number): number {
  if (!Number.isFinite(topInset) || !Number.isFinite(viewportWidth) || viewportWidth <= 0) {
    return 0;
  }
  return Math.max(0, topInset) * tabOverviewCardWidth(viewportWidth) / viewportWidth;
}

/**
 * Pixel-space crop used by every static tab preview.
 *
 * The mounted page is scaled to the card width and clipped from its top edge.
 * ImageFit.Cover instead centers the crop on both axes, which makes a page
 * appear to jump vertically when the user opens a tab from the overview.
 */
export interface TabOverviewThumbnailCrop {
  scale: number;
  horizontalSourceOffset: number;
  verticalSourceOffset: number;
}

export function tabOverviewThumbnailCrop(
  sourceWidth: number,
  sourceHeight: number,
  containerWidth: number,
  containerHeight: number
): TabOverviewThumbnailCrop {
  const identity: TabOverviewThumbnailCrop = {
    scale: 1,
    horizontalSourceOffset: 0,
    verticalSourceOffset: 0
  };
  if (!Number.isFinite(sourceWidth) || !Number.isFinite(sourceHeight) ||
    !Number.isFinite(containerWidth) || !Number.isFinite(containerHeight) ||
    sourceWidth <= 0 || sourceHeight <= 0 || containerWidth <= 0 || containerHeight <= 0) {
    return identity;
  }
  const scale: number = Math.max(containerWidth / sourceWidth, containerHeight / sourceHeight);
  return {
    scale,
    // Preserve Cover's horizontal centering for wide pages, but deliberately
    // anchor the vertical crop at the same top edge as BrowserTransitionScene.
    horizontalSourceOffset: Math.max(0, (sourceWidth - containerWidth / scale) / 2),
    verticalSourceOffset: 0
  };
}

export interface TabOverviewSnapshotSize {
  width: number;
  height: number;
}

/**
 * Normalize the dimensions supplied to ArkWeb webPageSnapshot.
 *
 * webPageSnapshot expects the page's own CSS pixel dimensions. Falling back
 * to a square makes responsive pages render in a different viewport from the
 * mounted Web component, so the fallback keeps the current viewport aspect.
 */
export function tabOverviewSnapshotSize(
  pageWidth: number,
  pageHeight: number,
  viewportWidth: number,
  viewportHeight: number
): TabOverviewSnapshotSize {
  const fallbackWidth: number = 720;
  const safeViewportWidth: number = Number.isFinite(viewportWidth) && viewportWidth > 0
    ? viewportWidth
    : 1;
  const safeViewportHeight: number = Number.isFinite(viewportHeight) && viewportHeight > 0
    ? viewportHeight
    : 1;
  const width: number = Number.isFinite(pageWidth) && pageWidth > 0
    ? Math.max(1, Math.round(pageWidth))
    : fallbackWidth;
  const height: number = Number.isFinite(pageHeight) && pageHeight > 0
    ? Math.max(1, Math.round(pageHeight))
    : Math.max(1, Math.round(width * safeViewportHeight / safeViewportWidth));
  return { width, height };
}

/** Progress of the short visual handoff from the live page to the card grid. */
export function tabOverviewHandoffProgress(progress: number): number {
  const clampedProgress: number = clampOverviewProgress(progress);
  if (clampedProgress <= TAB_OVERVIEW_PAGE_HANDOFF_START_PROGRESS) {
    return 0;
  }
  return (clampedProgress - TAB_OVERVIEW_PAGE_HANDOFF_START_PROGRESS) /
    (1 - TAB_OVERVIEW_PAGE_HANDOFF_START_PROGRESS);
}

/** The grid is revealed only during the final live-page-to-card handoff. */
export function tabOverviewGridOpacityAtProgress(progress: number, hasLivePage: boolean): number {
  return hasLivePage ? tabOverviewHandoffProgress(progress) : 1;
}

/**
 * Opacity of the label that lives inside the same transformed layer as the
 * page. It fades in during the shrink and remains that page's only visible
 * label after landing. Keeping it alive at progress 1 lets the reverse spring
 * expand the exact same node instead of crossfading to a second card label.
 */
export function tabOverviewLiveCaptionOpacity(progress: number): number {
  const clampedProgress: number = clampOverviewProgress(progress);
  if (clampedProgress <= 0) {
    return 0;
  }
  if (clampedProgress < TAB_OVERVIEW_CAPTION_FADE_IN_END_PROGRESS) {
    return clampedProgress / TAB_OVERVIEW_CAPTION_FADE_IN_END_PROGRESS;
  }
  return 1;
}

/**
 * The fixed active card retains its caption layout as the close-button hit
 * target, but the live transformed page owns the pixels. Other cards continue
 * to render their normal caption.
 */
export function tabOverviewCardCaptionVisualOpacity(livePreview: boolean): number {
  return livePreview ? 0 : 1;
}

/**
 * The active live page and its transparent card shell share this close track.
 * Keeping the scalar values here prevents the shell from moving ahead while
 * the page stays behind it during a horizontal close gesture.
 */
export interface TabOverviewLivePageCloseFrame {
  horizontalOffset: number;
  scale: number;
  opacity: number;
}

export function tabOverviewLivePageCloseFrame(
  progress: number,
  horizontalOffset: number
): TabOverviewLivePageCloseFrame {
  const clampedProgress: number = clampOverviewProgress(progress);
  return {
    horizontalOffset: Number.isFinite(horizontalOffset) ? horizontalOffset : 0,
    scale: 1 - 0.06 * clampedProgress,
    opacity: Math.max(0.05, 1 - 0.95 * clampedProgress)
  };
}

/**
 * Native ArkWeb layers do not reliably follow an ancestor transform while a
 * card is being dismissed. Once a real thumbnail is available, let the card
 * shell own the closing pixels so the page and its frame share one transform.
 */
export function shouldUseTabOverviewCloseThumbnail(
  progress: number,
  hasThumbnail: boolean
): boolean {
  return hasThumbnail && clampOverviewProgress(progress) > 0;
}

/**
 * The live page and its card shell must never paint the selection ring at the
 * same time.  The live page owns the ring while it is moving or expanding
 * back; the card shell takes ownership only after the overview has settled.
 */
export type TabOverviewBorderOwner = 'none' | 'live-page' | 'card';

export function tabOverviewBorderOwner(
  progress: number,
  closing: boolean
): TabOverviewBorderOwner {
  const clampedProgress: number = clampOverviewProgress(progress);
  if (clampedProgress <= 0) {
    return 'none';
  }
  // During reverse expansion the live page must keep ownership so its ring
  // grows with the same frame as the page. During entry, hand ownership to
  // the fixed card in the final grid handoff segment to avoid a taller live
  // clip ring sitting outside the already-settled card bounds.
  if (closing) {
    return 'live-page';
  }
  if (clampedProgress < TAB_OVERVIEW_BORDER_HANDOFF_PROGRESS) {
    return 'live-page';
  }
  return 'card';
}

/**
 * Convert the last vertical gesture velocity into the normalized velocity
 * expected by ArkUI's interpolatingSpring curve.  The value is measured in
 * progress units per second relative to the remaining progress distance.
 */
export function tabOverviewSpringVelocity(
  startProgress: number,
  targetProgress: number,
  velocityY: number,
  viewportHeight: number
): number {
  const start: number = clampOverviewProgress(startProgress);
  const target: number = clampOverviewProgress(targetProgress);
  const distance: number = target - start;
  if (Math.abs(distance) < 0.0001 || !Number.isFinite(velocityY) ||
    !Number.isFinite(viewportHeight) || viewportHeight <= 0) {
    return 0;
  }
  // A negative screen-Y velocity means upward progress. Divide by the
  // signed remaining distance so the result is positive when the gesture is
  // already moving toward the requested spring target.
  const progressVelocity: number = -velocityY / viewportHeight;
  const normalized: number = progressVelocity / distance;
  return Math.max(-TAB_OVERVIEW_SPRING_MAX_NORMALIZED_VELOCITY,
    Math.min(TAB_OVERVIEW_SPRING_MAX_NORMALIZED_VELOCITY, normalized));
}

/** Build the native ArkUI easing string used by the shared frame animator. */
export function tabOverviewSpringEasing(
  startProgress: number,
  targetProgress: number,
  velocityY: number,
  viewportHeight: number
): string {
  const velocity: number = tabOverviewSpringVelocity(
    startProgress,
    targetProgress,
    velocityY,
    viewportHeight
  );
  return `interpolating-spring(${velocity.toFixed(3)}, ${TAB_OVERVIEW_SPRING_MASS}, ` +
    `${TAB_OVERVIEW_SPRING_STIFFNESS}, ${TAB_OVERVIEW_SPRING_DAMPING})`;
}

/**
 * One native transform track for the active live page during overview entry.
 * The frame starts as the full page and finishes at the active card's measured
 * slot. Keeping this geometry pure makes button entry and the upward pull use
 * exactly the same visual target without moving or remounting the WebView.
 */
export interface TabOverviewPageFrame {
  scaleX: number;
  scaleY: number;
  translateX: number;
  translateY: number;
  /** The stationary clip window that receives the live page during handoff. */
  clipLeft: number;
  clipTop: number;
  clipWidth: number;
  clipHeight: number;
  cornerRadius: number;
  /** Border belongs to the same transformed page layer, not the card shell. */
  borderWidth: number;
  /** The live title row uses local coordinates so it inherits this transform. */
  captionOpacity: number;
  captionLocalTop: number;
  captionLocalHeight: number;
  /** Local metric multiplier that resolves to 1 after the parent reaches its target scale. */
  captionContentScale: number;
}

/**
 * Resolve the caption's local radius so that, after the shared page-layer
 * scale is applied, its visible bottom corners match the live page outline.
 * The outline is in screen coordinates while the caption is inside the
 * transformed page layer, so reusing the raw radius directly causes the two
 * corners to diverge during the interactive shrink.
 */
export function tabOverviewCaptionLocalRadius(frame: TabOverviewPageFrame | undefined): number {
  if (frame === undefined || !Number.isFinite(frame.cornerRadius) ||
    !Number.isFinite(frame.scaleX) || frame.scaleX <= 0) {
    return 0;
  }
  return frame.cornerRadius / frame.scaleX;
}

/**
 * Screen-space choreography for the two pieces of browser chrome that must
 * remain visually related to the live page during the overview morph.
 *
 * `addressLeft`/`addressTop`/`addressWidth` describe the transition layout
 * box. `addressTop` is calculated for the compact 44vp root used while the
 * capsule tracks the page; normal mode moves its 56vp touch slot 8vp upward
 * before rendering the same visible capsule. The visible capsule is exposed
 * separately so tests can assert that it lands on the same card width as the
 * page frame.
 */
export interface TabOverviewChromeFrame {
  addressLeft: number;
  addressTop: number;
  addressWidth: number;
  addressScaleX: number;
  addressScaleY: number;
  addressOpacity: number;
  addressVisualLeft: number;
  addressVisualTop: number;
  addressVisualWidth: number;
  addressVisualHeight: number;
  addressJellyScaleX: number;
  addressJellyScaleY: number;
  addressJellyTranslateY: number;
  toolbarOpacity: number;
  toolbarTranslateY: number;
  toolbarScaleX: number;
  toolbarScaleY: number;
}

/**
 * The bottom chrome is one fixed surface shared by the normal page and the
 * overview transition. Keep that surface mounted through the settled overview
 * endpoint so the final transparent frame cannot trigger an unmount/remount
 * layout flash.
 */
export function shouldMountBottomBrowserBar(fullScreen: boolean): boolean {
  return !fullScreen;
}

/**
 * Keep the shared address capsule alive through the overview handoff. At the
 * settled overview endpoint it is transparent and hit-test disabled, but
 * keeping the node mounted prevents a short reverse drag from losing the
 * first frame when the capsule returns to the bottom chrome.
 */
export function shouldMountAddressTransitionLayer(fullScreen: boolean): boolean {
  return !fullScreen;
}

/**
 * The address layer is a sibling of the bottom chrome and must win every
 * reverse-drag z-order race. Its child remains the only interactive address
 * surface, so the full-window parent does not steal page touches.
 */
export function tabOverviewAddressLayerZIndex(): number {
  return 40;
}

/**
 * During reverse expansion the live page sits above the overview cards at
 * z-index 20. Put the returning toolbar above that page, while keeping the
 * shared address capsule above both layers.
 */
export function tabOverviewBottomChromeZIndex(closing: boolean): number {
  return closing ? 25 : 10;
}

/** Short screen-space handoff after the card bottom reaches the address row. */
export const TAB_OVERVIEW_ADDRESS_ATTACH_DURATION_PROGRESS: number = 0.08;
/** Address-only jelly remains independent from the toolbar exit handoff. */
export const TAB_OVERVIEW_ADDRESS_JELLY_START_PROGRESS: number = 0.22;
export const TAB_OVERVIEW_ADDRESS_JELLY_END_PROGRESS: number = 0.44;
/** The bottom toolbar leaves in one short rebound after its dynamic exit point. */
export const TAB_OVERVIEW_TOOLBAR_HIDE_DURATION_PROGRESS: number = 0.20;

/** Reverse expansion keeps the toolbar below the page until the address rejoins. */
export const TAB_OVERVIEW_ADDRESS_RETURN_JELLY_END_PROGRESS: number = 0.18;

/** Handoff the transient address capsule to the settled card caption. */
export const TAB_OVERVIEW_ADDRESS_HANDOFF_START_PROGRESS: number = 0.82;
export const TAB_OVERVIEW_ADDRESS_HANDOFF_END_PROGRESS: number = 0.90;
export const TAB_OVERVIEW_CAPTION_HANDOFF_START_PROGRESS: number = 0.90;
export const TAB_OVERVIEW_CAPTION_HANDOFF_END_PROGRESS: number = 0.98;

function overviewSegmentProgress(progress: number, start: number, end: number): number {
  if (end <= start) {
    return progress >= end ? 1 : 0;
  }
  return Math.max(0, Math.min(1, (progress - start) / (end - start)));
}

/** A bounded bell keeps the jelly directly driven by the shared progress. */
function overviewJellyProgress(progress: number, start: number, end: number): number {
  const segment: number = overviewSegmentProgress(progress, start, end);
  return Math.sin(Math.PI * segment);
}

/**
 * The live page caption is the settled card label. Fade it in only during the
 * final grid handoff so a miniature address field is not left visible under
 * an already-settled card.
 */
export function tabOverviewCaptionHandoffOpacity(progress: number, _closing: boolean): number {
  const handoff: number = overviewSegmentProgress(
    progress,
    TAB_OVERVIEW_CAPTION_HANDOFF_START_PROGRESS,
    TAB_OVERVIEW_CAPTION_HANDOFF_END_PROGRESS
  );
  // The same track is reversible: progress falls during dismissal, so the
  // caption naturally fades out without a second animation timeline.
  return handoff;
}

/** Find the progress at which the shrinking card reaches the address row. */
function tabOverviewAddressAttachStartProgress(
  viewportHeight: number,
  addressTop: number,
  addressHeight: number,
  targetCardBottom: number,
  targetScaleY: number
): number {
  const initialGap: number = viewportHeight - (addressTop + addressHeight);
  const targetGap: number = targetCardBottom -
    (addressTop + addressHeight * targetScaleY);
  const denominator: number = initialGap - targetGap;
  if (!Number.isFinite(denominator) || denominator <= 0) {
    return 1;
  }
  return Math.max(0, Math.min(1, initialGap / denominator));
}

/** Find when the card bottom has completely cleared the fixed bottom chrome. */
function tabOverviewToolbarExitProgress(
  viewportHeight: number,
  chromeHeight: number,
  targetCardBottom: number
): number {
  const distance: number = viewportHeight - targetCardBottom;
  if (!Number.isFinite(distance) || distance <= 0) {
    return 1;
  }
  return Math.max(0, Math.min(1, chromeHeight / distance));
}

/**
 * Build the address/toolbar frame from the same page progress as the live
 * page. The address capsule uses the page frame's target scale and visible
 * width, while its local layout box compensates for ArkUI's center scaling so
 * the rendered capsule remains aligned with the page card.
 */
export function tabOverviewChromeFrame(
  progress: number,
  closing: boolean,
  viewportWidth: number,
  viewportHeight: number,
  chromeHeight: number,
  pageFrame: TabOverviewPageFrame
): TabOverviewChromeFrame {
  const clampedProgress: number = clampOverviewProgress(progress);
  const width: number = Number.isFinite(viewportWidth) && viewportWidth > 0 ? viewportWidth : 1;
  const height: number = Number.isFinite(viewportHeight) && viewportHeight > 0 ? viewportHeight : 1;
  const safeChromeHeight: number = Number.isFinite(chromeHeight) && chromeHeight > 0
    ? chromeHeight
    : 0;
  const pageScale: number = Math.max(0.01, Math.min(1,
    Number.isFinite(pageFrame.scaleX) ? pageFrame.scaleX : 1));
  const pageScaleY: number = Math.max(0.01, Math.min(1,
    Number.isFinite(pageFrame.scaleY) ? pageFrame.scaleY : pageScale));
  const fullLeft: number = 8;
  const fullTop: number = height - safeChromeHeight + ADDRESS_SEARCH_BAR_TOP_PADDING;
  const fullWidth: number = Math.max(1, width - 16);
  const fullHeight: number = ADDRESS_SEARCH_BAR_STYLE.height;

  // `pageFrame` is already evaluated at `clampedProgress`. Do not interpolate
  // from the current frame a second time: doing so makes the address strip
  // lag behind the live page during the gesture and leaves a visible gap
  // between the card bottom and the capsule. Recover the final card geometry
  // once, then place the capsule on the same single progress track.
  const progressForTarget: number = Math.max(0.0001, clampedProgress);
  const targetScaleY: number = clampedProgress > 0
    ? 1 + (pageFrame.scaleY - 1) / progressForTarget
    : 1;
  const targetLeft: number = clampedProgress > 0
    ? pageFrame.clipLeft / progressForTarget
    : 0;
  const targetTop: number = clampedProgress > 0
    ? pageFrame.clipTop / progressForTarget
    : 0;
  const targetWidth: number = clampedProgress > 0
    ? width + (pageFrame.clipWidth - width) / progressForTarget
    : width;
  const targetHeight: number = clampedProgress > 0
    ? height + (pageFrame.clipHeight - height) / progressForTarget
    : height;
  const scaleX: number = pageScale;
  const scaleY: number = pageScaleY;
  const currentCardBottom: number = pageFrame.clipTop + pageFrame.clipHeight;
  const addressHeight: number = fullHeight * scaleY;
  const addressHandoff: number = overviewSegmentProgress(
    clampedProgress,
    TAB_OVERVIEW_ADDRESS_HANDOFF_START_PROGRESS,
    TAB_OVERVIEW_ADDRESS_HANDOFF_END_PROGRESS
  );
  // The card caption is a fixed 32vp screen-space row. During the final
  // address handoff, morph the address row to that same height instead of
  // letting the 44vp field remain smaller after page scaling completes.
  const captionVisualHeight: number = TAB_OVERVIEW_CAPTION_HEIGHT;
  const visualHeight: number = interpolateOverviewValue(
    addressHeight,
    captionVisualHeight,
    addressHandoff
  );
  const attachStart: number = tabOverviewAddressAttachStartProgress(
    height,
    fullTop,
    fullHeight,
    targetTop + targetHeight,
    targetScaleY
  );
  const attachEnd: number = Math.min(
    1,
    attachStart + TAB_OVERVIEW_ADDRESS_ATTACH_DURATION_PROGRESS
  );
  const attachProgress: number = overviewSegmentProgress(
    clampedProgress,
    attachStart,
    attachEnd
  );
  const attachedTop: number = currentCardBottom - visualHeight;
  const visualLeft: number = interpolateOverviewValue(
    fullLeft, targetLeft, clampedProgress
  );
  const visualTop: number = interpolateOverviewValue(
    fullTop, attachedTop, attachProgress
  );
  const visualWidth: number = interpolateOverviewValue(
    fullWidth, targetWidth, clampedProgress
  );
  const layoutWidth: number = Math.max(16, visualWidth / Math.max(0.01, scaleX) + 16);
  // The strip's active capsule is centered with an 8vp inset in its local box.
  // Compensate for ArkUI's center-based scale before placing that box.
  const addressLeft: number = visualLeft - 8 * scaleX - layoutWidth * (1 - scaleX) / 2;
  // During the morph the root must have the same 44vp height as the visible
  // field. Retaining the normal 56vp slot here leaves an empty scaled band
  // above/below the capsule and produces the oversized transient seen in the
  // overview screenshots.
  const addressScaleY: number = visualHeight / Math.max(0.01, fullHeight);
  const addressTop: number = visualTop - (fullHeight - visualHeight) / 2;
  const jellyProgress: number = closing
    ? overviewJellyProgress(clampedProgress, 0, TAB_OVERVIEW_ADDRESS_RETURN_JELLY_END_PROGRESS)
    : overviewJellyProgress(
      clampedProgress,
      TAB_OVERVIEW_ADDRESS_JELLY_START_PROGRESS,
      TAB_OVERVIEW_ADDRESS_JELLY_END_PROGRESS
    );
  const toolbarExitStart: number = tabOverviewToolbarExitProgress(
    height,
    safeChromeHeight,
    targetTop + targetHeight
  );
  const toolbarExitEnd: number = Math.min(
    1,
    toolbarExitStart + TAB_OVERVIEW_TOOLBAR_HIDE_DURATION_PROGRESS
  );
  const toolbarHideProgress: number = overviewSegmentProgress(
    clampedProgress,
    toolbarExitStart,
    toolbarExitEnd
  );
  const toolbarJellyProgress: number = overviewJellyProgress(
    clampedProgress,
    toolbarExitStart,
    toolbarExitEnd
  );
  const addressOpacity: number = 1 - addressHandoff;
  const toolbarJellyAnchorOffset: number = toolbarJellyProgress * safeChromeHeight * 0.05;
  const toolbarOpacity: number = 1 - toolbarHideProgress;
  const toolbarTranslateY: number = safeChromeHeight * toolbarHideProgress -
    toolbarJellyAnchorOffset;
  return {
    addressLeft,
    addressTop,
    addressWidth: layoutWidth,
    addressScaleX: scaleX,
    addressScaleY,
    addressOpacity,
    addressVisualLeft: visualLeft,
    addressVisualTop: visualTop,
    addressVisualWidth: visualWidth,
    addressVisualHeight: visualHeight,
    addressJellyScaleX: 1 + jellyProgress * (closing ? 0.05 : 0.032),
    addressJellyScaleY: 1 - jellyProgress * (closing ? 0.12 : 0.08),
    addressJellyTranslateY: -jellyProgress * (closing ? 4 : 3),
    toolbarOpacity,
    toolbarTranslateY,
    toolbarScaleX: 1 + toolbarJellyProgress * 0.04,
    // Keep the bottom edge visually anchored while the top edge stretches up.
    toolbarScaleY: 1 + toolbarJellyProgress * 0.10
  };
}

function clampOverviewProgress(progress: number): number {
  if (!Number.isFinite(progress)) {
    return 0;
  }
  return Math.max(0, Math.min(1, progress));
}

function interpolateOverviewValue(start: number, end: number, progress: number): number {
  return start + (end - start) * progress;
}

/** Calculate the full-page-to-active-card transform used by the live page. */
export function tabOverviewPageFrame(
  progress: number,
  viewportWidth: number,
  viewportHeight: number,
  activeIndex: number,
  topInset: number,
  searchProgress: number = 0,
  activeCardScrollOffset: number = 0
): TabOverviewPageFrame {
  const identity: TabOverviewPageFrame = {
    scaleX: 1,
    scaleY: 1,
    translateX: 0,
    translateY: 0,
    clipLeft: 0,
    clipTop: 0,
    clipWidth: viewportWidth,
    clipHeight: viewportHeight,
    cornerRadius: 0,
    borderWidth: 0,
    captionOpacity: 0,
    captionLocalTop: Math.max(0, viewportHeight - TAB_OVERVIEW_CAPTION_HEIGHT),
    captionLocalHeight: TAB_OVERVIEW_CAPTION_HEIGHT,
    captionContentScale: 1
  };
  if (!Number.isFinite(viewportWidth) || !Number.isFinite(viewportHeight) ||
    viewportWidth <= 0 || viewportHeight <= 0 || activeIndex < 0) {
    return identity;
  }

  const clampedProgress: number = clampOverviewProgress(progress);
  const cardWidth: number = tabOverviewCardWidth(viewportWidth);
  const cardHeight: number = TAB_OVERVIEW_LAYOUT.cardHeight;
  const column: number = activeIndex % TAB_OVERVIEW_LAYOUT.columns;
  const row: number = Math.floor(activeIndex / TAB_OVERVIEW_LAYOUT.columns);
  const targetLeft: number = TAB_OVERVIEW_LAYOUT.horizontalPadding +
    column * (cardWidth + TAB_OVERVIEW_LAYOUT.gap);
  const targetTop: number = tabOverviewCardTopForProgress(topInset, searchProgress) +
    row * (cardHeight + TAB_OVERVIEW_LAYOUT.gap) -
    (Number.isFinite(activeCardScrollOffset) ? Math.max(0, activeCardScrollOffset) : 0);
  // Preserve the WebView's aspect ratio.  The card is intentionally shorter
  // than the page, so the page is fitted to the card width and the shared
  // clip window crops the lower part instead of vertically squeezing content.
  const targetScale: number = cardWidth / viewportWidth;
  const scale: number = interpolateOverviewValue(1, targetScale, clampedProgress);
  // ArkUI scales around the layer center. Compensate the center shift so the
  // scaled layer's top-left corner stays aligned with the clip window.
  const targetTranslateX: number = targetLeft - viewportWidth * (1 - targetScale) / 2;
  const targetTranslateY: number = targetTop - viewportHeight * (1 - targetScale) / 2;
  const clipHeight: number = interpolateOverviewValue(viewportHeight, cardHeight, clampedProgress);
  // Keep the label inside the same scaled layer while pinning its rendered
  // bottom edge to the current clip window. Resolve its local metrics from
  // the current page scale so the visible title row stays the same 32vp as
  // the settled card throughout the shrink.
  const captionLocalHeight: number = TAB_OVERVIEW_CAPTION_HEIGHT / Math.max(0.01, scale);
  const captionLocalTop: number = Math.max(0, clipHeight / scale - captionLocalHeight);
  return {
    scaleX: scale,
    scaleY: scale,
    translateX: interpolateOverviewValue(0, targetTranslateX, clampedProgress),
    translateY: interpolateOverviewValue(0, targetTranslateY, clampedProgress),
    clipLeft: interpolateOverviewValue(0, targetLeft, clampedProgress),
    clipTop: interpolateOverviewValue(0, targetTop, clampedProgress),
    clipWidth: interpolateOverviewValue(viewportWidth, cardWidth, clampedProgress),
    clipHeight: clipHeight,
    // The live page already has the same rounded screen surface before the
    // overview starts. Keep that outer radius stable so the first frame does
    // not flash from square corners into the card's rounded corners.
    cornerRadius: TAB_OVERVIEW_LAYOUT.cardRadius,
    borderWidth: interpolateOverviewValue(0, 2, clampedProgress),
    captionOpacity: tabOverviewLiveCaptionOpacity(clampedProgress),
    captionLocalTop: captionLocalTop,
    captionLocalHeight: captionLocalHeight,
    captionContentScale: 1 / Math.max(0.01, scale)
  };
}
