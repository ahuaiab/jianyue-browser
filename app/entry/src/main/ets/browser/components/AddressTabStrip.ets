import { RectShape } from '@kit.ArkUI';
import { PageAction } from '../model/PageActions';
import { PageFontSize } from '../model/PageDisplayState';
import { BrowserTabRecord, lastValidUrlForTab, PendingTabDraft, searchQueryForUrl } from '../model/BrowserTypes';
import {
  SAFARI_ADDRESS_ITEM_GAP_VP,
  SAFARI_ADDRESS_PREVIEW_FADE_DURATION_MS,
  SAFARI_ADDRESS_ROW_HEIGHT_VP,
  SafariAddressTrackClipFrame,
  safariAddressTrackClipFrame,
  safariAddressItemWidth
} from '../model/BrowserVisualMetrics';
import {
  ADDRESS_SEARCH_BAR_STYLE,
  ADDRESS_SEARCH_BAR_TOP_PADDING,
  TabOverviewChromeFrame
} from '../model/TabOverviewActions';
import { isPointInTabBar, TabBarRect } from '../gesture/TabBarGestureGate';
import { beginTouchOwnership, TouchOwner } from '../gesture/TouchOwnership';
import {
  addressItemLeft,
  addressPreviewOpacity,
  addressPreviewSurfaceVisual,
  newTabHandoffVisual,
  newTabPreviewVisual,
  pendingTabVisualIndex,
  shouldAnimateAddressItemExit,
  shouldRenderAddressHandoff,
  shouldRenderAddressItem,
  shouldRenderPendingTabPreview
} from '../model/SafariTabTransition';
import { addressTextColorFor } from '../model/BrowserInteraction';
import { TabPreviewKind } from '../model/TabGestureMotion';
import { DownloadProgressSnapshot } from '../model/DownloadModels';
import { AddressSearchBar, AddressSearchBarDownloadProps, addressSearchBarDownloadProps } from './AddressSearchBar';

const ADDRESS_PREVIEW_SURFACE = addressPreviewSurfaceVisual(ADDRESS_SEARCH_BAR_STYLE.cornerRadius);

export function addressTabStripDownloadSnapshotForItem(
  snapshot: DownloadProgressSnapshot | undefined,
  index: number,
  activeIndex: number
): DownloadProgressSnapshot | undefined {
  return index === activeIndex ? snapshot : undefined;
}

@ComponentV2
export struct AddressTabStrip {
  @Param tabs: BrowserTabRecord[] = [];
  @Param pendingTab: PendingTabDraft | undefined = undefined;
  @Param activeIndex: number = 0;
  @Param displayDragX: number = 0;
  @Param viewportWidth: number = 0;
  @Param interactionLocked: boolean = false;
  @Param address: string = '';
  @Param pageTitle: string = '';
  @Param searchQuery: string = '';
  @Param addressDraft: string = '';
  @Param isPrivate: boolean = false;
  @Param inputExpandProgress: number = 0;
  @Param barMode: string = 'collapsed';
  @Param addressEditing: boolean = false;
  @Param inputMounted: boolean = true;
  @Param activeInputIdentity: string = 'unknown';
  @Param addressInputFocusEnabled: boolean = true;
  @Param previewKind: TabPreviewKind = TabPreviewKind.NONE;
  @Param newTabProgress: number = 0;
  @Param addressHandoffMounted: boolean = false;
  @Param addressHandoffProgress: number = 1;
  @Param downloadProgress: DownloadProgressSnapshot | undefined = undefined;
  /** Shared page/chrome frame used while the address capsule leaves the bar. */
  @Param overviewTransitionActive: boolean = false;
  @Param overviewChromeFrame: TabOverviewChromeFrame | undefined = undefined;
  @Param inputFocusRequestToken: number = 0;
  @Param selectedFontSize: PageFontSize = PageFontSize.STANDARD;
  @Param webReady: boolean = false;
  @Param desktopMode: boolean = false;
  @Param onNavigate: (value: string) => void = (_value: string) => undefined;
  @Param onReload: () => void = () => undefined;
  @Param onOpenAddress: () => void = () => undefined;
  @Param onAddressChange: (value: string) => void = (_value: string) => undefined;
  @Param onInputFocusChange: (focused: boolean) => void = (_focused: boolean) => undefined;
  @Param onAddressSubmit: (value: string) => void = (_value: string) => undefined;
  @Param onAddressCancel: () => void = () => undefined;
  @Param onFontSize: (size: PageFontSize) => void = (_size: PageFontSize) => undefined;
  @Param onPageAction: (action: PageAction) => void = (_action: PageAction) => undefined;
  @Param onNewTab: () => void = () => undefined;
  @Param onNewPrivateTab: () => void = () => undefined;
  @Param onGestureTouchStart: (x: number, y: number, startInAddressStrip: boolean,
    owner: TouchOwner, buttonId: string) => void =
    (_x: number, _y: number, _startInAddressStrip: boolean, _owner: TouchOwner, _button: string) => undefined;
  @Param onGestureRectChange: (x: number, y: number, width: number, height: number) => void =
    (_x: number, _y: number, _width: number, _height: number) => undefined;
  @Param onGestureStart: (x: number, y: number) => void = (_x: number, _y: number) => undefined;
  @Param onGestureUpdate: (event: GestureEvent) => void = (_event: GestureEvent) => undefined;
  @Param onGestureEnd: (event: GestureEvent) => void = (_event: GestureEvent) => undefined;
  @Param onGestureCancel: () => void = () => undefined;

  // The address strip can be a fractional width smaller than the Web host
  // after the immersive material and window avoidance are applied. Use its
  // own measured width for the capsule track so both outer corner centers
  // are calculated in the same coordinate space.
  @Local addressLayoutWidth: number = 0;
  private addressStripRect: TabBarRect = { x: 0, y: 0, width: 0, height: 0 };
  private touchStartX: number = 0;
  private touchStartY: number = 0;

  private layoutWidth(): number {
    if (this.overviewTransitionActive && this.overviewChromeFrame !== undefined) {
      return this.overviewChromeFrame.addressWidth;
    }
    return this.addressLayoutWidth > 0 ? this.addressLayoutWidth : this.viewportWidth;
  }

  private frameWidth(): number | string {
    return this.overviewChromeFrame === undefined
      ? '100%'
      : this.overviewChromeFrame.addressWidth;
  }

  private frameHeight(): number {
    return this.overviewTransitionActive
      ? ADDRESS_SEARCH_BAR_STYLE.height
      : SAFARI_ADDRESS_ROW_HEIGHT_VP;
  }

  private framePosition(): Position {
    return this.overviewChromeFrame === undefined
      ? { x: 0, y: 0 }
      : {
        x: this.overviewChromeFrame.addressLeft,
        // The model's top is the compact transition root. Normal mode keeps
        // the 56vp touch slot and places its visible 44vp field 8vp below it.
        y: this.overviewChromeFrame.addressTop -
          (this.overviewTransitionActive ? 0 : ADDRESS_SEARCH_BAR_TOP_PADDING)
      };
  }

  private frameScaleX(): number {
    if (this.overviewChromeFrame === undefined) {
      return 1;
    }
    return this.overviewChromeFrame.addressScaleX * this.overviewChromeFrame.addressJellyScaleX;
  }

  private frameScaleY(): number {
    if (this.overviewChromeFrame === undefined) {
      return 1;
    }
    return this.overviewChromeFrame.addressScaleY * this.overviewChromeFrame.addressJellyScaleY;
  }

  private frameTranslateY(): number {
    return this.overviewChromeFrame?.addressJellyTranslateY ?? 0;
  }

  private addressTrackClipShape(): RectShape {
    const frame: SafariAddressTrackClipFrame = safariAddressTrackClipFrame(
      this.layoutWidth(),
      this.overviewTransitionActive
    );
    return new RectShape({
      width: frame.width,
      height: this.frameHeight(),
      radius: [frame.topRadius, frame.topRadius, 0, 0]
    }).position({ x: frame.left, y: 0 });
  }

  private itemWidth(): number {
    return safariAddressItemWidth(this.layoutWidth());
  }

  private itemOffset(index: number): number {
    return addressItemLeft(index, this.activeIndex, this.itemWidth(),
      SAFARI_ADDRESS_ITEM_GAP_VP, this.displayDragX, this.layoutWidth());
  }

  private itemOpacity(index: number): number {
    return addressPreviewOpacity(index, this.activeIndex, this.displayDragX, this.viewportWidth);
  }

  private addressPlusOpacity(): number {
    return newTabPreviewVisual(this.newTabProgress).addressPlusOpacity;
  }

  private addressBackgroundOpacity(): number {
    return newTabPreviewVisual(this.newTabProgress).addressBackgroundOpacity;
  }

  private handoffPlusOpacity(): number {
    return this.handoffUsesPendingSlot()
      ? 0
      : newTabHandoffVisual(this.addressHandoffProgress).plusOpacity;
  }

  private handoffPlaceholderOpacity(): number {
    return newTabHandoffVisual(this.addressHandoffProgress).placeholderOpacity;
  }

  private handoffPlusScale(): number {
    return newTabHandoffVisual(this.addressHandoffProgress).plusScale;
  }

  private handoffPlaceholderScale(): number {
    return newTabHandoffVisual(this.addressHandoffProgress).placeholderScale;
  }

  private handoffPlaceholderTranslateX(): number {
    // Keep the placeholder on the same centered track as the normal collapsed
    // address field; the handoff must not introduce a second horizontal jump.
    return 0;
  }

  private handoffUsesPendingSlot(): boolean {
    return this.pendingTab !== undefined && this.previewKind === TabPreviewKind.NEW_TAB;
  }

  private pendingItemIndex(): number {
    return pendingTabVisualIndex(
      this.pendingTab?.tab.id ?? '',
      this.tabs.map((tab: BrowserTabRecord): string => tab.id)
    );
  }

  private handoffIndex(): number {
    return this.handoffUsesPendingSlot() ? this.pendingItemIndex() : this.activeIndex;
  }

  private handoffOwnsAddressSlot(): boolean {
    // During the outgoing spring the handoff layer is mounted beside the
    // pending plus, so the current tab must remain visible. Once the draft is
    // committed, the handoff layer becomes the sole owner of the active slot
    // until the plus-to-placeholder crossfade has finished.
    return this.addressHandoffMounted && this.pendingTab === undefined;
  }

  private touchPoint(event: TouchEvent): TouchObject | undefined {
    if (event.touches !== undefined && event.touches.length > 0) {
      return event.touches[0];
    }
    if (event.changedTouches !== undefined && event.changedTouches.length > 0) {
      return event.changedTouches[0];
    }
    return undefined;
  }

  private handleTouch(event?: TouchEvent): void {
    if (event === undefined || event.type !== TouchType.Down) {
      return;
    }
    const point: TouchObject | undefined = this.touchPoint(event);
    if (point === undefined) {
      return;
    }
    const windowX: number = point.windowX;
    const windowY: number = point.windowY;
    const startsInAddressStrip: boolean = isPointInTabBar(
      windowX,
      windowY,
      this.addressStripRect
    );
    const ownership = beginTouchOwnership(startsInAddressStrip, '');
    this.touchStartX = windowX;
    this.touchStartY = windowY;
    this.onGestureTouchStart(
      windowX,
      windowY,
      startsInAddressStrip,
      ownership.owner,
      ownership.buttonId
    );
  }

  @Builder
  private tabItem(tab: BrowserTabRecord, index: number) {
    AddressSearchBar({
      address: index === this.activeIndex ? this.address : lastValidUrlForTab(tab),
      pageTitle: index === this.activeIndex ? this.pageTitle : tab.title,
      searchQuery: index === this.activeIndex
        ? this.searchQuery
        : tab.addressSource === 'search'
          ? (tab.addressQuery ?? searchQueryForUrl(lastValidUrlForTab(tab)) ?? '')
          : '',
      initialDraft: index === this.activeIndex ? this.addressDraft : '',
      inputIdentity: index === this.activeIndex ? this.activeInputIdentity : `address-input-${tab.id}`,
      selectedFontSize: this.selectedFontSize,
      webReady: index === this.activeIndex && this.webReady,
      desktopMode: index === this.activeIndex && this.desktopMode,
      downloadActive: addressSearchBarDownloadProps(
        addressTabStripDownloadSnapshotForItem(this.downloadProgress, index, this.activeIndex)
      ).downloadActive,
      downloadProgress: addressSearchBarDownloadProps(
        addressTabStripDownloadSnapshotForItem(this.downloadProgress, index, this.activeIndex)
      ).downloadProgress,
      onNavigate: index === this.activeIndex ? this.onAddressSubmit : (_value: string) => undefined,
      onFontSize: index === this.activeIndex ? this.onFontSize : (_size: PageFontSize) => undefined,
      onPageAction: index === this.activeIndex ? this.onPageAction : (_action: PageAction) => undefined,
      onOpenAddress: index === this.activeIndex ? this.onOpenAddress : () => undefined,
      onAddressCancel: index === this.activeIndex ? this.onAddressCancel : () => undefined,
      onDraftChange: index === this.activeIndex ? this.onAddressChange : (_value: string) => undefined,
      onInputFocusChange: index === this.activeIndex ? this.onInputFocusChange : (_focused: boolean) => undefined,
      focusRequestToken: index === this.activeIndex ? this.inputFocusRequestToken : 0,
      allowFocus: index === this.activeIndex && !this.interactionLocked && this.addressInputFocusEnabled,
      gestureEnabled: index === this.activeIndex && !this.interactionLocked,
      inputMounted: index === this.activeIndex ? this.inputMounted : true,
      editorActive: index === this.activeIndex && this.addressEditing,
      editorClosing: index === this.activeIndex && this.barMode === 'collapsing',
      inputExpandProgress: index === this.activeIndex ? this.inputExpandProgress : 0,
      onGestureCancel: index === this.activeIndex ? this.onGestureCancel : () => undefined,
      transitionCompact: this.overviewTransitionActive
    })
      .id(`address-tab-item-${tab.id}`)
      .width(this.itemWidth())
      .height(this.frameHeight())
      .position({ x: this.itemOffset(index), y: 0 })
      .opacity(this.itemOpacity(index))
      // An adjacent tab is a transient visual item. If the gesture commits or
      // springs back, let ArkUI fade that item out before its keyed node is
      // removed. A committed handoff disables this exit animation for every
      // item so the old active capsule cannot overlap the handoff owner.
      .transition(
        shouldAnimateAddressItemExit(index, this.activeIndex, this.addressHandoffMounted)
          ? TransitionEffect.asymmetric(
            TransitionEffect.IDENTITY,
            TransitionEffect.OPACITY
          ).animation({ duration: SAFARI_ADDRESS_PREVIEW_FADE_DURATION_MS, curve: Curve.EaseOut })
          : TransitionEffect.IDENTITY
      )
      .hitTestBehavior(index === this.activeIndex ? HitTestMode.Default : HitTestMode.None);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.overviewTransitionActive) {
        if (this.activeIndex >= 0 && this.activeIndex < this.tabs.length) {
          this.tabItem(this.tabs[this.activeIndex], this.activeIndex);
        }
      } else {
        ForEach(this.tabs, (tab: BrowserTabRecord, index: number) => {
          if (shouldRenderAddressItem(index, this.activeIndex, this.displayDragX,
            this.tabs.length, this.previewKind, this.handoffOwnsAddressSlot())) {
            this.tabItem(tab, index);
          }
        }, (tab: BrowserTabRecord) => tab.id);
      }
      if (!this.overviewTransitionActive && this.pendingTab !== undefined && shouldRenderPendingTabPreview(
        this.previewKind, this.newTabProgress)) {
        Stack({ alignContent: Alignment.Center }) {
          Column() {
          }
            .width('100%')
            .height('100%')
            .backgroundColor('#BFFFFFFF')
            .borderRadius(ADDRESS_PREVIEW_SURFACE.cornerRadius)
            .opacity(this.addressBackgroundOpacity());
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(26)
            .fontColor(['#1677FF'])
            .opacity(this.addressPlusOpacity());
          }
          .id('pending-address-tab-item')
          .width(this.itemWidth())
          .height(ADDRESS_SEARCH_BAR_STYLE.height)
          .position({ x: this.itemOffset(this.pendingItemIndex()), y: ADDRESS_SEARCH_BAR_TOP_PADDING })
          .backgroundColor(Color.Transparent)
          .borderRadius(ADDRESS_PREVIEW_SURFACE.cornerRadius)
          .clip(ADDRESS_PREVIEW_SURFACE.clipsChildren)
          .hitTestBehavior(HitTestMode.None);
      }
      if (!this.overviewTransitionActive && shouldRenderAddressHandoff(
        this.addressHandoffMounted, this.addressHandoffProgress)) {
        Stack() {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(26)
            .fontColor(['#1677FF'])
            .opacity(this.handoffPlusOpacity())
            .scale({ x: this.handoffPlusScale(), y: this.handoffPlusScale() });
          Text('搜索或输入网站')
            .fontSize(16)
            .fontColor(addressTextColorFor(false))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(newTabHandoffVisual(this.addressHandoffProgress).placeholderTextAlignment === 'start'
              ? TextAlign.Start
              : TextAlign.Center)
            .width('100%')
            .padding({ left: 0, right: 0 })
            .opacity(this.handoffPlaceholderOpacity())
            .scale({ x: this.handoffPlaceholderScale(), y: this.handoffPlaceholderScale() })
            .translate({ x: this.handoffPlaceholderTranslateX(), y: 0, z: 0 });
        }
          .id('new-tab-address-handoff')
          .width(this.itemWidth())
          .height(ADDRESS_SEARCH_BAR_STYLE.height)
          .clip(true)
          .position({ x: this.itemOffset(this.handoffIndex()), y: ADDRESS_SEARCH_BAR_TOP_PADDING })
          .backgroundColor(this.handoffUsesPendingSlot() ? Color.Transparent : '#BFFFFFFF')
          .borderRadius(ADDRESS_SEARCH_BAR_STYLE.cornerRadius)
          .border({ width: this.handoffUsesPendingSlot() ? 0 : 1,
            color: this.handoffUsesPendingSlot() ? '#00000000' : '#55FFFFFF' })
          .hitTestBehavior(HitTestMode.None);
      }
    }
      .id('address-tab-strip')
      .width(this.frameWidth())
      .height(this.frameHeight())
      .position(this.framePosition())
      .scale({ x: this.frameScaleX(), y: this.frameScaleY(), z: 1 })
      .translate({ x: 0, y: this.frameTranslateY(), z: 0 })
      .opacity(this.overviewChromeFrame?.addressOpacity ?? 1)
      .clipShape(this.addressTrackClipShape())
      // The transition layer is mounted above the bottom chrome so the
      // address capsule can morph independently. In its normal position,
      // transparent hit testing keeps the capsule interactive without
      // swallowing the toolbar and tab-count button underneath it.
      .hitTestBehavior(this.overviewTransitionActive ? HitTestMode.None : HitTestMode.Transparent)
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        const globalPosition = newValue.globalPosition ?? newValue.position;
        const measuredWidth: number = Number(newValue.width);
        if (Number.isFinite(measuredWidth) && measuredWidth > 0 &&
          this.addressLayoutWidth !== measuredWidth) {
          this.addressLayoutWidth = measuredWidth;
        }
        this.addressStripRect = {
          x: Number(globalPosition?.x ?? 0),
          y: Number(globalPosition?.y ?? 0),
          width: measuredWidth,
          height: Number(newValue.height)
        };
        this.onGestureRectChange(
          this.addressStripRect.x,
          this.addressStripRect.y,
          measuredWidth,
          Number(newValue.height)
        );
      })
      .onTouch((event?: TouchEvent) => this.handleTouch(event))
      .gesture(
        PanGesture(new PanGestureOptions({ direction: PanDirection.All, fingers: 1, distance: 8 }))
          .onActionStart((_event: GestureEvent) =>
            this.onGestureStart(this.touchStartX, this.touchStartY))
          .onActionUpdate((event: GestureEvent) => this.onGestureUpdate(event))
          .onActionEnd((event: GestureEvent) => this.onGestureEnd(event))
          .onActionCancel(() => this.onGestureCancel())
      );
  }
}
