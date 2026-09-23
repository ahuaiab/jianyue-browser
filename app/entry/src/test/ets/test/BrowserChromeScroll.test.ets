import { describe, expect, it } from '@ohos/hypium';
import {
  BrowserChromeScrollDirection,
  bottomChromeHiddenForScroll,
  browserChromeScrollDirection
} from '../../../main/ets/browser/model/BrowserChromeScroll';

export default function browserChromeScrollTest() {
  describe('BrowserChromeScroll', () => {
    it('detects page-up and page-down directions from Web yOffset', 0, () => {
      expect(browserChromeScrollDirection(0, 12))
        .assertEqual(BrowserChromeScrollDirection.PAGE_UP);
      expect(browserChromeScrollDirection(12, 0))
        .assertEqual(BrowserChromeScrollDirection.PAGE_DOWN);
    });

    it('ignores offset noise below the direction threshold', 0, () => {
      expect(browserChromeScrollDirection(10, 15))
        .assertEqual(BrowserChromeScrollDirection.NONE);
      expect(browserChromeScrollDirection(15, 10))
        .assertEqual(BrowserChromeScrollDirection.NONE);
    });

    it('hides on a settled page-up and reveals on a settled page-down', 0, () => {
      expect(bottomChromeHiddenForScroll(false, 0, 8)).assertTrue();
      expect(bottomChromeHiddenForScroll(true, 20, 12)).assertFalse();
      expect(bottomChromeHiddenForScroll(true, 12, 20)).assertTrue();
    });

    it('keeps the chrome visible at the page top and ignores a first sample', 0, () => {
      expect(bottomChromeHiddenForScroll(true, 16, 0)).assertFalse();
      expect(bottomChromeHiddenForScroll(false, undefined, 32)).assertFalse();
    });
  });
}
