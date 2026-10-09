import { describe, expect, it } from '@ohos/hypium';
import {
  shouldDisableBottomChromeHitTesting,
  shouldDisableTabOverviewLivePageHitTesting,
  shouldMountAddressTransitionLayer,
  shouldMountBottomBrowserBar,
  ADDRESS_SEARCH_BAR_STYLE,
  TAB_OVERVIEW_CAPTION_HEIGHT,
  TAB_OVERVIEW_CAPTION_FONT_SIZE,
  tabOverviewAddressLayerZIndex,
  tabOverviewBorderOwner,
  tabOverviewBottomChromeZIndex,
  tabOverviewCaptionHandoffOpacity,
  tabOverviewCaptionLocalRadius,
  tabOverviewCardCaptionVisualOpacity,
  tabOverviewChromeFrame,
  TabOverviewChromeFrame,
  tabOverviewGridOpacityAtProgress,
  tabOverviewGridOpacityForTransition,
  tabOverviewActiveCardScrollOffset,
  tabOverviewGridMaxScrollOffset,
  tabOverviewGridZIndex,
  tabOverviewLiveCaptionOpacity,
  tabOverviewLivePageContentHeight,
  tabOverviewLocalPageClipFrame,
  tabOverviewLivePageContentTop,
  tabOverviewLivePageZIndex,
  tabOverviewTransitionViewportClipsOverflow,
  tabOverviewThumbnailTopOffset,
  TAB_OVERVIEW_LAYOUT,
  TabOverviewPageFrame,
  TabOverviewLocalPageClipFrame,
  tabOverviewPageFrame,
  tabOverviewSpringEasing,
  tabOverviewSpringVelocity
} from '../../../main/ets/browser/model/TabOverviewActions';
import { verticalOverviewGestureMotion } from '../../../main/ets/browser/model/TabGestureMotion';
import { BROWSER_MODAL_Z_INDEX } from '../../../main/ets/browser/model/BrowserVisualMetrics';

export default function tabOverviewTransitionTest() {
  describe('TabOverviewTransition', () => {
    it('starts the overview page transform with the screen border radius', 0, () => {
      const frame: TabOverviewPageFrame = tabOverviewPageFrame(0, 400, 800, 0, 0);
      expect(frame.scaleX).assertEqual(1);
      expect(frame.scaleY).assertEqual(1);
      expect(frame.translateX).assertEqual(0);
      expect(frame.translateY).assertEqual(0);
      expect(frame.clipLeft).assertEqual(0);
      expect(frame.clipTop).assertEqual(0);
      expect(frame.clipWidth).assertEqual(400);
      expect(frame.clipHeight).assertEqual(800);
      expect(frame.cornerRadius).assertEqual(TAB_OVERVIEW_LAYOUT.cardRadius);
      expect(frame.borderWidth).assertEqual(0);
    });

    it('keeps the live page border radius fixed throughout the overview transform', 0, () => {
      const first: TabOverviewPageFrame = tabOverviewPageFrame(0, 400, 800, 0, 0);
      const middle: TabOverviewPageFrame = tabOverviewPageFrame(0.5, 400, 800, 0, 0);
      const settled: TabOverviewPageFrame = tabOverviewPageFrame(1, 400, 800, 0, 0);
      expect(first.cornerRadius).assertEqual(TAB_OVERVIEW_LAYOUT.cardRadius);
      expect(middle.cornerRadius).assertEqual(TAB_OVERVIEW_LAYOUT.cardRadius);
      expect(settled.cornerRadius).assertEqual(TAB_OVERVIEW_LAYOUT.cardRadius);
    });

    it('lands the live page on the active two-column card slot', 0, () => {
      const frame: TabOverviewPageFrame = tabOverviewPageFrame(1, 400, 800, 0, 0);
      expect(frame.scaleX.toFixed(6)).assertEqual('0.445000');
      expect(frame.scaleY.toFixed(6)).assertEqual('0.445000');
      expect(frame.translateX.toFixed(6)).assertEqual('-95.000000');
      expect(frame.translateY.toFixed(6)).assertEqual('-198.000000');
      expect(frame.clipLeft.toFixed(6)).assertEqual('16.000000');
      expect(frame.clipTop.toFixed(6)).assertEqual('24.000000');
      expect(frame.clipWidth.toFixed(6)).assertEqual('178.000000');
      expect(frame.clipHeight.toFixed(6)).assertEqual('242.000000');
      expect(frame.cornerRadius).assertEqual(16);
      expect(frame.borderWidth).assertEqual(2);
    });

    it('brings a deep active card into the first visible overview row', 0, () => {
      const firstRowOffset: number = tabOverviewActiveCardScrollOffset(0);
      const thirdRowOffset: number = tabOverviewActiveCardScrollOffset(4);
      const firstRow: TabOverviewPageFrame = tabOverviewPageFrame(1, 400, 800, 0, 0, 0, firstRowOffset);
      const thirdRow: TabOverviewPageFrame = tabOverviewPageFrame(1, 400, 800, 4, 0, 0, thirdRowOffset);
      expect(firstRowOffset).assertEqual(0);
      expect(thirdRowOffset).assertEqual((TAB_OVERVIEW_LAYOUT.cardHeight + TAB_OVERVIEW_LAYOUT.gap) * 2);
      expect(thirdRow.clipTop).assertEqual(firstRow.clipTop);
      expect(thirdRow.clipHeight).assertEqual(firstRow.clipHeight);
    });

    it('clamps the last active row to the Grid content end', 0, () => {
      const maxScrollOffset: number = tabOverviewGridMaxScrollOffset(19, 800, 0, 0);
      const lastRowOffset: number = tabOverviewActiveCardScrollOffset(18, maxScrollOffset);
      const rawLastRowOffset: number = tabOverviewActiveCardScrollOffset(18);
      expect(lastRowOffset).assertEqual(maxScrollOffset);
      expect(lastRowOffset < rawLastRowOffset).assertTrue();
      const lastRow: TabOverviewPageFrame = tabOverviewPageFrame(
        1, 400, 800, 18, 0, 0, lastRowOffset
      );
      expect(lastRow.clipTop).assertEqual(488);
    });

    it('moves the live page with the measured Grid scroll offset', 0, () => {
      const atGridOrigin: TabOverviewPageFrame = tabOverviewPageFrame(
        1, 400, 800, 4, 0, 0, 0
      );
      const afterGridScroll: TabOverviewPageFrame = tabOverviewPageFrame(
        1, 400, 800, 4, 0, 0, 120
      );
      expect(afterGridScroll.clipTop.toFixed(6)).assertEqual((atGridOrigin.clipTop - 120).toFixed(6));
      expect(afterGridScroll.translateY.toFixed(6)).assertEqual((atGridOrigin.translateY - 120).toFixed(6));
      expect(afterGridScroll.captionLocalTop).assertEqual(atGridOrigin.captionLocalTop);
    });

    it('shows the card grid from the first visible shrink frame', 0, () => {
      expect(tabOverviewGridOpacityAtProgress(0, true) > 0).assertTrue();
      expect(tabOverviewGridOpacityAtProgress(0.01, true) >
        tabOverviewGridOpacityAtProgress(0, true)).assertTrue();
      expect(tabOverviewGridOpacityAtProgress(0.25, true) >
        tabOverviewGridOpacityAtProgress(0.01, true)).assertTrue();
      expect(tabOverviewGridOpacityAtProgress(0.5, true) > 0).assertTrue();
      expect(tabOverviewGridOpacityAtProgress(0.5, true) < 1).assertTrue();
      expect(tabOverviewGridOpacityAtProgress(0.92, true) > 0).assertTrue();
      expect(tabOverviewGridOpacityAtProgress(0.96, true) > 0).assertTrue();
      expect(tabOverviewGridOpacityAtProgress(1, true)).assertEqual(1);
    });

    it('removes the overview grid before reverse expansion reaches the full page', 0, () => {
      expect(tabOverviewGridOpacityForTransition(1, true, true)).assertEqual(0);
      expect(tabOverviewGridOpacityForTransition(0.5, true, true)).assertEqual(0);
      expect(tabOverviewGridOpacityForTransition(0.35, true, true)).assertEqual(0);
      expect(tabOverviewGridOpacityForTransition(0, true, true)).assertEqual(0);
      expect(tabOverviewGridOpacityForTransition(-0.1, true, true)).assertEqual(0);
      expect(tabOverviewGridOpacityForTransition(0, true, false) > 0).assertTrue();
    });

    it('keeps the background crop stable while the live page crosses the top inset', 0, () => {
      const identity: TabOverviewPageFrame = tabOverviewPageFrame(0, 400, 800, 0, 137);
      const nearIdentity: TabOverviewPageFrame = tabOverviewPageFrame(0.001, 400, 800, 0, 137);
      const handoffMiddle: TabOverviewPageFrame = tabOverviewPageFrame(0.5, 400, 800, 0, 137);
      const handoffEnd: TabOverviewPageFrame = tabOverviewPageFrame(1, 400, 800, 0, 137);
      const middle: TabOverviewPageFrame = tabOverviewPageFrame(0.5, 400, 800, 0, 137);
      expect(tabOverviewLivePageContentTop(identity, 137)).assertEqual(137);
      // The safe-area handoff follows the entire page morph and must not jump
      // to zero on its first transformed frame.
      const nearIdentityTop: number = tabOverviewLivePageContentTop(nearIdentity, 137);
      const handoffMiddleTop: number = tabOverviewLivePageContentTop(handoffMiddle, 137);
      expect(nearIdentityTop > 136).assertTrue();
      expect(nearIdentityTop < 137).assertTrue();
      expect(handoffMiddleTop < nearIdentityTop).assertTrue();
      expect(handoffMiddleTop > 0).assertTrue();
      expect(tabOverviewLivePageContentTop(handoffEnd, 137)).assertEqual(0);
      expect(tabOverviewLivePageContentTop(middle, 137)).assertEqual(68.5);
      expect(tabOverviewLivePageContentTop(tabOverviewPageFrame(1, 400, 800, 0, 137), 137))
        .assertEqual(0);
      expect(tabOverviewLivePageContentHeight(identity, 800, 137)).assertEqual(663);
      expect(tabOverviewLivePageContentHeight(middle, 800, 137)).assertEqual(663);
    });

    it('clips transformed page pixels to the transition viewport', 0, () => {
      expect(tabOverviewTransitionViewportClipsOverflow()).assertTrue();
    });

    it('derives a local rounded clip window for transformed page pixels', 0, () => {
      const page: TabOverviewPageFrame = tabOverviewPageFrame(1, 400, 800, 0, 0);
      const clip: TabOverviewLocalPageClipFrame = tabOverviewLocalPageClipFrame(page, 400, 800);
      expect(clip.left.toFixed(6)).assertEqual('0.000000');
      expect(clip.top.toFixed(6)).assertEqual('0.000000');
      expect(clip.width.toFixed(6)).assertEqual('400.000000');
      expect(clip.height.toFixed(6)).assertEqual('543.820225');
      expect(clip.cornerRadius.toFixed(6)).assertEqual('35.955056');
    });

    it('keeps every static tab thumbnail flush with the card top', 0, () => {
      expect(tabOverviewThumbnailTopOffset(137, 400)).assertEqual(0);
      expect(tabOverviewThumbnailTopOffset(48, 720)).assertEqual(0);
      expect(tabOverviewThumbnailTopOffset(0, 400)).assertEqual(0);
    });

    it('reveals the live page label before it shrinks into the card', 0, () => {
      expect(tabOverviewLiveCaptionOpacity(0)).assertEqual(0);
      expect(tabOverviewLiveCaptionOpacity(0.05) > 0).assertTrue();
      expect(tabOverviewLiveCaptionOpacity(0.22)).assertEqual(1);
      expect(tabOverviewLiveCaptionOpacity(0.7)).assertEqual(1);
      expect(tabOverviewLiveCaptionOpacity(0.92)).assertEqual(1);
      expect(tabOverviewLiveCaptionOpacity(0.98)).assertEqual(1);
      expect(tabOverviewLiveCaptionOpacity(1)).assertEqual(1);
    });

    it('keeps a single visual caption owner while the live page is the card', 0, () => {
      expect(tabOverviewCardCaptionVisualOpacity(true)).assertEqual(0);
      expect(tabOverviewCardCaptionVisualOpacity(false)).assertEqual(1);
    });

    it('uses a compact title size for both overview caption owners', 0, () => {
      expect(TAB_OVERVIEW_CAPTION_FONT_SIZE).assertEqual(10);
    });

    it('keeps the live caption radius equal to the visible page border radius', 0, () => {
      const frame: TabOverviewPageFrame = tabOverviewPageFrame(0.5, 400, 800, 0, 0);
      const localRadius: number = tabOverviewCaptionLocalRadius(frame);
      expect((localRadius * frame.scaleX).toFixed(6)).assertEqual(frame.cornerRadius.toFixed(6));
    });

    it('attaches the address bottom to the current card bottom after overlap', 0, () => {
      const page: TabOverviewPageFrame = tabOverviewPageFrame(0.5, 400, 800, 0, 0);
      const frame: TabOverviewChromeFrame = tabOverviewChromeFrame(
        0.5, false, 400, 800, 104, page
      );
      const addressBottom: number = frame.addressVisualTop + frame.addressVisualHeight;
      const cardBottom: number = page.clipTop + page.clipHeight;
      expect(Math.abs(addressBottom - cardBottom) <= 0.000001).assertTrue();
    });

    it('uses the scaled visible address height as the transition root height', 0, () => {
      const page: TabOverviewPageFrame = tabOverviewPageFrame(0.5, 400, 800, 0, 0);
      const frame: TabOverviewChromeFrame = tabOverviewChromeFrame(
        0.5, false, 400, 800, 104, page
      );
      const expectedRootTop: number = frame.addressVisualTop -
        (ADDRESS_SEARCH_BAR_STYLE.height - frame.addressVisualHeight) / 2;
      expect(frame.addressTop.toFixed(6)).assertEqual(expectedRootTop.toFixed(6));
    });

    it('keeps the address row as tall as the card caption during final handoff', 0, () => {
      const progress: number = 0.94;
      const page: TabOverviewPageFrame = tabOverviewPageFrame(progress, 400, 800, 0, 0);
      const frame: TabOverviewChromeFrame = tabOverviewChromeFrame(
        progress, false, 400, 800, 104, page
      );
      expect(frame.addressVisualHeight.toFixed(6)).assertEqual(
        TAB_OVERVIEW_CAPTION_HEIGHT.toFixed(6)
      );
      expect((frame.addressScaleY * ADDRESS_SEARCH_BAR_STYLE.height).toFixed(6))
        .assertEqual(frame.addressVisualHeight.toFixed(6));
    });

    it('starts the monotonic toolbar exit only after the address leaves the bottom chrome', 0, () => {
      const before: TabOverviewPageFrame = tabOverviewPageFrame(0.18, 400, 800, 0, 0);
      const after: TabOverviewPageFrame = tabOverviewPageFrame(0.3, 400, 800, 0, 0);
      const beforeChrome: TabOverviewChromeFrame = tabOverviewChromeFrame(
        0.18, false, 400, 800, 104, before
      );
      const afterChrome: TabOverviewChromeFrame = tabOverviewChromeFrame(
        0.3, false, 400, 800, 104, after
      );
      expect(beforeChrome.toolbarOpacity).assertEqual(1);
      expect(afterChrome.toolbarOpacity < 1).assertTrue();
      expect(afterChrome.toolbarTranslateY > 0).assertTrue();
    });

    it('uses the same toolbar geometry while reversing the overview', 0, () => {
      const page: TabOverviewPageFrame = tabOverviewPageFrame(0.3, 400, 800, 0, 0);
      const entering: TabOverviewChromeFrame = tabOverviewChromeFrame(
        0.3, false, 400, 800, 104, page
      );
      const leaving: TabOverviewChromeFrame = tabOverviewChromeFrame(
        0.3, true, 400, 800, 104, page
      );
      expect(leaving.toolbarOpacity.toFixed(6)).assertEqual(entering.toolbarOpacity.toFixed(6));
      expect(leaving.toolbarTranslateY.toFixed(6)).assertEqual(entering.toolbarTranslateY.toFixed(6));
    });

    it('keeps the address capsule width on the same track as the live page', 0, () => {
      const page: TabOverviewPageFrame = tabOverviewPageFrame(1, 400, 800, 0, 0);
      const frame: TabOverviewChromeFrame = tabOverviewChromeFrame(
        1, false, 400, 800, 104, page
      );
      expect(frame.addressVisualLeft.toFixed(6)).assertEqual(page.clipLeft.toFixed(6));
      expect(frame.addressVisualWidth.toFixed(6)).assertEqual(page.clipWidth.toFixed(6));
      expect(frame.addressScaleX.toFixed(6)).assertEqual(page.scaleX.toFixed(6));
      expect(frame.toolbarOpacity).assertEqual(0);
      expect(frame.toolbarTranslateY).assertEqual(104);
    });

    it('keeps the fixed bottom chrome mounted through the overview endpoint', 0, () => {
      expect(shouldMountBottomBrowserBar(false)).assertTrue();
      expect(shouldMountBottomBrowserBar(true)).assertFalse();
    });

    it('keeps the address transition node mounted for reverse drag recovery', 0, () => {
      expect(shouldMountAddressTransitionLayer(false)).assertTrue();
      expect(shouldMountAddressTransitionLayer(true)).assertFalse();
    });

    it('keeps the bottom chrome above the live page in both directions', 0, () => {
      expect(tabOverviewBottomChromeZIndex(false) > tabOverviewLivePageZIndex(false)).assertTrue();
      expect(tabOverviewBottomChromeZIndex(true) > tabOverviewLivePageZIndex(true)).assertTrue();
    });

    it('keeps the address capsule above the bottom chrome in both directions', 0, () => {
      expect(tabOverviewAddressLayerZIndex() > tabOverviewBottomChromeZIndex(false)).assertTrue();
      expect(tabOverviewAddressLayerZIndex() > tabOverviewBottomChromeZIndex(true)).assertTrue();
    });

    it('keeps modal sheets above the address transition layer', 0, () => {
      expect(BROWSER_MODAL_Z_INDEX > tabOverviewAddressLayerZIndex()).assertTrue();
    });

    it('keeps the address capsule on one track during the live shrink', 0, () => {
      const middlePage: TabOverviewPageFrame = tabOverviewPageFrame(0.5, 400, 800, 0, 0);
      const endPage: TabOverviewPageFrame = tabOverviewPageFrame(1, 400, 800, 0, 0);
      const frame: TabOverviewChromeFrame = tabOverviewChromeFrame(
        0.5, false, 400, 800, 104, middlePage
      );
      const expectedWidth: number = 384 + (endPage.clipWidth - 384) * 0.5;
      const addressBottom: number = frame.addressVisualTop + frame.addressVisualHeight;
      const cardBottom: number = middlePage.clipTop + middlePage.clipHeight;
      expect(frame.addressScaleX.toFixed(6)).assertEqual(middlePage.scaleX.toFixed(6));
      expect(addressBottom.toFixed(6)).assertEqual(cardBottom.toFixed(6));
      expect(frame.addressVisualWidth.toFixed(6)).assertEqual(expectedWidth.toFixed(6));
    });

    it('crossfades the address capsule into the settled card caption', 0, () => {
      expect(tabOverviewCaptionHandoffOpacity(0.9, false)).assertEqual(0);
      expect(tabOverviewCaptionHandoffOpacity(0.94, false).toFixed(6)).assertEqual('0.500000');
      expect(tabOverviewCaptionHandoffOpacity(0.98, false)).assertEqual(1);
      expect(tabOverviewCaptionHandoffOpacity(0.94, true).toFixed(6)).assertEqual('0.500000');
      expect(tabOverviewCaptionHandoffOpacity(0.9, true)).assertEqual(0);
    });

    it('hands the address capsule off before the card label appears', 0, () => {
      const early: TabOverviewPageFrame = tabOverviewPageFrame(0.82, 400, 800, 0, 0);
      const middle: TabOverviewPageFrame = tabOverviewPageFrame(0.86, 400, 800, 0, 0);
      const late: TabOverviewPageFrame = tabOverviewPageFrame(0.94, 400, 800, 0, 0);
      const earlyChrome: TabOverviewChromeFrame = tabOverviewChromeFrame(
        0.82, false, 400, 800, 104, early
      );
      const middleChrome: TabOverviewChromeFrame = tabOverviewChromeFrame(
        0.86, false, 400, 800, 104, middle
      );
      const lateChrome: TabOverviewChromeFrame = tabOverviewChromeFrame(
        0.94, false, 400, 800, 104, late
      );
      expect(earlyChrome.addressOpacity).assertEqual(1);
      expect(middleChrome.addressOpacity > 0).assertTrue();
      expect(middleChrome.addressOpacity < 1).assertTrue();
      expect(lateChrome.addressOpacity).assertEqual(0);
    });

    it('keeps the chrome on one track without decorative rebound on entry', 0, () => {
      const page: TabOverviewPageFrame = tabOverviewPageFrame(0.33, 400, 800, 0, 0);
      const frame: TabOverviewChromeFrame = tabOverviewChromeFrame(
        0.33, false, 400, 800, 104, page
      );
      expect(frame.addressJellyScaleX).assertEqual(1);
      expect(frame.addressJellyScaleY).assertEqual(1);
      expect(frame.addressJellyTranslateY).assertEqual(0);
      expect(frame.toolbarScaleX).assertEqual(1);
      expect(frame.toolbarScaleY).assertEqual(1);
    });

    it('keeps the address track fixed during an upward overview drag', 0, () => {
      const motion = verticalOverviewGestureMotion();
      expect(motion.rawDragX).assertEqual(0);
      expect(motion.normalizedProgress).assertEqual(0);
      expect(motion.pageTranslateX).assertEqual(0);
      expect(motion.adjacentTranslateX).assertEqual(0);
      expect(motion.isDragging).assertTrue();
    });

    it('returns the address capsule and toolbar through one reversible frame', 0, () => {
      const page: TabOverviewPageFrame = tabOverviewPageFrame(0, 400, 800, 0, 0);
      const frame: TabOverviewChromeFrame = tabOverviewChromeFrame(
        0, true, 400, 800, 104, page
      );
      expect(frame.addressVisualLeft).assertEqual(8);
      expect(frame.addressVisualWidth).assertEqual(384);
      expect(frame.addressVisualTop).assertEqual(704);
      expect(frame.toolbarOpacity).assertEqual(1);
      expect(frame.toolbarTranslateY).assertEqual(0);
    });

    it('keeps the chrome on one track while the address capsule merges back', 0, () => {
      const page: TabOverviewPageFrame = tabOverviewPageFrame(0.09, 400, 800, 0, 0);
      const jellyFrame: TabOverviewChromeFrame = tabOverviewChromeFrame(
        0.09, true, 400, 800, 104, page
      );
      expect(jellyFrame.addressJellyScaleX).assertEqual(1);
      expect(jellyFrame.addressJellyScaleY).assertEqual(1);
      expect(jellyFrame.addressJellyTranslateY).assertEqual(0);
      const toolbarPage: TabOverviewPageFrame = tabOverviewPageFrame(0.3, 400, 800, 0, 0);
      const toolbarFrame: TabOverviewChromeFrame = tabOverviewChromeFrame(
        0.3, true, 400, 800, 104, toolbarPage
      );
      expect(toolbarFrame.toolbarOpacity > 0).assertTrue();
      expect(toolbarFrame.toolbarOpacity < 1).assertTrue();
      expect(toolbarFrame.toolbarScaleX).assertEqual(1);
      expect(toolbarFrame.toolbarScaleY).assertEqual(1);
    });

    it('keeps the live label attached to the shrinking page bottom', 0, () => {
      const early: TabOverviewPageFrame = tabOverviewPageFrame(0.05, 400, 800, 0, 0);
      const middle: TabOverviewPageFrame = tabOverviewPageFrame(0.7, 400, 800, 0, 0);
      const end: TabOverviewPageFrame = tabOverviewPageFrame(1, 400, 800, 0, 0);
      const earlyBottom: number = (early.captionLocalTop + early.captionLocalHeight) * early.scaleY;
      const middleBottom: number = (middle.captionLocalTop + middle.captionLocalHeight) * middle.scaleY;
      expect(earlyBottom.toFixed(6)).assertEqual(early.clipHeight.toFixed(6));
      expect(middleBottom.toFixed(6)).assertEqual(middle.clipHeight.toFixed(6));
      expect((early.captionLocalHeight * early.scaleY).toFixed(6))
        .assertEqual(TAB_OVERVIEW_CAPTION_HEIGHT.toFixed(6));
      expect((middle.captionLocalHeight * middle.scaleY).toFixed(6))
        .assertEqual(TAB_OVERVIEW_CAPTION_HEIGHT.toFixed(6));
      expect((end.captionLocalHeight * end.scaleY).toFixed(6))
        .assertEqual(TAB_OVERVIEW_CAPTION_HEIGHT.toFixed(6));
      expect((early.captionContentScale * early.scaleY).toFixed(6)).assertEqual('1.000000');
      expect((middle.captionContentScale * middle.scaleY).toFixed(6)).assertEqual('1.000000');
      expect((end.captionContentScale * end.scaleY).toFixed(6)).assertEqual('1.000000');
    });

    it('normalizes release velocity for a native interpolating spring', 0, () => {
      expect(tabOverviewSpringVelocity(0.4, 1, -240, 800).toFixed(3)).assertEqual('0.500');
      expect(tabOverviewSpringVelocity(0.6, 0, 240, 800).toFixed(3)).assertEqual('0.500');
      expect(tabOverviewSpringVelocity(0.4, 1, 240, 800).toFixed(3)).assertEqual('-0.500');
      expect(tabOverviewSpringVelocity(0.4, 1, -10000, 800)).assertEqual(3);
      expect(tabOverviewSpringVelocity(0.4, 1, Number.NaN, 800)).assertEqual(0);
      expect(tabOverviewSpringEasing(0.4, 1, -240, 800))
        .assertEqual('interpolating-spring(0.500, 1, 228, 30)');
    });

    it('keeps exactly one blue border owner through the overview handoff', 0, () => {
      expect(tabOverviewBorderOwner(0, false)).assertEqual('none');
      expect(tabOverviewBorderOwner(0.97, false)).assertEqual('live-page');
      // The live page is the foreground layer throughout the overview. Its
      // outline must remain the visible ring after the page reaches the card
      // slot; the card shell sits underneath it and cannot own that pixel.
      expect(tabOverviewBorderOwner(0.98, false)).assertEqual('live-page');
      expect(tabOverviewBorderOwner(1, false)).assertEqual('live-page');
      expect(tabOverviewBorderOwner(1, true)).assertEqual('live-page');
      expect(tabOverviewBorderOwner(0.4, true)).assertEqual('live-page');
    });

    it('hands settled card interaction above the live page without changing morph order', 0, () => {
      // During the interactive morph the live page stays visually in front,
      // but once overview settles the card grid must own the pointer stream.
      // A native ArkWeb surface can otherwise consume the active card's tap
      // and horizontal close gesture even when its ArkUI wrapper is None.
      expect(tabOverviewLivePageZIndex(false) > tabOverviewGridZIndex(0.5, false)).assertTrue();
      expect(tabOverviewGridZIndex(1, false) > tabOverviewLivePageZIndex(false)).assertTrue();
      expect(tabOverviewLivePageZIndex(true) > tabOverviewGridZIndex(1, true)).assertTrue();
    });

    it('removes live page hit testing while the overview is visible', 0, () => {
      expect(shouldDisableTabOverviewLivePageHitTesting(0)).assertFalse();
      expect(shouldDisableTabOverviewLivePageHitTesting(-0.1)).assertFalse();
      expect(shouldDisableTabOverviewLivePageHitTesting(0.01)).assertTrue();
      expect(shouldDisableTabOverviewLivePageHitTesting(1)).assertTrue();
    });

    it('keeps the bottom chrome gesture alive until the overview drag ends', 0, () => {
      expect(shouldDisableBottomChromeHitTesting(0.2, true, false)).assertFalse();
      expect(shouldDisableBottomChromeHitTesting(0.2, false, false)).assertTrue();
      expect(shouldDisableBottomChromeHitTesting(0, true, false)).assertFalse();
      expect(shouldDisableBottomChromeHitTesting(0.2, true, true)).assertTrue();
    });

    it('shrinks the live page monotonically toward the card slot', 0, () => {
      const start: TabOverviewPageFrame = tabOverviewPageFrame(0, 400, 800, 0, 0);
      const middle: TabOverviewPageFrame = tabOverviewPageFrame(0.5, 400, 800, 0, 0);
      const end: TabOverviewPageFrame = tabOverviewPageFrame(1, 400, 800, 0, 0);
      expect(middle.scaleX < start.scaleX).assertTrue();
      expect(middle.scaleY < start.scaleY).assertTrue();
      expect(end.scaleX < middle.scaleX).assertTrue();
      expect(end.scaleY < middle.scaleY).assertTrue();
      expect(end.scaleX).assertEqual(end.scaleY);
    });

    it('moves the live page with the grid when the tab search field is revealed', 0, () => {
      const hiddenSearch: TabOverviewPageFrame = tabOverviewPageFrame(1, 400, 800, 0, 137, 0);
      const revealedSearch: TabOverviewPageFrame = tabOverviewPageFrame(1, 400, 800, 0, 137, 1);
      expect(hiddenSearch.clipTop).assertEqual(145);
      expect(revealedSearch.clipTop).assertEqual(199);
      expect(revealedSearch.clipTop > hiddenSearch.clipTop).assertTrue();
      expect(revealedSearch.translateY > hiddenSearch.translateY).assertTrue();
    });
  });
}
