import { describe, expect, it } from '@ohos/hypium';
import { BookmarkRecord } from '../../../main/ets/browser/model/BrowserTypes';
import {
  mergeBookmarkedStartPageItems,
  StartPageItem,
  StartPageItemType,
  startPageContentSurfaceColor,
  startPageUsesImmersiveSurface,
  startPageItemNavigationTitle
} from '../../../main/ets/browser/model/StartPageModels';
import {
  SAFARI_BOTTOM_CHROME_FALLBACK_COLOR,
  SAFARI_BOTTOM_CHROME_MATERIAL_BASE_COLOR,
  SAFARI_BOTTOM_CHROME_MATERIAL_COLOR
} from '../../../main/ets/browser/model/BrowserVisualMetrics';

export default function startPageBookmarksTest() {
  describe('StartPageBookmarks', () => {
    it('merges existing bookmarks into start-page items', 0, () => {
      const bookmarks: BookmarkRecord[] = [
        { url: 'https://a.example', title: 'A', createdAt: 10 },
        { url: 'https://b.example', title: 'B', createdAt: 20 }
      ];

      const merged: StartPageItem[] = mergeBookmarkedStartPageItems([], bookmarks);

      expect(merged.length).assertEqual(2);
      expect(merged[0].type).assertEqual(StartPageItemType.FAVORITE);
      expect(merged[0].url).assertEqual('https://a.example');
      expect(merged[1].url).assertEqual('https://b.example');
    });

    it('preserves the user-defined bookmark order while appending new bookmarks', 0, () => {
      const bookmarks: BookmarkRecord[] = [
        { url: 'https://a.example', title: 'A updated', createdAt: 30 },
        { url: 'https://b.example', title: 'B', createdAt: 20 },
        { url: 'https://c.example', title: 'C', createdAt: 10 }
      ];
      const existing: StartPageItem[] = [
        {
          id: 'bookmark-b',
          type: StartPageItemType.FAVORITE,
          title: 'B',
          url: 'https://b.example',
          order: 0,
          updatedAt: 20
        },
        {
          id: 'bookmark-a',
          type: StartPageItemType.FAVORITE,
          title: 'A',
          url: 'https://a.example',
          order: 1,
          updatedAt: 10
        }
      ];

      const merged: StartPageItem[] = mergeBookmarkedStartPageItems(existing, bookmarks);

      expect(merged[0].url).assertEqual('https://b.example');
      expect(merged[1].url).assertEqual('https://a.example');
      expect(merged[2].url).assertEqual('https://c.example');
      expect(merged[1].title).assertEqual('A updated');
      expect(merged[0].order).assertEqual(0);
      expect(merged[1].order).assertEqual(1);
      expect(merged[2].order).assertEqual(2);
    });

    it('removes stale bookmark entries from the start-page projection', 0, () => {
      const existing: StartPageItem[] = [{
        id: 'bookmark-removed',
        type: StartPageItemType.FAVORITE,
        title: 'Removed',
        url: 'https://removed.example',
        order: 0,
        updatedAt: 1
      }];

      const merged: StartPageItem[] = mergeBookmarkedStartPageItems(existing, []);

      expect(merged.length).assertEqual(0);
    });

    it('uses the bookmark title as the initial navigation title', 0, () => {
      const item: StartPageItem = {
        id: 'bookmark-example',
        type: StartPageItemType.FAVORITE,
        title: 'Example Domain',
        url: 'https://example.com',
        order: 0,
        updatedAt: 1
      };

      expect(startPageItemNavigationTitle(item)).assertEqual('Example Domain');
      expect(startPageItemNavigationTitle({
        id: 'bookmark-empty-title',
        type: StartPageItemType.FAVORITE,
        title: '  ',
        url: 'https://fallback.example',
        order: 0,
        updatedAt: 1
      })).assertEqual('https://fallback.example');
    });

    it('uses a light content surface over a custom background', 0, () => {
      expect(startPageContentSurfaceColor('system-gradient')).assertEqual('#00000000');
      expect(startPageContentSurfaceColor('background-image-1'))
        .assertEqual(SAFARI_BOTTOM_CHROME_MATERIAL_COLOR);
      expect(startPageContentSurfaceColor('background-image-1', true))
        .assertEqual(SAFARI_BOTTOM_CHROME_MATERIAL_BASE_COLOR);
      expect(SAFARI_BOTTOM_CHROME_MATERIAL_COLOR).assertEqual('#FFF2F2F7');
      expect(SAFARI_BOTTOM_CHROME_FALLBACK_COLOR).assertEqual(SAFARI_BOTTOM_CHROME_MATERIAL_COLOR);
      expect(startPageUsesImmersiveSurface('system-gradient')).assertFalse();
      expect(startPageUsesImmersiveSurface('background-image-1')).assertTrue();
    });
  });
}
