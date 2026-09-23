import { describe, expect, it } from '@ohos/hypium';
import {
  BrowserChromeAnchor,
  BrowserChromeHandedness,
  BrowserChromeOperatingHand,
  BrowserChromeLayoutFrame,
  browserChromeLayoutFrame,
  browserChromeSurfaceFrame,
  browserChromeSurfaceHorizontalOffset,
  browserChromeAnchorForHandedness,
  browserChromeAnchorForOperatingHand,
  browserChromeFloatingControlOffset,
  SAFARI_BROWSER_CHROME_DESIGN_WIDTH_VP
} from '../../../main/ets/browser/model/BrowserVisualMetrics';
import {
  TabOverviewChromeFrame,
  TabOverviewPageFrame,
  tabOverviewChromeFrame,
  tabOverviewPageFrame
} from '../../../main/ets/browser/model/TabOverviewActions';

export default function adaptiveBrowserLayoutTest() {
  describe('AdaptiveBrowserLayout', () => {
    it('keeps the portrait chrome width after rotating to landscape', 0, () => {
      const portrait: BrowserChromeLayoutFrame = browserChromeLayoutFrame(400, 0, 0);
      const landscape: BrowserChromeLayoutFrame = browserChromeLayoutFrame(800, 0, 0);

      expect(SAFARI_BROWSER_CHROME_DESIGN_WIDTH_VP).assertEqual(400);
      expect(portrait.width).assertEqual(400);
      expect(portrait.left).assertEqual(0);
      expect(landscape.width).assertEqual(400);
      expect(landscape.left).assertEqual(200);
    });

    it('centers the fixed chrome inside asymmetric side avoid areas', 0, () => {
      const frame: BrowserChromeLayoutFrame = browserChromeLayoutFrame(800, 24, 36);

      expect(frame.width).assertEqual(400);
      expect(frame.left).assertEqual(194);
    });

    it('places the fixed chrome at the requested start and end anchors', 0, () => {
      const start: BrowserChromeLayoutFrame = browserChromeLayoutFrame(
        800, 24, 36, BrowserChromeAnchor.START);
      const end: BrowserChromeLayoutFrame = browserChromeLayoutFrame(
        800, 24, 36, BrowserChromeAnchor.END);

      expect(start.left).assertEqual(24);
      expect(end.left).assertEqual(364);
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

      expect(leftOffset).assertEqual(-300);
      expect(centerOffset).assertEqual(0);
      expect(rightOffset).assertEqual(300);
    });

    it('shrinks only when the safe width is narrower than the design width', 0, () => {
      const frame: BrowserChromeLayoutFrame = browserChromeLayoutFrame(360, 16, 16);

      expect(frame.width).assertEqual(328);
      expect(frame.left).assertEqual(16);
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

      expect(center.width).assertEqual(384);
      expect(center.left).assertEqual(202);
      expect(start.width).assertEqual(384);
      expect(start.left).assertEqual(32);
      expect(end.width).assertEqual(384);
      expect(end.left).assertEqual(372);
      expect(narrow.width).assertEqual(312);
      expect(narrow.left).assertEqual(24);
      expect(browserChromeSurfaceHorizontalOffset(800, 24, 36, BrowserChromeAnchor.START))
        .assertEqual(-176);
      expect(browserChromeSurfaceHorizontalOffset(800, 24, 36, BrowserChromeAnchor.END))
        .assertEqual(164);
    });

    it('starts the overview morph from the same fixed chrome frame', 0, () => {
      const pageFrame: TabOverviewPageFrame = tabOverviewPageFrame(0, 800, 400, 0, 0);
      const chromeFrame: TabOverviewChromeFrame = tabOverviewChromeFrame(
        0, false, 800, 400, 112, pageFrame, 200, 400);

      expect(chromeFrame.addressLeft).assertEqual(200);
      expect(chromeFrame.addressWidth).assertEqual(400);
      expect(chromeFrame.addressVisualLeft).assertEqual(208);
      expect(chromeFrame.addressVisualWidth).assertEqual(384);
    });
  });
}
