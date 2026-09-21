import { describe, expect, it } from '@ohos/hypium';
import {
  availableContentHeight,
  avoidRectBottom,
  safeAreaInsetsFromAvoidAreas,
  WindowAvoidAreaRects,
  WindowAvoidRect,
  WindowAvoidInsets,
  topContentInsetFromAvoidRects
} from '../../../main/ets/browser/model/WindowAvoidance';

const EMPTY_AVOID_RECT: WindowAvoidRect = { left: 0, top: 0, width: 0, height: 0 };

export default function windowAvoidanceTest() {
  describe('WindowAvoidance', () => {
    it('uses the rectangle bottom edge instead of height alone', 0, () => {
      expect(avoidRectBottom(12, 36)).assertEqual(48);
    });

    it('uses the larger system or cutout bottom edge', 0, () => {
      expect(topContentInsetFromAvoidRects(8, 24, 0, 48)).assertEqual(48);
      expect(topContentInsetFromAvoidRects(12, 36, 0, 24)).assertEqual(48);
    });

    it('clamps invalid or negative rectangles to zero', 0, () => {
      expect(avoidRectBottom(-20, 4)).assertEqual(0);
      expect(avoidRectBottom(0, -4)).assertEqual(0);
      expect(avoidRectBottom(Number.NaN, 40)).assertEqual(0);
      expect(topContentInsetFromAvoidRects(-20, 4, Number.NaN, 40)).assertEqual(0);
    });

    it('keeps the web content height equal to the remaining viewport', 0, () => {
      expect(availableContentHeight(800, 64)).assertEqual(736);
      expect(availableContentHeight(800, 0)).assertEqual(800);
      expect(availableContentHeight(40, 64)).assertEqual(1);
    });

    it('merges four window edges from separate avoid areas', 0, () => {
      const systemArea: WindowAvoidAreaRects = {
        topRect: EMPTY_AVOID_RECT,
        bottomRect: EMPTY_AVOID_RECT,
        leftRect: { left: 0, top: 0, width: 32, height: 1080 },
        rightRect: EMPTY_AVOID_RECT
      };
      const cutoutArea: WindowAvoidAreaRects = {
        topRect: { left: 0, top: 0, width: 2400, height: 60 },
        bottomRect: EMPTY_AVOID_RECT,
        leftRect: EMPTY_AVOID_RECT,
        rightRect: EMPTY_AVOID_RECT
      };
      const navigationArea: WindowAvoidAreaRects = {
        topRect: EMPTY_AVOID_RECT,
        bottomRect: { left: 0, top: 982, width: 2400, height: 98 },
        leftRect: EMPTY_AVOID_RECT,
        rightRect: { left: 2352, top: 0, width: 48, height: 1080 }
      };

      const insets: WindowAvoidInsets = safeAreaInsetsFromAvoidAreas(
        2400, 1080, [systemArea, cutoutArea, navigationArea]);

      expect(insets.left).assertEqual(32);
      expect(insets.top).assertEqual(60);
      expect(insets.right).assertEqual(48);
      expect(insets.bottom).assertEqual(98);
    });

    it('takes the maximum overlapping edge and ignores empty rectangles', 0, () => {
      const systemArea: WindowAvoidAreaRects = {
        topRect: { left: 0, top: 12, width: 1080, height: 48 },
        bottomRect: EMPTY_AVOID_RECT,
        leftRect: EMPTY_AVOID_RECT,
        rightRect: EMPTY_AVOID_RECT
      };
      const cutoutArea: WindowAvoidAreaRects = {
        topRect: { left: 0, top: 0, width: 1080, height: 44 },
        bottomRect: EMPTY_AVOID_RECT,
        leftRect: EMPTY_AVOID_RECT,
        rightRect: EMPTY_AVOID_RECT
      };
      const insets: WindowAvoidInsets = safeAreaInsetsFromAvoidAreas(
        1080, 2400, [systemArea, cutoutArea]);

      expect(insets.top).assertEqual(60);
      expect(insets.left).assertEqual(0);
      expect(insets.right).assertEqual(0);
      expect(insets.bottom).assertEqual(0);
    });
  });
}
