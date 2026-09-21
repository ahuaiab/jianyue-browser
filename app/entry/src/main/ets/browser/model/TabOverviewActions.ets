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

/**
 * Reveal the rear cards as soon as the live page has visibly started shrinking.
 * Keeping this before the final caption handoff lets the overview read as a
 * stack of pages throughout the morph instead of a lone page that suddenly
 * becomes a grid at the endpoint.
 */
export const TAB_OVERVIEW_PAGE_HANDOFF_START_PROGRESS: number = 0.35;

/** Keep the rear cards legible on the very first non-zero shrink frame. */
export const TAB_OVERVIEW_GRID_START_OPACITY: number = 0.28;

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

/** Short, reversible handoff that removes the normal page's top safe area. */
export const TAB_OVERVIEW_SAFE_INSET_HANDOFF_PROGRESS: number = 0.08;

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
 * Keep every static thumbnail flush with the card's top edge.
 *
 * The grid's top spacer already owns the system avoid area. Applying that
 * inset again inside a PixelMap translates the image down and leaves a white
 * strip above inactive cards, while the active live-page card starts at the
 * card edge. Static snapshots therefore use the same zero local offset as
 * the live card; the parameters remain part of the helper's call contract so
 * the card layout has one explicit policy for all preview types.
 */
export function tabOverviewThumbnailTopOffset(_topInset: number, _viewportWidth: number): number {
  return 0;
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

/** Reveal the grid progressively while the live page is still shrinking. */
export function tabOverviewGridOpacityAtProgress(progress: number, hasLivePage: boolean): number {
  if (!hasLivePage) {
    return 1;
  }
  const clampedProgress: number = clampOverviewProgress(progress);
  return TAB_OVERVIEW_GRID_START_OPACITY +
    (1 - TAB_OVERVIEW_GRID_START_OPACITY) * clampedProgress;
}

/**
 * Resolve the overview grid opacity for the transition direction.
 *
 * Entry keeps a small baseline opacity so rear cards are visible as soon as
 * the live page starts shrinking. Reverse expansion has a different visual
 * owner: the live page is already expanding from the selected card, so the
 * grid must leave immediately instead of leaving translucent thumbnails over
 * the desktop background.
 */
export function tabOverviewGridOpacityForTransition(
  progress: number,
  hasLivePage: boolean,
  closing: boolean
): number {
  if (closing && hasLivePage) {
    return 0;
  }
  return tabOverviewGridOpacityAtProgress(progress, hasLivePage);
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
 * same time. The live page is the foreground layer for the whole overview
 * morph, so it remains the ring owner after reaching the card slot as well.
 * The card shell is underneath the live page and its ring would otherwise be
 * hidden in the settled frame.
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
  // The live page outline is rendered after its page content inside the
  // foreground scene. Keep ownership through both settled entry and reverse
  // expansion so the selected ring cannot be occluded by the lower grid.
  return 'live-page';
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
  /** Shared 0..1 morph progress used by layout helpers without inferring it from scale. */
  transitionProgress: number;
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
 * Local clip window for the full-size page layer before its overview scale.
 * The page layer scales around its center, so a screen-space card rectangle
 * must be inverse-transformed before it can clip the native page contents.
 */
export interface TabOverviewLocalPageClipFrame {
  left: number;
  top: number;
  width: number;
  height: number;
  cornerRadius: number;
}

export function tabOverviewLocalPageClipFrame(
  frame: TabOverviewPageFrame | undefined,
  viewportWidth: number,
  viewportHeight: number
): TabOverviewLocalPageClipFrame {
  const safeWidth: number = Number.isFinite(viewportWidth) && viewportWidth > 0 ? viewportWidth : 1;
  const safeHeight: number = Number.isFinite(viewportHeight) && viewportHeight > 0 ? viewportHeight : 1;
  if (frame === undefined) {
    return { left: 0, top: 0, width: safeWidth, height: safeHeight, cornerRadius: 0 };
  }
  const scaleX: number = Number.isFinite(frame.scaleX) && Math.abs(frame.scaleX) > 0.01
    ? Math.abs(frame.scaleX) : 1;
  const scaleY: number = Number.isFinite(frame.scaleY) && Math.abs(frame.scaleY) > 0.01
    ? Math.abs(frame.scaleY) : 1;
  const translateX: number = Number.isFinite(frame.translateX) ? frame.translateX : 0;
  const translateY: number = Number.isFinite(frame.translateY) ? frame.translateY : 0;
  const clipLeft: number = Number.isFinite(frame.clipLeft) ? frame.clipLeft : 0;
  const clipTop: number = Number.isFinite(frame.clipTop) ? frame.clipTop : 0;
  const clipWidth: number = Number.isFinite(frame.clipWidth) && frame.clipWidth > 0
    ? frame.clipWidth : safeWidth;
  const clipHeight: number = Number.isFinite(frame.clipHeight) && frame.clipHeight > 0
    ? frame.clipHeight : safeHeight;
  const localLeft: number = safeWidth / 2 +
    (clipLeft - translateX - safeWidth / 2) / scaleX;
  const localTop: number = safeHeight / 2 +
    (clipTop - translateY - safeHeight / 2) / scaleY;
  const localRadius: number = Number.isFinite(frame.cornerRadius)
    ? Math.max(0, frame.cornerRadius) / Math.min(scaleX, scaleY) : 0;
  return {
    left: localLeft,
    top: localTop,
    width: Math.max(1, clipWidth / scaleX),
    height: Math.max(1, clipHeight / scaleY),
    cornerRadius: localRadius
  };
}

/**
 * Resolve the page scene's top inset for the current transform.
 *
 * The normal page is laid out below the system avoid area. During the
 * overview morph, however, the page is already positioned inside the card's
 * transformed coordinate space. Applying the same inset to NodeContainer a
 * second time leaves a visible gap between the blue card outline and the
 * page image. Keep the normal inset at the identity frame, then hand it off
 * over a short smooth segment so the transformed frame owns the complete
 * page viewport without a first-frame jump. The grid and card frame already
 * own the safe-area spacing; retaining it after the handoff would scale a
 * white strip into the card's top edge.
 */
export function tabOverviewLivePageContentTop(
  frame: TabOverviewPageFrame | undefined,
  normalTopInset: number
): number {
  const safeInset: number = Number.isFinite(normalTopInset) ? Math.max(0, normalTopInset) : 0;
  if (frame === undefined) {
    return safeInset;
  }
  const progress: number = clampOverviewProgress(frame.transitionProgress);
  if (progress <= 0 || safeInset <= 0) {
    return safeInset;
  }
  const handoff: number = Math.min(1, progress / TAB_OVERVIEW_SAFE_INSET_HANDOFF_PROGRESS);
  // Smoothstep keeps both the first frame and the zero-inset endpoint
  // velocity-neutral, so reverse expansion does not visibly spring at either
  // end of the safe-area handoff.
  const eased: number = handoff * handoff * (3 - 2 * handoff);
  return safeInset * (1 - eased);
}

/**
 * Keep the page layout viewport stable while it is transformed. Resizing the
 * start page changes its Cover crop and makes the wallpaper visibly shift as
 * reverse expansion reaches the identity frame.
 */
export function tabOverviewLivePageContentHeight(
  _frame: TabOverviewPageFrame | undefined,
  viewportHeight: number,
  normalTopInset: number
): number {
  const safeHeight: number = Number.isFinite(viewportHeight) && viewportHeight > 0
    ? viewportHeight
    : 1;
  const safeInset: number = Number.isFinite(normalTopInset) ? Math.max(0, normalTopInset) : 0;
  return Math.max(1, safeHeight - safeInset);
}

/**
 * The transformed page is backed by a native ArkWeb surface. Keep the outer
 * transition viewport as a hard paint boundary so reverse expansion cannot
 * leak page pixels into the status-bar avoid area before the identity frame
 * restores the normal top inset.
 */
export function tabOverviewTransitionViewportClipsOverflow(): boolean {
  return true;
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
 * The live page sits above the overview cards at z-index 20 in both
 * directions. Keep the fixed toolbar/bottom bar above that page as well, so
 * the page background cannot cover the chrome while the transition is running;
 * the shared address capsule remains above both layers at z-index 40.
 */
export function tabOverviewBottomChromeZIndex(closing: boolean): number {
  return 25;
}

/**
 * Do not revoke hit testing from the bottom chrome while its vertical pan is
 * still active. Changing the gesture owner's parent to HitTestMode.None on
 * the first non-zero overview frame prevents ArkUI from delivering the final
 * action-end/cancel callback and strands the shared progress mid-transition.
 */
export function shouldDisableBottomChromeHitTesting(
  overviewProgress: number,
  gestureInProgress: boolean,
  overviewClosing: boolean
): boolean {
  if (overviewClosing) {
    return true;
  }
  return clampOverviewProgress(overviewProgress) > 0 && !gestureInProgress;
}

/**
 * Keep the selected live page above the overview grid while either direction
 * is moving. At the settled endpoint the grid becomes the foreground hit
 * owner so the native NodeContainer cannot steal card interactions.
 */
export function tabOverviewGridZIndex(
  overviewProgress: number = 0,
  overviewClosing: boolean = false
): number {
  // The transformed live page must lead while it is moving, otherwise rear
  // cards can paint over the current card during the morph. At the settled
  // endpoint, however, the Grid must become the top ArkUI hit owner: native
  // ArkWeb content can keep consuming pointer streams even after an ancestor
  // is switched to HitTestMode.None.
  if (!overviewClosing && clampOverviewProgress(overviewProgress) >= 1) {
    return 25;
  }
  return 15;
}

/**
 * The selected page owns the foreground for entry and reverse dismissal.
 * Keeping one value avoids a one-frame layer swap when the direction changes.
 */
export function tabOverviewLivePageZIndex(_closing: boolean): number {
  return 20;
}

/**
 * The live page remains visually above the overview cards, but it must leave
 * the hit-test chain as soon as the overview starts so card taps reach Grid.
 */
export function shouldDisableTabOverviewLivePageHitTesting(progress: number): boolean {
  return clampOverviewProgress(progress) > 0;
}

/** Short screen-space handoff after the card bottom reaches the address row. */
export const TAB_OVERVIEW_ADDRESS_ATTACH_DURATION_PROGRESS: number = 0.08;
/** The bottom toolbar leaves in one short, monotonic handoff after its exit point. */
export const TAB_OVERVIEW_TOOLBAR_HIDE_DURATION_PROGRESS: number = 0.20;

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
  pageFrame: TabOverviewPageFrame,
  restingChromeLeft: number = 0,
  restingChromeWidth: number = viewportWidth
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
  const safeRestingLeft: number = Number.isFinite(restingChromeLeft)
    ? restingChromeLeft
    : 0;
  const safeRestingWidth: number = Number.isFinite(restingChromeWidth) && restingChromeWidth > 0
    ? restingChromeWidth
    : width;
  const fullLeft: number = safeRestingLeft + 8;
  const fullTop: number = height - safeChromeHeight + ADDRESS_SEARCH_BAR_TOP_PADDING;
  const fullWidth: number = Math.max(1, safeRestingWidth - 16);
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
  const addressOpacity: number = 1 - addressHandoff;
  const toolbarOpacity: number = 1 - toolbarHideProgress;
  const toolbarTranslateY: number = safeChromeHeight * toolbarHideProgress;
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
    // Keep the address and toolbar on the shared geometry track. The former
    // bell-shaped jelly pass caused a visible rebound at both ends of the
    // overview transition, especially while reversing the gesture.
    addressJellyScaleX: 1,
    addressJellyScaleY: 1,
    addressJellyTranslateY: 0,
    toolbarOpacity,
    toolbarTranslateY,
    toolbarScaleX: 1,
    toolbarScaleY: 1
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
    transitionProgress: 0,
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
    transitionProgress: clampedProgress,
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
