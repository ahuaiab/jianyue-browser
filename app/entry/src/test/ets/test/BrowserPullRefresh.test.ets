import { describe, expect, it } from '@ohos/hypium';
import {
  BrowserPullRefreshContentTranslation,
  browserPullRefreshContentTranslation,
  browserPullRefreshIndicatorMode,
  browserPullRefreshOffset,
  browserPullRefreshProgressPercent,
  BrowserPullRefreshIndicatorMode,
  isBrowserWebPageAtTop,
  shouldCaptureBrowserPullGesture,
  shouldRefreshBrowserPageOnPullRelease
} from '../../../main/ets/browser/model/BrowserPullRefresh';

export default function browserPullRefreshTest() {
  describe('BrowserPullRefresh', () => {
    it('caps the exposed blank area at the bottom bar height', 0, () => {
      expect(browserPullRefreshOffset(120, 72)).assertEqual(72);
      expect(browserPullRefreshOffset(36, 72)).assertEqual(38.88);
      expect(browserPullRefreshOffset(-12, 72)).assertEqual(0);
    });

    it('compensates for short finger travel without changing the reveal height', 0, () => {
      expect(browserPullRefreshOffset(114, 120)).assertEqual(120);
      expect(shouldRefreshBrowserPageOnPullRelease(114, 120, true)).assertTrue();
    });

    it('moves the ArkWeb wrapper by the clamped reveal distance', 0, () => {
      const translation: BrowserPullRefreshContentTranslation =
        browserPullRefreshContentTranslation(84, 72);
      expect(translation.x).assertEqual(0);
      expect(translation.y).assertEqual(72);
      expect(translation.z).assertEqual(0);
    });

    it('refreshes only when the full bottom bar height is exposed at page top', 0, () => {
      expect(shouldRefreshBrowserPageOnPullRelease(66, 72, true)).assertFalse();
      expect(shouldRefreshBrowserPageOnPullRelease(67, 72, true)).assertTrue();
      expect(shouldRefreshBrowserPageOnPullRelease(120, 72, false)).assertFalse();
    });

    it('does not refresh when no blank reveal distance is available', 0, () => {
      expect(shouldRefreshBrowserPageOnPullRelease(0, 0, true)).assertFalse();
    });

    it('couples the ring progress to the revealed blank-page distance', 0, () => {
      expect(browserPullRefreshProgressPercent(0, 72)).assertEqual(0);
      expect(browserPullRefreshProgressPercent(18, 72)).assertEqual(27);
      expect(browserPullRefreshProgressPercent(72, 72)).assertEqual(100);
      expect(browserPullRefreshProgressPercent(96, 72)).assertEqual(100);
    });

    it('changes the indicator state at the exact refresh threshold', 0, () => {
      expect(browserPullRefreshIndicatorMode(0, 72, false))
        .assertEqual(BrowserPullRefreshIndicatorMode.HIDDEN);
      expect(browserPullRefreshIndicatorMode(66, 72, false))
        .assertEqual(BrowserPullRefreshIndicatorMode.PULLING);
      expect(browserPullRefreshIndicatorMode(67, 72, false))
        .assertEqual(BrowserPullRefreshIndicatorMode.READY);
      expect(browserPullRefreshIndicatorMode(0, 72, true))
        .assertEqual(BrowserPullRefreshIndicatorMode.REFRESHING);
    });

    it('lets the Web page keep scrolling unless refresh is enabled at its top', 0, () => {
      expect(shouldCaptureBrowserPullGesture(true, true, false, 72)).assertTrue();
      expect(shouldCaptureBrowserPullGesture(true, false, false, 72)).assertFalse();
      expect(shouldCaptureBrowserPullGesture(false, true, false, 72)).assertFalse();
      expect(shouldCaptureBrowserPullGesture(true, true, true, 72)).assertFalse();
      expect(shouldCaptureBrowserPullGesture(true, true, false, 0)).assertFalse();
    });

    it('allows refresh only when the absolute ArkWeb page offset is zero', 0, () => {
      expect(isBrowserWebPageAtTop(-1)).assertFalse();
      expect(isBrowserWebPageAtTop(-120)).assertFalse();
      expect(isBrowserWebPageAtTop(0)).assertTrue();
      expect(isBrowserWebPageAtTop(1)).assertFalse();
      expect(isBrowserWebPageAtTop(24)).assertFalse();
      expect(shouldCaptureBrowserPullGesture(true, isBrowserWebPageAtTop(24), false, 72))
        .assertFalse();
      expect(isBrowserWebPageAtTop(Number.NaN)).assertFalse();
    });
  });
}
