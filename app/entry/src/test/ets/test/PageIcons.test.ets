import { describe, expect, it } from '@ohos/hypium';
import { BrowserRepository } from '../../../main/ets/browser/data/BrowserRepository';
import { KeyValueStore } from '../../../main/ets/browser/data/KeyValueStore';
import {
  historyTimelineGroups,
  libraryEntries,
  LibrarySection
} from '../../../main/ets/browser/model/LibraryModels';
import {
  PageIconRecord,
  pageIconPathForUrl,
  upsertPageIconRecord,
  validPageIconRecord
} from '../../../main/ets/browser/model/PageIconModels';

class InMemoryPageIconStore implements KeyValueStore {
  private readonly values: Map<string, string> = new Map();

  async getString(key: string, fallback: string): Promise<string> {
    return this.values.get(key) ?? fallback;
  }

  async putString(key: string, value: string): Promise<void> {
    this.values.set(key, value);
  }

  async flush(): Promise<void> {
    return Promise.resolve();
  }
}

export default function pageIconsTest() {
  describe('PageIcons', () => {
    it('uses the persisted local icon path for the matching page URL', 0, () => {
      const records: PageIconRecord[] = [{
        url: 'https://example.com/path',
        localPath: '/data/storage/el2/base/files/page-icons/example.png',
        updatedAt: 10
      }];

      expect(pageIconPathForUrl(records, 'https://example.com/path'))
        .assertEqual('/data/storage/el2/base/files/page-icons/example.png');
      expect(pageIconPathForUrl(records, 'https://example.com/other?tab=1'))
        .assertEqual('/data/storage/el2/base/files/page-icons/example.png');
      expect(pageIconPathForUrl(records, 'https://other.example'))
        .assertUndefined();
    });

    it('replaces an existing page icon without duplicating the URL', 0, () => {
      const initial: PageIconRecord[] = [{
        url: 'https://example.com',
        localPath: '/old.png',
        updatedAt: 1
      }];

      const updated: PageIconRecord[] = upsertPageIconRecord(initial, {
        url: 'https://example.com',
        localPath: '/new.png',
        updatedAt: 2
      });

      expect(updated.length).assertEqual(1);
      expect(updated[0].localPath).assertEqual('/new.png');
      expect(updated[0].updatedAt).assertEqual(2);
    });

    it('rejects records without a local path so native fallback can render', 0, () => {
      expect(validPageIconRecord({
        url: 'https://example.com',
        localPath: '',
        updatedAt: 1
      })).assertFalse();
    });

    it('persists page icon paths independently from bookmarks and history', 0, async () => {
      const repository: BrowserRepository = new BrowserRepository(new InMemoryPageIconStore());
      await repository.savePageIcon({
        url: 'https://example.com',
        localPath: '/data/storage/el2/base/files/page-icons/example.png',
        updatedAt: 12
      });

      const restored: PageIconRecord[] = await repository.listPageIcons();
      expect(restored.length).assertEqual(1);
      expect(restored[0].localPath).assertEqual(
        '/data/storage/el2/base/files/page-icons/example.png'
      );
    });

    it('projects one persisted icon path into both library sections', 0, () => {
      const iconRecords: PageIconRecord[] = [{
        url: 'https://example.com',
        localPath: '/cached/example.png',
        updatedAt: 20
      }];
      const bookmarks = libraryEntries(LibrarySection.BOOKMARKS, [], [{
        url: 'https://example.com',
        title: 'Example',
        createdAt: 1
      }], iconRecords);
      const history = libraryEntries(LibrarySection.HISTORY, [{
        url: 'https://example.com',
        title: 'Example',
        visitedAt: 2
      }], [], iconRecords);

      expect(bookmarks[0].iconPath).assertEqual('/cached/example.png');
      expect(history[0].iconPath).assertEqual('/cached/example.png');

      const historyGroups = historyTimelineGroups([{
        url: 'https://example.com',
        title: 'Example',
        visitedAt: 2
      }], 3, iconRecords);
      expect(historyGroups[0].entries[0].iconPath).assertEqual('/cached/example.png');
    });
  });
}
