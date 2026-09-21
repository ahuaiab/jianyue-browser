import { describe, expect, it } from '@ohos/hypium';
import {
  BrowserChromeAnchor,
  BrowserChromeLayoutFrame,
  browserChromeLayoutFrame,
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

    it('reserves start and end anchors for future grip-aware placement', 0, () => {
      const start: BrowserChromeLayoutFrame = browserChromeLayoutFrame(
        800, 24, 36, BrowserChromeAnchor.START);
      const end: BrowserChromeLayoutFrame = browserChromeLayoutFrame(
        800, 24, 36, BrowserChromeAnchor.END);

      expect(start.left).assertEqual(24);
      expect(end.left).assertEqual(364);
    });

    it('shrinks only when the safe width is narrower than the design width', 0, () => {
      const frame: BrowserChromeLayoutFrame = browserChromeLayoutFrame(360, 16, 16);

      expect(frame.width).assertEqual(328);
      expect(frame.left).assertEqual(16);
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
