import { describe, expect, it } from '@ohos/hypium';
import {
  tabGestureMotion,
  TabPreviewKind
} from '../../../main/ets/browser/model/TabGestureMotion';

export default function tabGestureMotionTest() {
  describe('TabGestureMotion', () => {
    it('keeps the first page fixed while the leading-edge address capsule resists', 0, () => {
      const motion = tabGestureMotion(80, 400, 0, 1);

      expect(motion.rawDragX).assertEqual(80);
      expect(motion.displayDragX > 0).assertTrue();
      expect(motion.displayDragX < motion.rawDragX).assertTrue();
      expect(motion.pageTranslateX).assertEqual(0);
      expect(motion.adjacentTranslateX).assertEqual(0);
      expect(motion.previewKind).assertEqual(TabPreviewKind.NONE);
      expect(motion.previewIndex).assertEqual(-1);
    });

    it('keeps an existing adjacent target paired with the current page', 0, () => {
      const motion = tabGestureMotion(-80, 400, 0, 2);

      expect(motion.displayDragX).assertEqual(-80);
      expect(motion.pageTranslateX).assertEqual(-80);
      expect(motion.adjacentTranslateX).assertEqual(320);
      expect(motion.previewKind).assertEqual(TabPreviewKind.EXISTING_TAB);
      expect(motion.previewIndex).assertEqual(1);
    });

    it('uses a real pending target after the final tab', 0, () => {
      const motion = tabGestureMotion(-80, 400, 0, 1);

      expect(motion.pageTranslateX).assertEqual(-80);
      expect(motion.adjacentTranslateX).assertEqual(320);
      expect(motion.previewKind).assertEqual(TabPreviewKind.NEW_TAB);
      expect(motion.previewIndex).assertEqual(-1);
    });
  });
}
