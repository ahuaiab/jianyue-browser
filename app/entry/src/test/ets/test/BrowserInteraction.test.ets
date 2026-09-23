import { describe, expect, it } from '@ohos/hypium';
import {
  addressBarPresentationForInput,
  AddressBarPresentationMode,
  addressClearButtonVisibleFor,
  addressEditorDraftFor,
  addressLockImageVerticalOffsetFor,
  addressLockVerticalOffsetFor,
  addressTextAlignmentFor,
  isOverviewSettled,
  overviewScaleAtProgress,
  shouldDeferTabOverviewSnapshotRevision,
  shouldUpdateTransitionSystemBar
} from '../../../main/ets/browser/model/BrowserInteraction';
import {
  addressBarLabelFor,
  searchQueryForUrl,
  searchQueryTextFor
} from '../../../main/ets/browser/model/BrowserTypes';

export default function browserInteractionTest() {
  describe('BrowserInteraction', () => {
    it('keeps a partially revealed overview in the settling phase', 0, () => {
      expect(isOverviewSettled(0)).assertFalse();
      expect(isOverviewSettled(0.64)).assertFalse();
      expect(isOverviewSettled(1)).assertTrue();
    });

    it('uses the native overview entry scale before settling', 0, () => {
      expect(overviewScaleAtProgress(0, 0.92)).assertEqual(0.92);
      expect(overviewScaleAtProgress(0.5, 0.92)).assertEqual(0.96);
      expect(overviewScaleAtProgress(1, 0.92)).assertEqual(1);
    });

    it('updates the transition system bar only when its requested state changes', 0, () => {
      expect(shouldUpdateTransitionSystemBar(false, true)).assertTrue();
      expect(shouldUpdateTransitionSystemBar(true, true)).assertFalse();
      expect(shouldUpdateTransitionSystemBar(true, false)).assertTrue();
      expect(shouldUpdateTransitionSystemBar(false, false)).assertFalse();
    });

    it('defers snapshot revisions while the overview transition is mounted', 0, () => {
      expect(shouldDeferTabOverviewSnapshotRevision(0, false, false)).assertFalse();
      expect(shouldDeferTabOverviewSnapshotRevision(0.01, false, false)).assertTrue();
      expect(shouldDeferTabOverviewSnapshotRevision(0, true, false)).assertTrue();
      expect(shouldDeferTabOverviewSnapshotRevision(0, false, true)).assertTrue();
    });

    it('restores the search query instead of exposing the search result URL', 0, () => {
      const mode: AddressBarPresentationMode = addressBarPresentationForInput('鸿蒙浏览器');
      expect(mode).assertEqual(AddressBarPresentationMode.SEARCH);
      expect(addressEditorDraftFor(
        'https://cn.bing.com/search?q=%E9%B8%BF%E8%92%99%E6%B5%8F%E8%A7%88%E5%99%A8',
        mode,
        '鸿蒙浏览器'
      )).assertEqual('鸿蒙浏览器');
    });

    it('keeps an explicitly entered URL editable as the real URL', 0, () => {
      const mode: AddressBarPresentationMode = addressBarPresentationForInput('https://example.com/path');
      expect(mode).assertEqual(AddressBarPresentationMode.URL);
      expect(addressEditorDraftFor('https://example.com/path', mode, '')).assertEqual(
        'https://example.com/path'
      );
    });

    it('uses a shortened host in the collapsed address bar for direct URLs', 0, () => {
      expect(addressBarLabelFor('https://example.com/path?query=1', 'Example Domain'))
        .assertEqual('example.com');
    });

    it('uses the saved bookmark label in the collapsed address bar', 0, () => {
      expect(addressBarLabelFor(
        'https://example.com/path?query=1',
        'Example Domain',
        '我的书签'
      )).assertEqual('我的书签');
      expect(addressBarLabelFor(
        'https://example.com/path?query=1',
        'Example Domain',
        '  '
      )).assertEqual('example.com');
    });

    it('left aligns the active editor and centers the collapsed address label', 0, () => {
      expect(addressTextAlignmentFor(true)).assertEqual('start');
      expect(addressTextAlignmentFor(false)).assertEqual('center');
    });

    it('shows the address clear button only while the editor has focus', 0, () => {
      expect(addressClearButtonVisibleFor(true, true, true)).assertTrue();
      expect(addressClearButtonVisibleFor(true, true, false)).assertFalse();
      expect(addressClearButtonVisibleFor(false, true, true)).assertFalse();
      expect(addressClearButtonVisibleFor(true, false, true)).assertFalse();
    });

    it('centers the security button inside the address capsule', 0, () => {
      expect(addressLockVerticalOffsetFor(44, 32)).assertEqual(6);
      expect(addressLockVerticalOffsetFor(44, 20)).assertEqual(12);
    });

    it('centers the security image inside its button content box', 0, () => {
      expect(addressLockImageVerticalOffsetFor(32, 20)).assertEqual(6);
    });

    it('does not expose matching outer quotes in a restored search term', 0, () => {
      expect(searchQueryTextFor('\"鸿蒙浏览器\"')).assertEqual('鸿蒙浏览器');
      expect(searchQueryTextFor('“鸿蒙浏览器”')).assertEqual('鸿蒙浏览器');
      expect(searchQueryTextFor('鸿蒙“浏览器”')).assertEqual('鸿蒙“浏览器”');
      const searchUrl: string = 'https://cn.bing.com/search?q=%E9%B8%BF%E8%92%99%E6%B5%8F%E8%A7%88%E5%99%A8';
      expect(searchQueryForUrl(searchUrl)).assertEqual('鸿蒙浏览器');
      expect(addressBarLabelFor(searchUrl, '鸿蒙浏览器 - 搜索')).assertEqual('鸿蒙浏览器');
    });
  });
}
