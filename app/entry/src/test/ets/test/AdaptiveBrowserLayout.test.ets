import { describe, expect, it } from '@ohos/hypium';
import {
  BrowserChromeAnchor,
  BrowserChromeHandedness,
  BrowserChromeOperatingHand,
  BrowserChromeLayoutFrame,
  LibraryTabInnerJoinFrame,
  browserChromeLayoutFrame,
  browserChromeSurfaceFrame,
  browserChromeSurfaceHorizontalOffset,
  libraryTabInnerJoinFrame,
  browserChromeAnchorForHandedness,
  browserChromeAnchorForOperatingHand,
  browserChromeFloatingControlOffset,
  SAFARI_BROWSER_CHROME_DESIGN_WIDTH_VP,
  safariBottomChromeActionSlotWidth,
  libraryContentCardWidth,
  libraryListWidth
} from '../../../main/ets/browser/model/BrowserVisualMetrics';
import {
  TabOverviewChromeFrame,
  TabOverviewPageFrame,
  tabOverviewChromeFrame,
  tabOverviewPageFrame,
  tabOverviewCardWidth,
  tabOverviewGridWidth,
  tabOverviewGridLeft
} from '../../../main/ets/browser/model/TabOverviewActions';

export default function adaptiveBrowserLayoutTest() {
  describe('AdaptiveBrowserLayout', () => {
    it('keeps the portrait chrome width after rotating to landscape', 0, () => {
      const portrait: BrowserChromeLayoutFrame = browserChromeLayoutFrame(366, 0, 0);
      const landscape: BrowserChromeLayoutFrame = browserChromeLayoutFrame(800, 0, 0);

      expect(SAFARI_BROWSER_CHROME_DESIGN_WIDTH_VP).assertEqual(366);
      expect(portrait.width).assertEqual(366);
      expect(portrait.left).assertEqual(0);
      expect(landscape.width).assertEqual(366);
      expect(landscape.left).assertEqual(217);
    });

    it('centers the fixed chrome on the window while respecting side avoid areas', 0, () => {
      const frame: BrowserChromeLayoutFrame = browserChromeLayoutFrame(800, 24, 36);

      expect(frame.width).assertEqual(366);
      expect(frame.left).assertEqual(217);
      expect(frame.left + frame.width / 2).assertEqual(400);
    });

    it('places the fixed chrome at the requested start and end anchors', 0, () => {
      const start: BrowserChromeLayoutFrame = browserChromeLayoutFrame(
        800, 24, 36, BrowserChromeAnchor.START);
      const end: BrowserChromeLayoutFrame = browserChromeLayoutFrame(
        800, 24, 36, BrowserChromeAnchor.END);

      expect(start.left).assertEqual(24);
      expect(end.left).assertEqual(398);
    });

    it('maps system handedness to a reachable chrome anchor', 0, () => {
      expect(browserChromeAnchorForHandedness(BrowserChromeHandedness.LEFT))
        .assertEqual(BrowserChromeAnchor.START);
      expect(browserChromeAnchorForHandedness(BrowserChromeHandedness.RIGHT))
        .assertEqual(BrowserChromeAnchor.END);
      expect(browserChromeAnchorForHandedness(BrowserChromeHandedness.BOTH))
        .assertEqual(BrowserChromeAnchor.CENTER);
      expect(browserChromeAnchorForHandedness(BrowserChromeHandedness.UNKNOWN))
        .assertEqual(BrowserChromeAnchor.CENTER);
    });

    it('maps the operating-hand fallback to a reachable chrome anchor', 0, () => {
      expect(browserChromeAnchorForOperatingHand(BrowserChromeOperatingHand.LEFT))
        .assertEqual(BrowserChromeAnchor.START);
      expect(browserChromeAnchorForOperatingHand(BrowserChromeOperatingHand.RIGHT))
        .assertEqual(BrowserChromeAnchor.END);
      expect(browserChromeAnchorForOperatingHand(BrowserChromeOperatingHand.UNKNOWN))
        .assertEqual(BrowserChromeAnchor.CENTER);
    });

    it('moves independent floating controls inside the same safe region', 0, () => {
      const leftOffset: number = browserChromeFloatingControlOffset(
        800, 24, 36, 108, BrowserChromeAnchor.START);
      const centerOffset: number = browserChromeFloatingControlOffset(
        800, 24, 36, 108, BrowserChromeAnchor.CENTER);
      const rightOffset: number = browserChromeFloatingControlOffset(
        800, 24, 36, 108, BrowserChromeAnchor.END);

      expect(leftOffset).assertEqual(-306);
      expect(centerOffset).assertEqual(0);
      expect(rightOffset).assertEqual(294);
    });

    it('clamps a centered frame only when an avoid area crosses the fixed footprint', 0, () => {
      const leftObstructed: BrowserChromeLayoutFrame = browserChromeLayoutFrame(800, 240, 0);
      const rightObstructed: BrowserChromeLayoutFrame = browserChromeLayoutFrame(800, 0, 240);
      expect(leftObstructed.width).assertEqual(366);
      expect(leftObstructed.left).assertEqual(240);
      expect(rightObstructed.left).assertEqual(194);
      expect(browserChromeSurfaceHorizontalOffset(800, 24, 36, BrowserChromeAnchor.CENTER))
        .assertEqual(0);
    });

    it('centers floating controls on the window and clamps crowded safe regions', 0, () => {
      expect(browserChromeFloatingControlOffset(800, 24, 36, 108, BrowserChromeAnchor.CENTER))
        .assertEqual(0);
      const offset: number = browserChromeFloatingControlOffset(
        300, 180, 12, 108, BrowserChromeAnchor.CENTER);
      expect((300 - 108) / 2 + offset).assertEqual(180);
    });

    it('shrinks only when the safe width is narrower than the design width', 0, () => {
      const frame: BrowserChromeLayoutFrame = browserChromeLayoutFrame(360, 16, 16);

      expect(frame.width).assertEqual(328);
      expect(frame.left).assertEqual(16);
    });

    it('anchors the selected tab to the shared content contour', 0, () => {
      const bookmarks: LibraryTabInnerJoinFrame = libraryTabInnerJoinFrame(326, true, 12);
      const history: LibraryTabInnerJoinFrame = libraryTabInnerJoinFrame(326, false, 12);

      expect(bookmarks.offsetX).assertEqual(24);
      expect(bookmarks.radius).assertEqual(12);
      expect(bookmarks.opensRight).assertEqual(false);
      expect(history.offsetX).assertEqual(163);
      expect(history.radius).assertEqual(12);
      expect(history.opensRight).assertEqual(true);
    });

    it('matches sheet width and handedness to the visible bottom chrome', 0, () => {
      const center: BrowserChromeLayoutFrame = browserChromeSurfaceFrame(
        800, 24, 36, BrowserChromeAnchor.CENTER);
      const start: BrowserChromeLayoutFrame = browserChromeSurfaceFrame(
        800, 24, 36, BrowserChromeAnchor.START);
      const end: BrowserChromeLayoutFrame = browserChromeSurfaceFrame(
        800, 24, 36, BrowserChromeAnchor.END);
      const narrow: BrowserChromeLayoutFrame = browserChromeSurfaceFrame(
        360, 16, 16, BrowserChromeAnchor.CENTER);

      expect(center.width).assertEqual(350);
      expect(center.left).assertEqual(225);
      expect(start.width).assertEqual(350);
      expect(start.left).assertEqual(32);
      expect(end.width).assertEqual(350);
      expect(end.left).assertEqual(406);
      expect(narrow.width).assertEqual(312);
      expect(narrow.left).assertEqual(24);
      expect(browserChromeSurfaceHorizontalOffset(800, 24, 36, BrowserChromeAnchor.START))
        .assertEqual(-193);
      expect(browserChromeSurfaceHorizontalOffset(800, 24, 36, BrowserChromeAnchor.END))
        .assertEqual(181);
    });

    it('keeps sheet content fixed while fitting narrow safe regions', 0, () => {
      const phone: BrowserChromeLayoutFrame = browserChromeSurfaceFrame(366);
      const wide: BrowserChromeLayoutFrame = browserChromeSurfaceFrame(900);
      const narrow: BrowserChromeLayoutFrame = browserChromeSurfaceFrame(300, 16, 16);

      expect(libraryContentCardWidth(phone.width)).assertEqual(326);
      expect(libraryContentCardWidth(wide.width)).assertEqual(326);
      expect(libraryListWidth(libraryContentCardWidth(phone.width))).assertEqual(260.8);
      expect(libraryListWidth(libraryContentCardWidth(wide.width))).assertEqual(260.8);
      expect(libraryContentCardWidth(narrow.width)).assertEqual(228);
      expect(libraryListWidth(libraryContentCardWidth(narrow.width))).assertEqual(228);
    });

    it('keeps action targets fixed while adapting two card columns to the window', 0, () => {
      expect(safariBottomChromeActionSlotWidth(366)).assertEqual(62);
      expect(safariBottomChromeActionSlotWidth(900)).assertEqual(62);
      expect(tabOverviewCardWidth(366)).assertEqual(161);
      expect(tabOverviewCardWidth(900)).assertEqual(428);
      expect(tabOverviewCardWidth(320)).assertEqual(138);
    });

    it('lands four live card slots in two equally sized columns on a wide window', 0, () => {
      const first: TabOverviewPageFrame = tabOverviewPageFrame(1, 900, 700, 0, 0);
      const second: TabOverviewPageFrame = tabOverviewPageFrame(1, 900, 700, 1, 0);
      const third: TabOverviewPageFrame = tabOverviewPageFrame(1, 900, 700, 2, 0);
      const fourth: TabOverviewPageFrame = tabOverviewPageFrame(1, 900, 700, 3, 0);

      expect(tabOverviewGridWidth(900)).assertEqual(900);
      expect(tabOverviewGridLeft(900)).assertEqual(0);
      expect(first.clipLeft).assertEqual(16);
      expect(second.clipLeft).assertEqual(456);
      expect(first.clipWidth).assertEqual(428);
      expect(second.clipWidth).assertEqual(428);
      expect(first.clipHeight).assertEqual(242);
      expect(second.clipHeight).assertEqual(242);
      expect(third.clipLeft).assertEqual(first.clipLeft);
      expect(fourth.clipLeft).assertEqual(second.clipLeft);
      expect(third.clipWidth).assertEqual(first.clipWidth);
      expect(fourth.clipWidth).assertEqual(second.clipWidth);
      expect(third.clipTop - first.clipTop).assertEqual(254);
      expect(fourth.clipTop).assertEqual(third.clipTop);
      expect(first.scaleX).assertEqual(first.scaleY);
    });

    it('fills the asymmetric wide safe region with two card columns', 0, () => {
      const first: TabOverviewPageFrame = tabOverviewPageFrame(1, 900, 700, 0, 0, 0, 0, 32, 12);
      const second: TabOverviewPageFrame = tabOverviewPageFrame(1, 900, 700, 1, 0, 0, 0, 32, 12);

      expect(tabOverviewGridWidth(900, 32, 12)).assertEqual(856);
      expect(tabOverviewGridLeft(900, 32, 12)).assertEqual(32);
      expect(tabOverviewCardWidth(900, 32, 12)).assertEqual(406);
      expect(first.clipLeft).assertEqual(48);
      expect(second.clipLeft).assertEqual(466);
      expect(first.clipWidth).assertEqual(406);
      expect(second.clipWidth).assertEqual(406);
      expect(second.clipLeft + second.clipWidth).assertEqual(872);
      expect(first.scaleX).assertEqual(first.scaleY);
    });

    it('keeps overview geometry finite when window metrics are invalid or crowded', 0, () => {
      expect(tabOverviewGridWidth(900, Number.NaN, Number.POSITIVE_INFINITY)).assertEqual(900);
      expect(tabOverviewGridLeft(900, Number.NaN, Number.POSITIVE_INFINITY)).assertEqual(0);
      expect(tabOverviewGridWidth(900, -32, -12)).assertEqual(900);
      expect(tabOverviewGridLeft(900, -32, -12)).assertEqual(0);
      expect(tabOverviewGridWidth(300, 500, 500)).assertEqual(1);
      expect(tabOverviewGridLeft(300, 500, 500)).assertEqual(299);
      expect(tabOverviewCardWidth(300, 500, 500)).assertEqual(1);
      expect(tabOverviewGridWidth(Number.NaN)).assertEqual(1);
      expect(tabOverviewGridLeft(Number.POSITIVE_INFINITY)).assertEqual(0);
    });

    it('fits grid columns and live pages inside asymmetric narrow avoid areas', 0, () => {
      const first: TabOverviewPageFrame = tabOverviewPageFrame(1, 300, 700, 0, 0, 0, 0, 32, 12);
      const second: TabOverviewPageFrame = tabOverviewPageFrame(1, 300, 700, 1, 0, 0, 0, 32, 12);

      expect(tabOverviewGridWidth(300, 32, 12)).assertEqual(256);
      expect(tabOverviewGridLeft(300, 32, 12)).assertEqual(32);
      expect(tabOverviewCardWidth(300, 32, 12)).assertEqual(106);
      expect(first.clipLeft).assertEqual(48);
      expect(second.clipLeft).assertEqual(166);
      expect(first.clipWidth).assertEqual(106);
      expect(second.clipLeft + second.clipWidth).assertEqual(272);
      expect(first.scaleX).assertEqual(first.scaleY);
    });

    it('starts the overview morph from the same fixed chrome frame', 0, () => {
      const pageFrame: TabOverviewPageFrame = tabOverviewPageFrame(0, 800, 400, 0, 0);
      const chromeFrame: TabOverviewChromeFrame = tabOverviewChromeFrame(
        0, false, 800, 400, 112, pageFrame, 217, 366);

      expect(chromeFrame.addressLeft).assertEqual(217);
      expect(chromeFrame.addressWidth).assertEqual(366);
      expect(chromeFrame.addressVisualLeft).assertEqual(225);
      expect(chromeFrame.addressVisualWidth).assertEqual(350);
    });
  });
}
