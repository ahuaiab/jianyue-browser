import {
  filterLibraryEntries,
  HistoryDeleteRange,
  HistoryTimelineGroup,
  historyDeleteCutoff,
  historyTimelineGroups,
  LIBRARY_DISMISS_THRESHOLD,
  LIBRARY_SEARCH_PULL_THRESHOLD,
  LIBRARY_SEARCH_REVEAL_ANIMATION_DURATION_MS,
  LIBRARY_SHEET_HEIGHT_PERCENT,
  libraryDismissProgress,
  libraryDismissShouldClose,
  libraryEntries,
  LibraryEntry,
  librarySearchPullShouldCaptureGesture,
  librarySearchPullProgress,
  librarySearchScrollFrame,
  librarySearchSwipeReleaseOffset,
  librarySearchSwipePullOffset,
  librarySheetPullDismissEnabled,
  LibrarySection,
  librarySectionChrome,
  visibleHistoryRecords
} from '../model/LibraryModels';
import { BookmarkRecord, HistoryRecord } from '../model/BrowserTypes';
import { PageIconRecord } from '../model/PageIconModels';
import fileUri from '@ohos.file.fileuri';
import { curves } from '@kit.ArkUI';
import {
  safariImmersiveMaterialIfSupported,
  safariOpaqueModalSurfaceBackgroundColor,
  safariImmersiveSurfaceBackgroundColor
} from '../model/BrowserMaterial';
import {
  TAB_SEARCH_BAR_BACKGROUND_COLOR,
  TAB_SEARCH_BAR_CONTENT_INSET,
  TAB_SEARCH_BAR_STYLE
} from '../model/TabOverviewActions';
import { placeholderForFocus } from '../model/BrowserInteraction';
import {
  BROWSER_UI_ICON_CONTAINER_SIZE_VP,
  BROWSER_UI_ICON_SIZE_VP,
  BROWSER_UI_TEXT_SIZE_VP,
  BrowserChromeAnchor,
  browserChromeSurfaceFrame,
  browserChromeSurfaceHorizontalOffset,
  libraryContentCardWidth,
  libraryListWidth,
  HARMONY_RADIUS_CONTROL,
  HARMONY_RADIUS_FLOATING,
  HARMONY_RADIUS_SHEET,
  SAFARI_BOTTOM_CHROME_BOTTOM_GAP_VP,
  safariBottomChromeUnpaintedAvoidAreaHeight
} from '../model/BrowserVisualMetrics';

const LIBRARY_TAB_HEIGHT_VP: number = 40;

/**
 * Safari-like library sheet. This pass is deliberately visual: it aligns the
 * sheet chrome and list geometry while keeping the existing data callbacks.
 */
const LIBRARY_SITE_ICON_SIZE: number = 24;
const LIBRARY_SITE_ICON_SLOT_SIZE: number = 26;
const LIBRARY_HISTORY_ICON_SIZE: number = 24;
const LIBRARY_HISTORY_ICON_SLOT_SIZE: number = 26;

interface LibraryScrollFrameHandlerResult {
  offsetRemain: number;
}

interface HistoryRemovalVisual {
  id: string;
  entry: LibraryEntry;
  headingKey: string;
  headingTitle: string;
  phase: number;
}

interface HistoryHeadingHeight {
  key: string;
  height: number;
}

interface HistoryHeadingAnchor {
  key: string;
  title: string;
}

const HISTORY_REMOVAL_PHASE_VISIBLE: number = 0;
const HISTORY_REMOVAL_PHASE_SLIDING: number = 1;
const HISTORY_REMOVAL_PHASE_COLLAPSING: number = 2;
const HISTORY_ROW_HEIGHT_VP: number = 65;
const HISTORY_SLIDE_DURATION_MS: number = 220;
const HISTORY_COLLAPSE_DURATION_MS: number = 180;

@ComponentV2
export struct LibrarySheet {
  @Param history: HistoryRecord[] = [];
  /** Explicit invalidation token for async history changes in the parent shell. */
  @Param historyRevision: number = 0;
  @Param bookmarks: BookmarkRecord[] = [];
  @Param pageIcons: PageIconRecord[] = [];
  @Param pageIconRevision: number = 0;
  @Param onMissingPageIcon: (url: string) => void = (_url: string) => undefined;
  /** System top avoid area in vp; the sheet keeps a visual breathing gap below it. */
  @Param topInset: number = 0;
  /** Bottom navigation-indicator avoid area in vp. */
  @Param bottomInset: number = 0;
  @Param viewportWidth: number = 400;
  @Param leftInset: number = 0;
  @Param rightInset: number = 0;
  @Param chromeAnchor: BrowserChromeAnchor = BrowserChromeAnchor.CENTER;
  @Param onOpen: (url: string) => void = (_url: string) => undefined;
  @Param onRemoveBookmark: (url: string) => void = (_url: string) => undefined;
  @Param onRemoveHistory: (entry: LibraryEntry) => void = (_entry: LibraryEntry) => undefined;
  @Param onDeleteHistoryRange: (range: HistoryDeleteRange) => void =
    (_range: HistoryDeleteRange) => undefined;
  @Param onClose: () => void = () => undefined;

  @Local section: LibrarySection = LibrarySection.BOOKMARKS;
  @Local sectionProgress: number = 0;
  @Local editing: boolean = false;
  @Local longPressEntryId: string = '';
  @Local menuEntryId: string = '';
  @Local suppressEntryClickId: string = '';
  @Local sheetSwipeOffset: number = 0;
  @Local sheetGestureActive: boolean = false;
  @Local searchQuery: string = '';
  @Local searchPullOffset: number = 0;
  @Local searchRevealed: boolean = false;
  @Local searchPullFinished: boolean = false;
  private searchCloseTouchStartX: number = 0;
  private searchCloseTouchStartY: number = 0;
  private searchCloseTouchStartOffset: number = 0;
  private searchCloseTouchWasVisible: boolean = false;
  private searchCloseTouchTracking: boolean = false;
  private searchCloseTouchCancelPending: boolean = false;
  @Local editMenuShown: boolean = false;
  @Local editLongPressActive: boolean = false;
  @Local suppressEditClick: boolean = false;
  @Local hiddenHistoryEntryIds: string[] = [];
  @Local historyRemovalVisuals: HistoryRemovalVisual[] = [];
  @Local historyHeadingHeights: HistoryHeadingHeight[] = [];
  @Local visibleHistoryItems: string[] = [];
  private historyRenderEntries: Map<string, LibraryEntry> = new Map();
  private historyRenderTitles: Map<string, string> = new Map();
  private readonly bookmarkScroller: Scroller = new Scroller();
  private readonly historyScroller: Scroller = new Scroller();
  private readonly sectionSwiperController: SwiperController = new SwiperController();
  private readonly sectionConnectorContext: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private sheetAnimationToken: number = 0;
  private searchAnimationToken: number = 0;
  private historyRemovalDisposed: boolean = false;
  private historyRangeMenuDispatchLocked: boolean = false;

  aboutToAppear(): void {
    this.historyRemovalDisposed = false;
    this.syncVisibleHistoryGroups();
  }

  aboutToDisappear(): void {
    // Deletion callbacks have already been dispatched. Ignore late animation
    // completions after the sheet closes without undoing those operations.
    this.historyRemovalDisposed = true;
  }

  @Monitor('historyRevision')
  private onHistoryRevisionChanged(): void {
    this.syncVisibleHistoryGroups();
  }

  @Monitor('section')
  private onLibrarySectionChanged(): void {
    this.drawSectionTabShape();
  }

  @Monitor('sectionProgress')
  private onLibrarySectionProgressChanged(): void {
    this.drawSectionTabShape();
  }

  @Monitor('searchQuery')
  private onHistorySearchChanged(): void {
    this.syncVisibleHistoryGroups();
  }

  private syncVisibleHistoryGroups(): void {
    // A missing Param row may only be the shell's optimistic snapshot, not a
    // committed repository read. Keep tombstones for this sheet lifetime so
    // any late async refresh cannot flash a deleted ID back into the list.
    // New visits receive a timestamp-based ID and remain visible.
    const visibleRecords: HistoryRecord[] = visibleHistoryRecords(
      this.history,
      this.hiddenHistoryEntryIds
    );
    const groups: HistoryTimelineGroup[] = historyTimelineGroups(
      visibleRecords,
      Date.now(),
      this.pageIcons
    )
      .map((group: HistoryTimelineGroup): HistoryTimelineGroup => ({
        section: group.section,
        title: group.title,
        entries: filterLibraryEntries(group.entries, this.searchQuery)
      }))
      .filter((group: HistoryTimelineGroup) => group.entries.length > 0);
    const renderItems: string[] = [];
    const renderEntries: Map<string, LibraryEntry> = new Map();
    const renderTitles: Map<string, string> = new Map();
    groups.forEach((group: HistoryTimelineGroup) => {
      const headingKey: string = `history-heading-${group.title}`;
      renderItems.push(headingKey);
      renderTitles.set(headingKey, group.title);
      group.entries.forEach((entry: LibraryEntry) => {
        renderItems.push(entry.id);
        renderEntries.set(entry.id, entry);
      });
    });
    // The shell updates history optimistically and then publishes a second
    // repository snapshot. Keep each in-flight row and its date heading in
    // the Repeat source until its collapse animation finishes.
    this.historyRemovalVisuals.forEach((visual: HistoryRemovalVisual) => {
      let headingIndex: number = renderItems.indexOf(visual.headingKey);
      if (headingIndex < 0) {
        let insertAt: number = renderItems.length;
        for (let index: number = 0; index < renderItems.length; index++) {
          const candidateHeading: string = renderItems[index];
          if (candidateHeading.indexOf('history-heading-') !== 0) {
            continue;
          }
          const candidateTimestamp: number = this.historyGroupFirstTimestamp(
            renderItems,
            index,
            renderEntries
          );
          if (candidateTimestamp < visual.entry.timestamp) {
            insertAt = index;
            break;
          }
        }
        renderItems.splice(insertAt, 0, visual.headingKey);
        renderTitles.set(visual.headingKey, visual.headingTitle);
        headingIndex = insertAt;
      }
      if (renderItems.indexOf(visual.id) >= 0) {
        renderEntries.set(visual.id, visual.entry);
        return;
      }
      let insertRowAt: number = renderItems.length;
      for (let index: number = headingIndex + 1; index < renderItems.length; index++) {
        const candidateKey: string = renderItems[index];
        if (candidateKey.indexOf('history-heading-') === 0) {
          insertRowAt = index;
          break;
        }
        const candidate: LibraryEntry | undefined = renderEntries.get(candidateKey);
        if (candidate !== undefined && candidate.timestamp < visual.entry.timestamp) {
          insertRowAt = index;
          break;
        }
      }
      renderItems.splice(insertRowAt, 0, visual.id);
      renderEntries.set(visual.id, visual.entry);
    });
    this.historyRenderEntries = renderEntries;
    this.historyRenderTitles = renderTitles;
    this.visibleHistoryItems = renderItems;
  }

  private historyGroupFirstTimestamp(
    items: string[],
    headingIndex: number,
    entries: Map<string, LibraryEntry>
  ): number {
    for (let index: number = headingIndex + 1; index < items.length; index++) {
      const key: string = items[index];
      if (key.indexOf('history-heading-') === 0) {
        break;
      }
      const entry: LibraryEntry | undefined = entries.get(key);
      if (entry !== undefined) {
        return entry.timestamp;
      }
    }
    return Number.MAX_SAFE_INTEGER;
  }

  private historyRemovalPhase(entryId: string): number {
    for (let index: number = 0; index < this.historyRemovalVisuals.length; index++) {
      if (this.historyRemovalVisuals[index].id === entryId) {
        return this.historyRemovalVisuals[index].phase;
      }
    }
    return -1;
  }

  private historyHeadingIsCollapsing(headingKey: string): boolean {
    let hasRemoval: boolean = false;
    for (let index: number = 0; index < this.historyRemovalVisuals.length; index++) {
      const visual: HistoryRemovalVisual = this.historyRemovalVisuals[index];
      if (visual.headingKey !== headingKey) {
        continue;
      }
      hasRemoval = true;
      if (visual.phase !== HISTORY_REMOVAL_PHASE_COLLAPSING) {
        return false;
      }
    }
    if (!hasRemoval) {
      return false;
    }
    let foundHeading: boolean = false;
    let hasRows: boolean = false;
    for (let index: number = 0; index < this.visibleHistoryItems.length; index++) {
      const key: string = this.visibleHistoryItems[index];
      if (key === headingKey) {
        foundHeading = true;
        continue;
      }
      if (!foundHeading) {
        continue;
      }
      if (key.indexOf('history-heading-') === 0) {
        break;
      }
      hasRows = true;
      if (this.historyRemovalPhase(key) < 0) {
        return false;
      }
    }
    return hasRows;
  }

  private historyHeadingHasPendingRemoval(headingKey: string): boolean {
    for (let index: number = 0; index < this.historyRemovalVisuals.length; index++) {
      if (this.historyRemovalVisuals[index].headingKey === headingKey) {
        return true;
      }
    }
    return false;
  }

  private historyHeadingHeight(headingKey: string): number | string {
    for (let index: number = 0; index < this.historyHeadingHeights.length; index++) {
      if (this.historyHeadingHeights[index].key === headingKey) {
        return this.historyHeadingHeights[index].height;
      }
    }
    return 'auto';
  }

  private rememberHistoryHeadingHeight(headingKey: string, height: number): void {
    if (height <= 0 || this.historyHeadingIsCollapsing(headingKey)) {
      return;
    }
    const measured: HistoryHeadingHeight[] = [...this.historyHeadingHeights];
    const index: number = measured.findIndex((value: HistoryHeadingHeight): boolean =>
      value.key === headingKey
    );
    if (index >= 0) {
      if (Math.abs(measured[index].height - height) < 0.5) {
        return;
      }
      measured[index] = { key: headingKey, height: height };
    } else {
      measured.push({ key: headingKey, height: height });
    }
    this.historyHeadingHeights = measured;
  }

  private historyHeadingForEntry(entryId: string): HistoryHeadingAnchor {
    let headingKey: string = '';
    let headingTitle: string = '';
    for (let index: number = 0; index < this.visibleHistoryItems.length; index++) {
      const key: string = this.visibleHistoryItems[index];
      if (key.indexOf('history-heading-') === 0) {
        headingKey = key;
        headingTitle = this.historyRenderTitle(key);
      }
      if (key === entryId) {
        break;
      }
    }
    return { key: headingKey, title: headingTitle };
  }

  private historyVisualWithPhase(visual: HistoryRemovalVisual, phase: number): HistoryRemovalVisual {
    return {
      id: visual.id,
      entry: visual.entry,
      headingKey: visual.headingKey,
      headingTitle: visual.headingTitle,
      phase: phase
    };
  }

  private historyRenderTitle(key: string): string {
    return this.historyRenderTitles.get(key) ?? '';
  }

  private historyRenderEntry(key: string): LibraryEntry {
    return this.historyRenderEntries.get(key) ?? {
      id: key,
      section: LibrarySection.HISTORY,
      title: '',
      url: '',
      timestamp: 0
    };
  }

  @Builder
  private historyRenderItem(key: string) {
    if (key.indexOf('history-heading-') === 0) {
      Column() {
        this.timelineHeading(this.historyRenderTitle(key));
      }
        .id(`library-history-heading-wrap-${key}`)
        .width('100%')
        .height(this.historyHeadingIsCollapsing(key)
          ? 0
          : this.historyHeadingHasPendingRemoval(key) ? this.historyHeadingHeight(key) : 'auto')
        .clip(true);
    } else {
      Column() {
        this.entryRow(this.historyRenderEntry(key));
      }
        .id(`library-history-removal-wrap-${key}`)
        .width('100%')
        .height(this.historyRemovalPhase(key) === HISTORY_REMOVAL_PHASE_COLLAPSING
          ? 0 : HISTORY_ROW_HEIGHT_VP)
        .clip(true)
        .translate({
          x: this.historyRemovalPhase(key) >= HISTORY_REMOVAL_PHASE_SLIDING
            ? -Math.max(this.sheetWidth(), this.viewportWidth) : 0
        })
        .opacity(this.historyRemovalPhase(key) >= HISTORY_REMOVAL_PHASE_SLIDING ? 0 : 1);
    }
  }

  private sectionTitle(section: LibrarySection): string {
    return librarySectionChrome(section).title;
  }

  private drawSectionTabShape(): void {
    const context: CanvasRenderingContext2D = this.sectionConnectorContext;
    const width: number = context.width;
    const height: number = context.height;
    if (width <= 0 || height <= 0) {
      return;
    }
    context.clearRect(0, 0, width, height);
    context.beginPath();
    const curveFactor: number = 0.55228475;
    // Derive the shoulder radius from the measured 40vp canvas height.
    const radius: number = height * 12 / LIBRARY_TAB_HEIGHT_VP;
    const progress: number = Math.max(0, Math.min(1, this.sectionProgress));
    const tabLeft: number = width / 2 * progress;
    const tabRight: number = tabLeft + width / 2;
    const leftShoulder: number = Math.min(radius, tabLeft);
    const rightShoulder: number = Math.min(radius, width - tabRight);

    context.moveTo(tabLeft - leftShoulder, height);
    if (leftShoulder > 0) {
      context.bezierCurveTo(
        tabLeft - leftShoulder + curveFactor * leftShoulder,
        height,
        tabLeft,
        height - leftShoulder + curveFactor * leftShoulder,
        tabLeft,
        height - leftShoulder
      );
    }
    context.lineTo(tabLeft, radius);
    context.bezierCurveTo(
      tabLeft,
      radius - curveFactor * radius,
      tabLeft + radius - curveFactor * radius,
      0,
      tabLeft + radius,
      0
    );
    context.lineTo(tabRight - radius, 0);
    context.bezierCurveTo(
      tabRight - radius + curveFactor * radius,
      0,
      tabRight,
      radius - curveFactor * radius,
      tabRight,
      radius
    );
    context.lineTo(tabRight, height - rightShoulder);
    if (rightShoulder > 0) {
      context.bezierCurveTo(
        tabRight,
        height - rightShoulder + curveFactor * rightShoulder,
        tabRight + rightShoulder - curveFactor * rightShoulder,
        height,
        tabRight + rightShoulder,
        height
      );
    }
    context.closePath();
    context.fillStyle = '#FFFFFF';
    context.fill();
  }

  private hexColorByte(value: number): string {
    const digits: string = '0123456789ABCDEF';
    const byte: number = Math.max(0, Math.min(255, Math.round(value)));
    return digits.charAt(Math.floor(byte / 16)) + digits.charAt(byte % 16);
  }

  private sectionIconTint(section: LibrarySection): string {
    const selectedProgress: number = section === LibrarySection.BOOKMARKS
      ? 1 - this.sectionProgress
      : this.sectionProgress;
    const inactiveProgress: number = 1 - selectedProgress;
    const red: number = 170 * inactiveProgress;
    const green: number = 122 * selectedProgress + 178 * inactiveProgress;
    const blue: number = 255 * selectedProgress + 189 * inactiveProgress;
    return `#${this.hexColorByte(red)}${this.hexColorByte(green)}${this.hexColorByte(blue)}`;
  }

  private sectionTabsWidth(): number {
    return Math.max(0, this.sheetWidth() - 24);
  }

  private libraryCardTopLeftRadius(): number {
    const tabLeft: number = this.sectionProgress * this.sectionTabsWidth() / 2;
    const leftShoulder: number = Math.min(12, tabLeft);
    return Math.min(HARMONY_RADIUS_SHEET, Math.max(0, tabLeft - leftShoulder));
  }

  private libraryCardTopRightRadius(): number {
    const width: number = this.sectionTabsWidth();
    const tabRight: number = this.sectionProgress * width / 2 + width / 2;
    const rightShoulder: number = Math.min(12, width - tabRight);
    return Math.min(HARMONY_RADIUS_SHEET, Math.max(0, width - tabRight - rightShoulder));
  }

  private selectSection(next: LibrarySection): void {
    this.sectionSwiperController.changeIndex(
      next === LibrarySection.BOOKMARKS ? 0 : 1,
      true
    );
  }

  private onSectionSwiperChange(index: number): void {
    const next: LibrarySection = index === 0
      ? LibrarySection.BOOKMARKS
      : LibrarySection.HISTORY;
    if (next === this.section) {
      return;
    }
    // Update the final section used by business logic; visual progress and
    // shell geometry are driven frame-by-frame by the Swiper scroll callback.
    this.getUIContext().animateTo({ duration: 0 }, () => {
      this.section = next;
    });
  }

  private onSectionSwiperScroll(selectedIndex: number, index: number, position: number,
    mainAxisLength: number): void {
    void selectedIndex;
    void mainAxisLength;
    const progress: number = Math.max(0, Math.min(1, index - position));
    if (Math.abs(progress - this.sectionProgress) > 0.0001) {
      this.sectionProgress = progress;
    }
  }

  private beginSheetSwipe(): void {
    this.sheetGestureActive = true;
    this.sheetAnimationToken += 1;
  }

  private updateSheetSwipe(event?: GestureEvent): void {
    if (!this.sheetGestureActive) {
      return;
    }
    const offset: number = event?.offsetY ?? 0;
    this.sheetSwipeOffset = Math.min(240, Math.max(0, offset));
  }

  private finishSheetSwipe(event?: GestureEvent): void {
    if (!this.sheetGestureActive) {
      return;
    }
    const offset: number = Math.max(0, this.sheetSwipeOffset > 0
      ? this.sheetSwipeOffset
      : (event?.offsetY ?? 0));
    this.sheetGestureActive = false;
    const token: number = this.sheetAnimationToken + 1;
    this.sheetAnimationToken = token;
    if (libraryDismissShouldClose(offset, LIBRARY_DISMISS_THRESHOLD)) {
      this.getUIContext().animateTo({
        curve: curves.springMotion(),
        onFinish: () => {
          if (token === this.sheetAnimationToken) {
            this.sheetSwipeOffset = 0;
            this.onClose();
          }
        }
      }, () => {
        this.sheetSwipeOffset = 240;
      });
      return;
    }
    this.getUIContext().animateTo({ curve: curves.springMotion() }, () => {
      this.sheetSwipeOffset = 0;
    });
  }

  private cancelSheetSwipe(): void {
    if (!this.sheetGestureActive && this.sheetSwipeOffset === 0) {
      return;
    }
    this.sheetGestureActive = false;
    this.sheetAnimationToken += 1;
    this.getUIContext().animateTo({ curve: curves.springMotion() }, () => {
      this.sheetSwipeOffset = 0;
    });
  }

  private beginSearchPull(): void {
    if (this.searchCloseTouchTracking && this.searchCloseTouchWasVisible) {
      return;
    }
    this.searchAnimationToken += 1;
    this.searchPullOffset = this.searchRevealed ? LIBRARY_SEARCH_PULL_THRESHOLD : 0;
    this.searchPullFinished = false;
  }

  private updateSearchPull(event?: GestureEvent): void {
    if (this.searchPullFinished || (this.searchCloseTouchTracking && this.searchCloseTouchWasVisible)) {
      return;
    }
    const baseOffset: number = this.searchRevealed ? LIBRARY_SEARCH_PULL_THRESHOLD : 0;
    this.searchPullOffset = Math.max(0, baseOffset + (event?.offsetY ?? 0));
  }

  private finishSearchPull(): void {
    if (this.searchPullFinished) {
      return;
    }
    this.searchPullFinished = true;
    const reveal: boolean = librarySearchPullProgress(this.searchPullOffset) >= 0.5;
    this.animateSearchTo(reveal ? LIBRARY_SEARCH_PULL_THRESHOLD : 0, reveal);
  }

  private cancelSearchPull(): void {
    if (this.searchCloseTouchCancelPending) {
      this.searchCloseTouchCancelPending = false;
      this.searchPullFinished = true;
      return;
    }
    this.searchPullFinished = true;
    if (this.searchPullOffset <= 0 && !this.searchRevealed) {
      return;
    }
    this.animateSearchTo(0, false);
  }

  private activeListScrollOffsetY(section: LibrarySection = this.section): number {
    if (section === LibrarySection.HISTORY && this.visibleHistoryItems.length === 0) {
      return 0;
    }
    try {
      return section === LibrarySection.BOOKMARKS
        ? this.bookmarkScroller.currentOffset().yOffset
        : this.historyScroller.currentOffset().yOffset;
    } catch (_error) {
      // A conditional Scroll may not have been bound on its first render yet.
      // Unknown position must not let the parent steal the list's gesture.
      return Number.NaN;
    }
  }

  private judgeSearchPullGesture(
    event: BaseGestureEvent,
    current: GestureRecognizer,
    targetId: string
  ): GestureJudgeResult {
    const target = current.getEventTargetInfo();
    if (target === undefined || target.getId() !== targetId || current.isBuiltIn() ||
      current.getType() !== GestureControl.GestureType.PAN_GESTURE) {
      return GestureJudgeResult.CONTINUE;
    }
    const panEvent = event as PanGestureEvent;
    const scrollOffsetY: number = this.activeListScrollOffsetY();
    const canCapture: boolean = librarySearchPullShouldCaptureGesture(
      scrollOffsetY,
      panEvent.offsetY,
      this.searchRevealed
    );
    return canCapture ? GestureJudgeResult.CONTINUE : GestureJudgeResult.REJECT;
  }

  private handleSearchCloseTouch(event?: TouchEvent): void {
    if (event === undefined) {
      return;
    }
    if (event.type === TouchType.Down) {
      if (event.changedTouches.length === 0) {
        this.searchCloseTouchTracking = false;
        this.searchCloseTouchWasVisible = false;
        return;
      }
      const touch = event.changedTouches[0];
      this.searchCloseTouchStartX = touch.x;
      this.searchCloseTouchStartY = touch.y;
      this.searchCloseTouchWasVisible = this.searchRevealed || this.searchPullOffset > 0;
      this.searchCloseTouchStartOffset = this.searchCloseTouchWasVisible
        ? (this.searchPullOffset > 0 ? this.searchPullOffset : LIBRARY_SEARCH_PULL_THRESHOLD)
        : 0;
      this.searchCloseTouchTracking = true;
      this.searchCloseTouchCancelPending = false;
      if (this.searchCloseTouchWasVisible) {
        this.searchAnimationToken += 1;
        this.searchPullFinished = false;
      }
      return;
    }
    if (event.type === TouchType.Cancel) {
      const restoreSearch: boolean = this.searchCloseTouchWasVisible;
      this.searchCloseTouchTracking = false;
      this.searchCloseTouchWasVisible = false;
      if (restoreSearch) {
        this.searchCloseTouchCancelPending = true;
        this.searchPullFinished = true;
        this.animateSearchTo(LIBRARY_SEARCH_PULL_THRESHOLD, true);
      }
      return;
    }
    if (!this.searchCloseTouchTracking ||
      (event.type !== TouchType.Move && event.type !== TouchType.Up) || event.changedTouches.length === 0) {
      return;
    }
    const touch = event.changedTouches[0];
    if (this.searchCloseTouchWasVisible) {
      const deltaX: number = touch.x - this.searchCloseTouchStartX;
      const deltaY: number = touch.y - this.searchCloseTouchStartY;
      this.searchPullOffset = librarySearchSwipePullOffset(
        this.searchCloseTouchStartOffset,
        deltaX,
        deltaY
      );
      if (event.type === TouchType.Up) {
        const targetOffset: number = librarySearchSwipeReleaseOffset(
          this.searchPullOffset,
          deltaX,
          deltaY,
          true
        );
        this.searchCloseTouchTracking = false;
        this.searchCloseTouchWasVisible = false;
        this.searchCloseTouchCancelPending = false;
        this.searchPullFinished = true;
        if (targetOffset === 0) {
          this.animateSearchTo(0, false);
        }
        return;
      }
    }
    if (event.type === TouchType.Up) {
      this.searchCloseTouchTracking = false;
      this.searchCloseTouchWasVisible = false;
    }
  }

  private handleLibraryScrollTouch(event?: TouchEvent): void {
    if (event === undefined) {
      return;
    }
    if (event.type === TouchType.Down) {
      this.searchCloseTouchTracking = event.changedTouches.length > 0;
      this.searchCloseTouchWasVisible = this.searchRevealed || this.searchPullOffset > 0;
      this.searchCloseTouchCancelPending = false;
      this.searchPullFinished = false;
      if (this.searchCloseTouchWasVisible) {
        this.searchAnimationToken += 1;
      }
      return;
    }
    if (event.type === TouchType.Cancel) {
      const restoreSearch: boolean = this.searchCloseTouchWasVisible;
      const discardPartialReveal: boolean = !restoreSearch && this.searchPullOffset > 0;
      this.searchCloseTouchTracking = false;
      this.searchCloseTouchWasVisible = false;
      this.searchPullFinished = true;
      if (restoreSearch) {
        this.animateSearchTo(LIBRARY_SEARCH_PULL_THRESHOLD, true);
      } else if (discardPartialReveal) {
        this.animateSearchTo(0, false);
      }
      return;
    }
    if (event.type !== TouchType.Up || !this.searchCloseTouchTracking) {
      return;
    }
    const searchWasVisible: boolean = this.searchCloseTouchWasVisible;
    this.searchCloseTouchTracking = false;
    this.searchCloseTouchWasVisible = false;
    this.searchCloseTouchCancelPending = false;
    if (searchWasVisible) {
      this.searchPullFinished = true;
      this.searchRevealed = this.searchPullOffset > 0;
      return;
    }
    if (this.searchPullOffset > 0) {
      this.finishSearchPull();
    }
  }

  private handleLibraryScrollFrame(
    offset: number,
    section: LibrarySection
  ): LibraryScrollFrameHandlerResult {
    const searchWasVisible: boolean = this.searchRevealed || this.searchPullOffset > 0;
    const frame = librarySearchScrollFrame(
      offset,
      this.searchPullOffset,
      this.activeListScrollOffsetY(section),
      this.searchCloseTouchTracking
    );
    this.searchPullOffset = frame.searchOffset;
    if (this.searchCloseTouchWasVisible) {
      this.searchRevealed = frame.searchOffset > 0;
    } else if (searchWasVisible && frame.searchOffset <= 0 && offset > 0) {
      this.searchRevealed = false;
    }
    return { offsetRemain: frame.offsetRemain };
  }

  private animateSearchTo(targetOffset: number, reveal: boolean): void {
    const token: number = this.searchAnimationToken + 1;
    this.searchAnimationToken = token;
    this.getUIContext().animateTo({
      duration: LIBRARY_SEARCH_REVEAL_ANIMATION_DURATION_MS,
      curve: curves.springMotion(),
      onFinish: () => {
        if (token === this.searchAnimationToken) {
          this.searchRevealed = reveal;
          this.searchPullFinished = false;
          if (reveal) {
            this.requestSearchFocus();
          }
        }
      }
    }, () => {
      this.searchPullOffset = targetOffset;
    });
  }

  private requestSearchFocus(): void {
    if (!this.searchRevealed) {
      return;
    }
    setTimeout(() => {
      if (!this.searchRevealed) {
        return;
      }
      try {
        this.getUIContext().getFocusController().requestFocus('library-search-input');
      } catch (_error) {
        // The field may be between conditional mount frames.
      }
    }, 0);
  }

  @Builder
  private sectionIcon(section: LibrarySection) {
    if (section === LibrarySection.BOOKMARKS) {
      SymbolGlyph($r('sys.symbol.bookmark'))
        .fontSize(BROWSER_UI_ICON_SIZE_VP)
        .width(BROWSER_UI_ICON_CONTAINER_SIZE_VP)
        .height(BROWSER_UI_ICON_CONTAINER_SIZE_VP)
        .fontColor([this.sectionIconTint(section)]);
    } else {
      SymbolGlyph($r('sys.symbol.clock'))
        .fontSize(BROWSER_UI_ICON_SIZE_VP)
        .width(BROWSER_UI_ICON_CONTAINER_SIZE_VP)
        .height(BROWSER_UI_ICON_CONTAINER_SIZE_VP)
        .fontColor([this.sectionIconTint(section)]);
    }
  }

  @Builder
  private sectionButton(section: LibrarySection) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Row() {
        this.sectionIcon(section);
      }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center);
    }
      .id(`library-section-${section}`)
      .width('100%')
      .layoutWeight(1)
      .height(LIBRARY_TAB_HEIGHT_VP)
      .padding({ left: 8, right: 8 })
      .backgroundColor(Color.Transparent)
      .borderRadius(0)
      .stateEffect(false)
      .accessibilityText(this.sectionTitle(section))
      .onClick(() => this.selectSection(section));
  }

  @Builder
  private sectionTabShapeCanvas() {
    Canvas(this.sectionConnectorContext)
      .id(`library-tab-shape-${this.section}`)
      .width('100%')
      .height(LIBRARY_TAB_HEIGHT_VP)
      .hitTestBehavior(HitTestMode.Transparent)
      .onReady(() => this.drawSectionTabShape())
      .onAreaChange((_oldArea: Area, _newArea: Area) => this.drawSectionTabShape());
  }

  @Builder
  private bookmarkFolderRow() {
    Row({ space: 12 }) {
      Text('书签')
        .fontSize(BROWSER_UI_TEXT_SIZE_VP)
        .fontColor('#1D1D1F');
      Blank().layoutWeight(1);
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(BROWSER_UI_ICON_SIZE_VP)
        .width(BROWSER_UI_ICON_CONTAINER_SIZE_VP)
        .height(BROWSER_UI_ICON_CONTAINER_SIZE_VP)
        .fontColor(['#C7C7CC']);
    }
      .id('library-bookmarks-folder')
      .width('100%')
      .height(36)
      .padding({ left: 8, right: 8 })
      .margin({ top: 12 * (1 - this.searchProgress()) });
  }

  private entries(section: LibrarySection): LibraryEntry[] {
    void this.pageIconRevision;
    return libraryEntries(section, this.history, this.bookmarks, this.pageIcons);
  }

  private filteredEntries(section: LibrarySection): LibraryEntry[] {
    return filterLibraryEntries(this.entries(section), this.searchQuery);
  }

  private removeEntry(entry: LibraryEntry): void {
    if (entry.section === LibrarySection.BOOKMARKS) {
      this.onRemoveBookmark(entry.url);
    } else {
      if (this.historyRemovalPhase(entry.id) >= 0 ||
        this.hiddenHistoryEntryIds.indexOf(entry.id) >= 0) {
        return;
      }
      this.beginHistoryRemoval([entry]);
      this.onRemoveHistory(entry);
    }
  }

  private removeHistoryRange(range: HistoryDeleteRange): void {
    const cutoff: number | undefined = range === HistoryDeleteRange.ALL
      ? undefined
      : historyDeleteCutoff(range, Date.now());
    const matchingEntries: LibraryEntry[] = [];
    this.visibleHistoryItems.forEach((key: string) => {
      if (key.indexOf('history-heading-') === 0) {
        return;
      }
      const entry: LibraryEntry | undefined = this.historyRenderEntries.get(key);
      if (entry === undefined || this.historyRemovalPhase(entry.id) >= 0) {
        return;
      }
      if (range === HistoryDeleteRange.ALL ||
        (cutoff !== undefined && entry.timestamp >= cutoff)) {
        matchingEntries.push(entry);
      }
    });
    // The range callback remains the sole business operation. The snapshot is
    // only the set of currently rendered rows that can participate visually.
    this.beginHistoryRemoval(matchingEntries);
    this.onDeleteHistoryRange(range);
  }

  private beginHistoryRemoval(entries: LibraryEntry[]): void {
    const additions: HistoryRemovalVisual[] = [];
    entries.forEach((entry: LibraryEntry) => {
      if (this.historyRemovalPhase(entry.id) >= 0 ||
        this.hiddenHistoryEntryIds.indexOf(entry.id) >= 0) {
        return;
      }
      const heading = this.historyHeadingForEntry(entry.id);
      additions.push({
        id: entry.id,
        entry: entry,
        headingKey: heading.key,
        headingTitle: heading.title,
        phase: HISTORY_REMOVAL_PHASE_VISIBLE
      });
    });
    if (additions.length === 0) {
      return;
    }
    const ids: string[] = additions.map((visual: HistoryRemovalVisual): string => visual.id);
    this.historyRemovalVisuals = [...this.historyRemovalVisuals, ...additions];
    this.syncVisibleHistoryGroups();
    this.getUIContext().animateTo({
      duration: HISTORY_SLIDE_DURATION_MS,
      curve: Curve.EaseIn,
      onFinish: () => this.beginHistoryCollapse(ids)
    }, () => {
      this.historyRemovalVisuals = this.historyRemovalVisuals.map((visual: HistoryRemovalVisual) =>
        ids.indexOf(visual.id) >= 0
          ? this.historyVisualWithPhase(visual, HISTORY_REMOVAL_PHASE_SLIDING)
          : visual
      );
    });
  }

  private beginHistoryCollapse(ids: string[]): void {
    if (this.historyRemovalDisposed) {
      return;
    }
    this.getUIContext().animateTo({
      duration: HISTORY_COLLAPSE_DURATION_MS,
      curve: Curve.EaseInOut,
      onFinish: () => this.finishHistoryRemoval(ids)
    }, () => {
      this.historyRemovalVisuals = this.historyRemovalVisuals.map((visual: HistoryRemovalVisual) =>
        ids.indexOf(visual.id) >= 0
          ? this.historyVisualWithPhase(visual, HISTORY_REMOVAL_PHASE_COLLAPSING)
          : visual
      );
    });
  }

  private finishHistoryRemoval(ids: string[]): void {
    if (this.historyRemovalDisposed) {
      return;
    }
    const finishedIds: string[] = this.historyRemovalVisuals
      .filter((visual: HistoryRemovalVisual): boolean => ids.indexOf(visual.id) >= 0)
      .map((visual: HistoryRemovalVisual): string => visual.id);
    if (finishedIds.length === 0) {
      return;
    }
    this.hiddenHistoryEntryIds = [...this.hiddenHistoryEntryIds, ...finishedIds];
    this.historyRemovalVisuals = this.historyRemovalVisuals.filter(
      (visual: HistoryRemovalVisual): boolean => ids.indexOf(visual.id) < 0
    );
    this.syncVisibleHistoryGroups();
  }

  private beginEntryLongPress(entry: LibraryEntry): void {
    if (entry.section !== LibrarySection.HISTORY) {
      return;
    }
    this.longPressEntryId = entry.id;
    this.menuEntryId = entry.id;
    this.suppressEntryClickId = entry.id;
  }

  private endEntryLongPress(entryId: string): void {
    if (this.longPressEntryId === entryId) {
      this.longPressEntryId = '';
    }
    // Keep menuEntryId until the native menu reports onDisappear. Clearing it
    // at release time would unmount the menu before ArkUI opens its window.
  }

  private dismissEntryMenu(entryId: string): void {
    if (this.menuEntryId === entryId) {
      this.menuEntryId = '';
    }
    if (this.longPressEntryId === entryId) {
      this.longPressEntryId = '';
    }
    if (this.suppressEntryClickId === entryId) {
      this.suppressEntryClickId = '';
    }
  }

  private handleEntryClick(entry: LibraryEntry): void {
    if (this.suppressEntryClickId === entry.id) {
      this.suppressEntryClickId = '';
      return;
    }
    if (!this.editing) {
      this.onOpen(entry.url);
    }
  }

  private beginEditLongPress(): void {
    this.editLongPressActive = true;
    this.editMenuShown = true;
    this.suppressEditClick = true;
    this.historyRangeMenuDispatchLocked = false;
  }

  private dispatchHistoryRangeFromMenu(range: HistoryDeleteRange): void {
    if (this.historyRangeMenuDispatchLocked) {
      return;
    }
    this.historyRangeMenuDispatchLocked = true;
    this.removeHistoryRange(range);
    this.dismissEditMenu();
  }

  private endEditLongPress(): void {
    this.editLongPressActive = false;
  }

  private dismissEditMenu(): void {
    this.editLongPressActive = false;
    this.editMenuShown = false;
    this.suppressEditClick = false;
  }

  private handleEditClick(): void {
    if (this.suppressEditClick) {
      this.suppressEditClick = false;
      return;
    }
    this.editing = !this.editing;
  }

  @Builder
  private editMenu() {
    Menu() {
      MenuItem({ content: '删除今天历史记录' })
        .contentFontColor('#FF3B30')
        .onChange((selected: boolean) => {
          if (selected) {
            this.dispatchHistoryRangeFromMenu(HistoryDeleteRange.TODAY);
          }
        })
      MenuItem({ content: '删除本周历史记录' })
        .contentFontColor('#FF3B30')
        .onChange((selected: boolean) => {
          if (selected) {
            this.dispatchHistoryRangeFromMenu(HistoryDeleteRange.THIS_WEEK);
          }
        })
      MenuItem({ content: '删除全部历史记录' })
        .contentFontColor('#FF3B30')
        .onChange((selected: boolean) => {
          if (selected) {
            this.dispatchHistoryRangeFromMenu(HistoryDeleteRange.ALL);
          }
        })
    }
  }

  @Builder
  private historyMenu(entry: LibraryEntry) {
    Menu() {
      MenuItem({ content: '打开' })
        .onChange((selected: boolean) => {
          if (selected) {
            this.onOpen(entry.url);
            this.dismissEntryMenu(entry.id);
          }
        })
      MenuItem({ content: '删除' })
        .onChange((selected: boolean) => {
          if (selected) {
            this.removeEntry(entry);
            this.dismissEntryMenu(entry.id);
          }
        })
    }
  }

  @Builder
  private entryIcon(entry: LibraryEntry, iconSize: number) {
    if (this.iconSourceFor(entry).length > 0) {
      Image(this.iconSourceFor(entry))
        .width(iconSize)
        .height(iconSize)
        .objectFit(ImageFit.Contain);
    } else {
      SymbolGlyph($r('sys.symbol.display'))
        .fontSize(iconSize)
        .fontColor(['#007AFF'])
        .onVisibleAreaApproximateChange(
          { ratios: [0.0], expectedUpdateInterval: 300 },
          (isExpanding: boolean, currentRatio: number): void => {
            if (isExpanding && currentRatio > 0 && entry.url.trim().length > 0) {
              this.onMissingPageIcon(entry.url);
            }
          }
        );
    }
  }

  private iconSourceFor(entry: LibraryEntry): string {
    if (entry.iconPath === undefined || entry.iconPath.length === 0) {
      return '';
    }
    try {
      return fileUri.getUriFromPath(entry.iconPath);
    } catch (_error) {
      return '';
    }
  }

  @Builder
  private entryRow(entry: LibraryEntry) {
    Column() {
      Row({ space: 12 }) {
        if (this.editing) {
          Button({ type: ButtonType.Normal, stateEffect: false }) {
            SymbolGlyph($r('sys.symbol.minus_circle_fill'))
              .fontSize(BROWSER_UI_ICON_SIZE_VP)
              .width(BROWSER_UI_ICON_CONTAINER_SIZE_VP)
              .height(BROWSER_UI_ICON_CONTAINER_SIZE_VP)
              .fontColor(['#FF3B30']);
          }
            .id(`library-delete-${entry.id}`)
            .width(26)
            .height(26)
            .padding(0)
            .backgroundColor(Color.Transparent)
            .stateEffect(false)
            .onClick(() => this.removeEntry(entry));
        }
        if (entry.section === LibrarySection.HISTORY) {
          Text(entry.timeText ?? '')
            .width(42)
            .fontSize(BROWSER_UI_TEXT_SIZE_VP)
            .fontColor('#6B6B72')
            .textAlign(TextAlign.Center)
            .maxLines(1);
          Row({ space: 8 }) {
            Stack() {
              this.entryIcon(entry, LIBRARY_HISTORY_ICON_SIZE);
            }
              .width(LIBRARY_HISTORY_ICON_SLOT_SIZE)
              .height(LIBRARY_HISTORY_ICON_SLOT_SIZE)
              .alignContent(Alignment.Center);
            Column({ space: 2 }) {
              Text(entry.title)
                .fontSize(BROWSER_UI_TEXT_SIZE_VP)
                .fontColor('#1D1D1F')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%');
              Text(entry.shortUrl ?? '')
                .fontSize(BROWSER_UI_TEXT_SIZE_VP)
                .fontColor('#8A8A90')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%');
            }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);
          }
            .width('100%')
            .alignItems(VerticalAlign.Center);
        } else {
          Stack() {
            this.entryIcon(entry, LIBRARY_SITE_ICON_SIZE);
          }
            .width(LIBRARY_SITE_ICON_SLOT_SIZE)
            .height(LIBRARY_SITE_ICON_SLOT_SIZE)
            .alignContent(Alignment.Center);
          Column({ space: 2 }) {
            Text(entry.title)
              .fontSize(BROWSER_UI_TEXT_SIZE_VP)
              .fontColor('#1D1D1F')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%');
          }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start);
        }
      }
        .width('100%')
        .height(entry.section === LibrarySection.BOOKMARKS ? 52 : 64)
        .alignItems(VerticalAlign.Center);
      Row()
        .width('100%')
        .height(1)
        .margin({ left: entry.section === LibrarySection.BOOKMARKS ? 44 : 66 })
        .backgroundColor('#E5E5EA');
    }
      .id(`library-entry-${entry.id}`)
      .width('100%')
      .padding({ left: 8, right: 0 })
      .backgroundColor(Color.Transparent)
      // ArkUI owns insertion/removal transitions so a delete from either
      // bookmark or history editing feels native and remains interruptible.
      .transition(
        TransitionEffect.asymmetric(
          TransitionEffect.OPACITY.combine(TransitionEffect.move(TransitionEdge.END)),
          TransitionEffect.OPACITY.combine(TransitionEffect.move(TransitionEdge.END))
        ).animation({ duration: 180, curve: Curve.EaseOut })
      )
      .onClick(() => this.handleEntryClick(entry))
      .bindContextMenu(this.menuEntryId === entry.id, this.historyMenu(entry), {
        placement: Placement.TopRight,
        systemMaterial: safariImmersiveMaterialIfSupported(),
        onDisappear: () => this.dismissEntryMenu(entry.id)
      })
      .gesture(
        LongPressGesture({ duration: 300 })
          .onAction(() => this.beginEntryLongPress(entry))
          .onActionEnd(() => this.endEntryLongPress(entry.id))
          .onActionCancel(() => this.endEntryLongPress(entry.id))
      );
  }

  @Builder
  private sectionHeading(section: LibrarySection) {
    Text(this.sectionTitle(section))
      .fontSize(BROWSER_UI_TEXT_SIZE_VP)
      .fontWeight(FontWeight.Medium)
      .fontColor('#6B6B72')
      .width('100%')
      .padding({ left: 14, top: 8, bottom: 6 });
  }

  @Builder
  private timelineHeading(title: string) {
    Column() {
      Text(title)
        .fontSize(BROWSER_UI_TEXT_SIZE_VP)
        .fontWeight(FontWeight.Medium)
        .fontColor('#6B6B72')
        .width('100%')
        .padding({ left: 14, top: 8, bottom: 6 });
      Row()
        .width('100%')
        .height(1)
        .margin({ left: 14, right: 14 })
        .backgroundColor('#D1D1D6');
    }
      .width('100%')
      .onAreaChange((_oldArea: Area, newArea: Area) =>
        this.rememberHistoryHeadingHeight(`history-heading-${title}`, newArea.height as number));
  }

  @Builder
  private emptyState() {
    // Keep an empty history surface quiet. The sheet is a navigation surface,
    // not a toast area; no explanatory placeholder text is rendered here.
    Blank()
      .id('library-empty-state')
      .transition(TransitionEffect.OPACITY.animation({
        duration: HISTORY_COLLAPSE_DURATION_MS,
        curve: Curve.EaseOut
      }))
      .onTouch((event?: TouchEvent) => this.handleSearchCloseTouch(event))
      .width('100%')
      .layoutWeight(1)
      .height('100%')
      .parallelGesture(
        PanGesture({ direction: PanDirection.Vertical, distance: 8 })
          .onActionStart(() => this.beginSearchPull())
          .onActionUpdate((event: GestureEvent | undefined) => this.updateSearchPull(event))
          .onActionEnd(() => this.finishSearchPull())
          .onActionCancel(() => this.cancelSearchPull())
      )
      .onGestureRecognizerJudgeBegin((event: BaseGestureEvent, current: GestureRecognizer,
        _recognizers: Array<GestureRecognizer>): GestureJudgeResult =>
        this.judgeSearchPullGesture(event, current, 'library-empty-state'));
  }

  private searchProgress(): number {
    return librarySearchPullProgress(this.searchPullOffset);
  }

  private searchSlotHeight(): number {
    return (TAB_SEARCH_BAR_STYLE.height + 16) * this.searchProgress();
  }

  @Builder
  private searchBar() {
    Stack() {
      if (this.searchPullOffset > 0 || this.searchRevealed) {
        Row() {
          TextInput({
            text: this.searchQuery,
            placeholder: '搜索'
          })
            .id('library-search-input')
            .width('100%')
            .height(TAB_SEARCH_BAR_STYLE.height)
            .padding({ left: TAB_SEARCH_BAR_CONTENT_INSET, right: TAB_SEARCH_BAR_CONTENT_INSET })
            .fontSize(BROWSER_UI_TEXT_SIZE_VP)
            .fontColor('#1D1D1F')
            .placeholderColor('#7E858B')
            .backgroundColor(Color.Transparent)
            .defaultFocus(this.searchRevealed)
            .onChange((value: string) => this.searchQuery = value);
        }
          .id('library-search-bar')
          .width(`calc(100% - ${TAB_SEARCH_BAR_STYLE.horizontalInset * 2}vp)`)
          .alignSelf(ItemAlign.Center)
          .height(TAB_SEARCH_BAR_STYLE.height)
          .margin({ top: 10, bottom: 6 })
          .opacity(this.searchProgress())
          .translate({ y: -20 * (1 - this.searchProgress()) })
          .backgroundColor(TAB_SEARCH_BAR_BACKGROUND_COLOR)
          .borderRadius(TAB_SEARCH_BAR_STYLE.cornerRadius);
      }
    }
      .id('library-search-slot')
      .width('100%')
      .height(this.searchSlotHeight())
      .clip(true);
  }

  @Builder
  private bookmarkContent() {
    Scroll(this.bookmarkScroller) {
      Column() {
        if (this.searchQuery.trim().length === 0) {
          this.bookmarkFolderRow();
        }
        ForEach(this.filteredEntries(LibrarySection.BOOKMARKS), (entry: LibraryEntry) => {
          this.entryRow(entry);
        }, (entry: LibraryEntry) => entry.id);
      }
        .width('100%')
        // Scroll stretches its child to the viewport on the preview/device
        // renderer. Pin the content column to the top so the first folder
        // row stays directly below the segmented tabs instead of appearing
        // in the vertical middle of the sheet.
        .height('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start);
    }
      .id('library-entry-scroll-bookmarks')
      .onTouch((event?: TouchEvent) => this.handleLibraryScrollTouch(event))
      .width(libraryListWidth(libraryContentCardWidth(this.sheetWidth())))
      .alignSelf(ItemAlign.Center)
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .onScrollFrameBegin((offset: number) => this.handleLibraryScrollFrame(offset, LibrarySection.BOOKMARKS));
  }

  @Builder
  private listContent() {
    Scroll(this.historyScroller) {
      Column() {
        Repeat<string>(this.visibleHistoryItems)
          .each((item: RepeatItem<string>) => {
            this.historyRenderItem(item.item);
          })
          .key((item: string) => item);
      }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start);
    }
      .id('library-entry-scroll-history')
      .align(Alignment.Top)
      .onTouch((event?: TouchEvent) => this.handleLibraryScrollTouch(event))
      .width(libraryListWidth(libraryContentCardWidth(this.sheetWidth())))
      .alignSelf(ItemAlign.Center)
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .onScrollFrameBegin((offset: number) => this.handleLibraryScrollFrame(offset, LibrarySection.HISTORY));
  }

  @Builder
  private historyContent() {
    if (this.visibleHistoryItems.length === 0) {
      this.emptyState();
    } else {
      this.listContent();
    }
  }

  @Builder
  private footerSpacer() {
    // The navigation indicator is a system-owned region. Keep the sheet's
    // content clear of it; the edit control is rendered independently
    // as a floating action below, matching the tab overview chrome.
    Blank()
      .id('library-footer-spacer')
      .width('100%')
      .height(this.safeBottomInset());
  }

  @Builder
  private floatingEditButton() {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      if (this.editing) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(BROWSER_UI_ICON_SIZE_VP)
          .width(BROWSER_UI_ICON_CONTAINER_SIZE_VP)
          .height(BROWSER_UI_ICON_CONTAINER_SIZE_VP)
          .fontColor(['#007AFF']);
      } else {
        SymbolGlyph($r('sys.symbol.pencil_line'))
          .fontSize(BROWSER_UI_ICON_SIZE_VP)
          .width(BROWSER_UI_ICON_CONTAINER_SIZE_VP)
          .height(BROWSER_UI_ICON_CONTAINER_SIZE_VP)
          .fontColor(['#007AFF']);
      }
    }
      .id('library-edit-button')
      .width(52)
      .height(52)
      .padding(0)
      .backgroundColor(safariImmersiveSurfaceBackgroundColor())
      .borderRadius(HARMONY_RADIUS_FLOATING)
      .systemMaterial(safariImmersiveMaterialIfSupported())
      .stateEffect(false)
      .onClick(() => this.handleEditClick())
      .bindContextMenu(this.editMenuShown, this.editMenu, {
        placement: Placement.TopRight,
        onDisappear: () => this.dismissEditMenu()
      })
      .parallelGesture(
        LongPressGesture({ duration: 300 })
          .onAction(() => this.beginEditLongPress())
          .onActionEnd(() => this.endEditLongPress())
          .onActionCancel(() => this.endEditLongPress())
      );
  }

  private safeBottomInset(): number {
    return safariBottomChromeUnpaintedAvoidAreaHeight(this.bottomInset) +
      SAFARI_BOTTOM_CHROME_BOTTOM_GAP_VP;
  }

  private floatingEditAlignment(): Alignment {
    return this.chromeAnchor === BrowserChromeAnchor.START
      ? Alignment.BottomStart
      : Alignment.BottomEnd;
  }

  // Keep the floating button and content card corner centers aligned.
  private floatingEditCornerInset(): number {
    return Math.max(0, HARMONY_RADIUS_SHEET - HARMONY_RADIUS_FLOATING);
  }

  private floatingEditHorizontalInset(): number {
    return (this.sheetWidth() - libraryContentCardWidth(this.sheetWidth())) / 2 +
      this.floatingEditCornerInset();
  }

  private sheetWidth(): number {
    return browserChromeSurfaceFrame(
      this.viewportWidth,
      this.leftInset,
      this.rightInset,
      this.chromeAnchor
    ).width;
  }

  private sheetHorizontalOffset(): number {
    return browserChromeSurfaceHorizontalOffset(
      this.viewportWidth,
      this.leftInset,
      this.rightInset,
      this.chromeAnchor
    );
  }

  private topContentInset(): number {
    // A small non-zero fallback covers the first frame on devices that report
    // TYPE_SYSTEM after the overlay has already been mounted. The page root
    // remains immersive, while the header text always starts below its
    // rounded sheet edge.
    // The rounded sheet edge already sits below the status region. A compact
    // 8–12vp breathing gap keeps the title visually attached to that edge.
    return Math.max(8, Math.min(this.topInset, 12));
  }

  @Builder
  private sheetContent() {
    Blank()
      .width('100%')
      .height(this.topContentInset());
    Stack({ alignContent: Alignment.TopStart }) {
      this.sectionTabShapeCanvas();
      Row() {
        this.sectionButton(LibrarySection.BOOKMARKS);
        this.sectionButton(LibrarySection.HISTORY);
      }
        .width('100%')
        .height(LIBRARY_TAB_HEIGHT_VP);
    }
      .id('library-section-tabs')
      // Match the content card width so the selected tab reaches its side edges.
      .width(libraryContentCardWidth(this.sheetWidth()))
      .alignSelf(ItemAlign.Center)
      .height(LIBRARY_TAB_HEIGHT_VP)
      .padding(0)
      .backgroundColor(Color.Transparent);

    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.searchBar();
        Swiper(this.sectionSwiperController) {
          Column() {
            this.bookmarkContent();
          }
            .id('library-section-page-bookmarks')
            .width('100%')
            .height('100%');
          Column() {
            this.historyContent();
          }
            .id('library-section-page-history')
            .width('100%')
            .height('100%');
        }
          .id('library-section-pager')
          .index(this.section === LibrarySection.BOOKMARKS ? 0 : 1)
          .width('100%')
          .layoutWeight(1)
          .displayCount(1)
          .itemSpace(0)
          .indicator(false)
          .loop(false)
          .curve(curves.springMotion())
          .onContentDidScroll((selectedIndex: number, index: number, position: number,
            mainAxisLength: number) =>
            this.onSectionSwiperScroll(selectedIndex, index, position, mainAxisLength))
          .onChange((index: number) => this.onSectionSwiperChange(index));
      }
        .width('100%')
        .height('100%');
    }
      .id('library-content-transition')
      .width(libraryContentCardWidth(this.sheetWidth()))
      .alignSelf(ItemAlign.Center)
      .layoutWeight(1)
      .backgroundColor(Color.White)
      .borderRadius({
        topLeft: this.libraryCardTopLeftRadius(),
        topRight: this.libraryCardTopRightRadius(),
        bottomLeft: HARMONY_RADIUS_SHEET,
        bottomRight: HARMONY_RADIUS_SHEET
      })
      .clip(true);
    this.footerSpacer();
  }

  @Builder
  private sheetInteractionLayer() {
    if (librarySheetPullDismissEnabled()) {
      Column() {
        this.sheetContent();
      }
        .width('100%')
        .height('100%')
        .parallelGesture(
          PanGesture({ direction: PanDirection.Vertical, distance: 8 })
            .onActionStart(() => this.beginSheetSwipe())
            .onActionUpdate((event: GestureEvent | undefined) => this.updateSheetSwipe(event))
            .onActionEnd((event: GestureEvent | undefined) => this.finishSheetSwipe(event))
            .onActionCancel(() => this.cancelSheetSwipe())
        );
    } else {
      Column() {
        this.sheetContent();
      }
        .width('100%')
        .height('100%');
    }
  }

  build() {
    Stack() {
      Column() {
      // Keep the overlay itself transparent. Only the bottom sheet paints a
      // white surface, so the status-bar region is never covered by the
      // sheet's rounded top edge. This is important on full-screen devices
      // where the app content is laid out under the system status bar.
      Blank()
        .width('100%')
        .layoutWeight(1)
        // The backdrop is intentionally a real hit target: tapping outside
        // the sheet dismisses the library without adding a visible close
        // button or toast.
        .onClick(() => this.onClose());

      Column() {
        this.sheetInteractionLayer();
      }
        .id('library-sheet')
        .width(this.sheetWidth())
        .alignSelf(ItemAlign.Center)
        // Leave a transparent breathing area above the sheet. The child
        // remains bottom-anchored and paints only its own rounded surface.
        .height(`${LIBRARY_SHEET_HEIGHT_PERCENT}%`)
        .padding({ left: 0, right: 0, top: 0, bottom: 0 })
        .backgroundColor(safariOpaqueModalSurfaceBackgroundColor())
        .borderRadius({ topLeft: HARMONY_RADIUS_SHEET, topRight: HARMONY_RADIUS_SHEET })
        .clip(true)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        .translate({ x: this.sheetHorizontalOffset(), y: this.sheetSwipeOffset })
        .opacity(1 - 0.22 * libraryDismissProgress(this.sheetSwipeOffset));
      }
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent);

      // Keep the edit/check control outside the sheet hierarchy. This gives
      // the library page the same independent floating action treatment as
      // the tab overview's plus and done controls.
      Stack({ alignContent: this.floatingEditAlignment() }) {
        this.floatingEditButton();
      }
        .id('library-floating-edit-host')
        .width(this.sheetWidth())
        .height('100%')
        .alignSelf(ItemAlign.Center)
        .translate({ x: this.sheetHorizontalOffset(), y: 0, z: 0 })
        .padding({
          left: this.chromeAnchor === BrowserChromeAnchor.START
            ? this.floatingEditHorizontalInset() : 0,
          right: this.chromeAnchor === BrowserChromeAnchor.START
            ? 0 : this.floatingEditHorizontalInset(),
          bottom: this.safeBottomInset() + this.floatingEditCornerInset()
        })
        // The host only positions the floating pencil. It must not become a
        // full-screen hit target and steal taps from the library tabs/list.
        .hitTestBehavior(HitTestMode.Transparent);
    }
      .width('100%')
      .height('100%');
  }
}
