import {
  newTabBackgroundProgressForPullProgress, TabPreviewKind
} from './TabGestureMotion';

export interface SafariTransitionFrame {
  progress: number;
  currentPageX: number;
  targetPageX: number;
  currentAddressX: number;
  targetAddressX: number;
  targetIndex: number;
  previewKind: TabPreviewKind;
}

export interface NewTabPreviewVisual {
  showPagePlus: boolean;
  showAddressPlus: boolean;
  addressPlusOpacity: number;
  addressBackgroundOpacity: number;
}

/** The transient address surface must clip its own background to the capsule. */
export interface AddressPreviewSurfaceVisual {
  cornerRadius: number;
  clipsChildren: boolean;
}

export interface NewTabHandoffVisual {
  plusOpacity: number;
  placeholderOpacity: number;
  plusScale: number;
  placeholderScale: number;
  placeholderSlideProgress: number;
  placeholderTextAlignment: 'start' | 'center';
}

export interface TabTransitionSceneVisualState {
  currentX: number;
  previewX: number;
  previewKind: TabPreviewKind;
  showPreview: boolean;
  /** The new-tab affordance belongs to AddressTabStrip, never this page scene. */
  showPagePlus: boolean;
}

export function shouldRenderAddressHandoff(active: boolean, progress: number): boolean {
  return active || finite(progress) < 1;
}

function finite(value: number): number {
  return Number.isFinite(value) ? value : 0;
}

function clamp(value: number, lower: number = -1, upper: number = 1): number {
  return Math.max(lower, Math.min(upper, value));
}

/**
 * Keep the two page layers alive for the whole pointer-driven transition.
 * The committed tab model is updated only after the settle animation ends.
 */
export function tabTransitionSceneVisualState(
  currentX: number,
  previewX: number,
  previewKind: TabPreviewKind,
  showPreview: boolean
): TabTransitionSceneVisualState {
  return {
    currentX: finite(currentX),
    previewX: finite(previewX),
    previewKind,
    showPreview: showPreview && previewKind !== TabPreviewKind.NONE,
    showPagePlus: false
  };
}

/**
 * A transition preview must be backed by one stable owner. An asynchronous
 * StartPage fallback can briefly mount a second image layer at the viewport
 * edge, so the caller should wait for either a native host or a PixelMap.
 */
export function shouldRenderStableTabPreview(
  hasPreviewHost: boolean,
  hasPreviewThumbnail: boolean
): boolean {
  return hasPreviewHost || hasPreviewThumbnail;
}

/**
 * A blank start tab has a real native page even before its image PixelMap is
 * ready. Keep that page in the transition tree so a freshly selected image
 * cannot leave a white hole at the incoming edge.
 */
export function shouldRenderTabPreviewContent(
  showPreview: boolean,
  previewIsStartPage: boolean,
  hasPreviewHost: boolean,
  hasPreviewThumbnail: boolean
): boolean {
  return showPreview && (previewIsStartPage || hasPreviewHost || hasPreviewThumbnail);
}

/**
 * Keep a blank tab on its captured frame while a newly committed start page
 * is handing the address capsule back to the normal browser chrome. The
 * native Image frame is already rendered, while a freshly mounted StartPage
 * may still be waiting for its gallery image to decode.
 */
export function shouldPreferStableStartPageFrame(
  isStartPage: boolean,
  handoffActive: boolean,
  hasThumbnail: boolean
): boolean {
  return isStartPage && handoffActive && hasThumbnail;
}

/**
 * A start-page snapshot must not replace the handoff frame while the address
 * capsule is still settling. The native snapshot can contain the not-yet-
 * painted StartPage and would briefly turn the page layer white.
 */
export function shouldCaptureStartPageThumbnailNow(
  gestureActive: boolean,
  addressHandoffActive: boolean
): boolean {
  return !gestureActive && !addressHandoffActive;
}

export function sceneOffsetForIndex(index: number, activeIndex: number, pageWidth: number, dragX: number): number {
  const width: number = Math.max(1, finite(pageWidth));
  return (index - activeIndex) * width + finite(dragX);
}

export function addressOffsetForIndex(index: number, activeIndex: number, addressStride: number,
  dragX: number, pageWidth: number): number {
  const width: number = Math.max(1, finite(pageWidth));
  const stride: number = Math.max(1, finite(addressStride));
  return (index - activeIndex) * stride + clamp(finite(dragX) / width) * stride;
}

export function addressItemLeft(index: number, activeIndex: number, itemWidth: number,
  gap: number, dragX: number, pageWidth: number): number {
  const width: number = Math.max(1, finite(pageWidth));
  const capsuleWidth: number = Math.max(1, finite(itemWidth));
  return (width - capsuleWidth) / 2 + addressOffsetForIndex(index, activeIndex,
    capsuleWidth + gap, dragX, width);
}

/**
 * Keep a reserved new-tab capsule on its original visual slot while the
 * draft is inserted into the committed tab list. Before insertion the draft
 * lives at the end of the list; afterwards its stable id identifies that
 * same index. Using `tabs.length` after insertion would add one stride and
 * cause the capsule to jump for a render frame.
 */
export function pendingTabVisualIndex(pendingTabId: string, tabIds: string[]): number {
  const normalizedId: string = pendingTabId.trim();
  const committedIndex: number = normalizedId.length === 0 ? -1 : tabIds.indexOf(normalizedId);
  return committedIndex >= 0 ? committedIndex : tabIds.length;
}

/** A final tab can prepare its render-only neighbour before pointer motion. */
export function shouldPrimeFinalTabPreview(activeIndex: number, tabCount: number): boolean {
  const count: number = Math.max(0, Math.trunc(finite(tabCount)));
  const index: number = Math.trunc(finite(activeIndex));
  return count > 0 && index === count - 1;
}

/** Keep the idle strip clean while retaining one target during a horizontal drag. */
export function shouldRenderAddressItem(index: number, activeIndex: number, dragX: number,
  tabCount: number, previewKind: TabPreviewKind = TabPreviewKind.EXISTING_TAB,
  handoffOwnsAddressSlot: boolean = false): boolean {
  const count: number = Math.max(0, Math.trunc(finite(tabCount)));
  const item: number = Math.trunc(finite(index));
  const active: number = Math.trunc(finite(activeIndex));
  if (handoffOwnsAddressSlot && item === active) {
    return false;
  }
  if (count <= 0 || active < 0 || active >= count || item === active) {
    return count > 0 && item === active;
  }
  if (!Number.isFinite(dragX) || dragX === 0 || previewKind !== TabPreviewKind.EXISTING_TAB) {
    return false;
  }
  const target: number = active + (dragX < 0 ? 1 : -1);
  return target >= 0 && target < count && item === target;
}

/**
 * An address item may fade out only when it is a transient adjacent preview.
 * During the committed new-tab handoff the old active item is removed at the
 * same coordinate as the handoff capsule; an exit transition would leave both
 * owners composited for one or more frames and produce a visible flash.
 */
export function shouldAnimateAddressItemExit(
  index: number,
  activeIndex: number,
  handoffMounted: boolean
): boolean {
  if (handoffMounted) {
    return false;
  }
  return Math.trunc(finite(index)) !== Math.trunc(finite(activeIndex));
}

/**
 * Keep the target capsule on the same track as the page, but let it emerge
 * after the gesture has established a direction. This removes the instant
 * second-capsule pop at the first PanGesture frame without delaying the
 * settled address value.
 */
export function addressPreviewOpacity(
  index: number,
  activeIndex: number,
  dragX: number,
  pageWidth: number
): number {
  if (Math.trunc(finite(index)) === Math.trunc(finite(activeIndex))) {
    return 1;
  }
  const normalized: number = Math.abs(finite(dragX)) / Math.max(1, finite(pageWidth));
  const fadeStart: number = 0.08;
  const fadeEnd: number = 0.20;
  return clamp((normalized - fadeStart) / (fadeEnd - fadeStart), 0, 1);
}

export function safariTransitionFrame(dragX: number, pageWidth: number, addressStride: number,
  activeIndex: number, tabCount: number): SafariTransitionFrame {
  const count: number = Math.max(0, Math.trunc(tabCount));
  const index: number = Math.max(0, Math.trunc(activeIndex));
  const horizontal: number = finite(dragX);
  const direction: number = horizontal < 0 ? 1 : -1;
  const candidate: number = index + direction;
  const isNewTab: boolean = horizontal < 0 && candidate >= count;
  const hasExistingTarget: boolean = candidate >= 0 && candidate < count;
  const targetIndex: number = isNewTab ? count : (hasExistingTarget ? candidate : index);
  const previewKind: TabPreviewKind = isNewTab ? TabPreviewKind.NEW_TAB
    : (hasExistingTarget ? TabPreviewKind.EXISTING_TAB : TabPreviewKind.NONE);
  return {
    progress: clamp(horizontal / Math.max(1, finite(pageWidth))),
    currentPageX: sceneOffsetForIndex(index, index, pageWidth, horizontal),
    targetPageX: sceneOffsetForIndex(targetIndex, index, pageWidth, horizontal),
    currentAddressX: addressOffsetForIndex(index, index, addressStride, horizontal, pageWidth),
    targetAddressX: addressOffsetForIndex(targetIndex, index, addressStride, horizontal, pageWidth),
    targetIndex,
    previewKind
  };
}

export function newTabPreviewVisual(progress: number): NewTabPreviewVisual {
  const normalized: number = Math.max(0, Math.min(1, finite(progress)));
  return {
    showPagePlus: false,
    showAddressPlus: normalized > 0,
    addressPlusOpacity: normalized,
    addressBackgroundOpacity: newTabBackgroundProgressForPullProgress(normalized)
  };
}

export function addressPreviewSurfaceVisual(cornerRadius: number): AddressPreviewSurfaceVisual {
  return {
    cornerRadius: Math.max(0, finite(cornerRadius)),
    clipsChildren: true
  };
}

/**
 * The reserved-tab glyph and the native address placeholder occupy the same
 * capsule after a new tab is committed. Keep the two owners mutually
 * exclusive during the handoff: crossfading both layers leaves a translucent
 * duplicate in the capsule and is visible as a flash on the first frame.
 */
export function newTabHandoffVisual(progress: number): NewTabHandoffVisual {
  const normalized: number = Math.max(0, Math.min(1, finite(progress)));
  // BrowserShell owns the short plus-only lead-in. The progress supplied here
  // is the dedicated handoff timeline. Use one opaque owner at a time instead
  // of animating two overlaid layers through a translucent intermediate state.
  const placeholderVisible: boolean = normalized >= 0.5;
  return {
    plusOpacity: placeholderVisible ? 0 : 1,
    placeholderOpacity: placeholderVisible ? 1 : 0,
    plusScale: 1,
    placeholderScale: 1,
    placeholderSlideProgress: 1,
    placeholderTextAlignment: 'center'
  };
}

/**
 * A reserved tab is a data-model placeholder, not a visible chrome item.
 * Keep it out of the address strip until the final-tab pull has produced a
 * positive visual progress value.
 */
export function shouldRenderPendingTabPreview(
  previewKind: TabPreviewKind,
  newTabProgress: number
): boolean {
  return previewKind === TabPreviewKind.NEW_TAB && finite(newTabProgress) > 0;
}

export function tabSceneKeys(tabIds: string[], pendingId: string = ''): string[] {
  const keys: string[] = tabIds.slice();
  if (pendingId.length > 0 && !keys.includes(pendingId)) keys.push(pendingId);
  return keys;
}

/** Native Tabs can select only a committed business tab, never a gesture draft. */
export function nativeTabIndexForId(tabIds: string[], tabId: string): number {
  if (tabId.length === 0) {
    return -1;
  }
  return tabIds.indexOf(tabId);
}
