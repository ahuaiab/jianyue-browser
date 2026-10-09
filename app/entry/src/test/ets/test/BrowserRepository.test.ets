import { describe, expect, it } from '@ohos/hypium';
import {
  BookmarkRecord,
  BookmarkFolderRecord,
  BrowserSessionSnapshot,
  HistoryRecord,
  TabResidency
} from '../../../main/ets/browser/model/BrowserTypes';
import { BrowserRepository } from '../../../main/ets/browser/data/BrowserRepository';
import { KeyValueStore } from '../../../main/ets/browser/data/KeyValueStore';

class FakeKeyValueStore implements KeyValueStore {
  private readonly values: Map<string, string>;

  constructor(initial: Map<string, string> = new Map()) {
    this.values = initial;
  }

  async getString(key: string, fallback: string): Promise<string> {
    return this.values.get(key) ?? fallback;
  }

  async putString(key: string, value: string): Promise<void> {
    this.values.set(key, value);
  }

  async flush(): Promise<void> {}

  allValues(): string[] {
    return Array.from(this.values.values());
  }
}

class ExitRaceKeyValueStore implements KeyValueStore {
  private readonly values: Map<string, string> = new Map();
  private activeReadStarted: boolean = false;
  private activeReadDelayed: boolean = false;

  async getString(key: string, fallback: string): Promise<string> {
    if (key === 'session.active' && !this.activeReadDelayed) {
      this.activeReadDelayed = true;
      this.activeReadStarted = true;
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, 0));
    }
    return this.values.get(key) ?? fallback;
  }

  async putString(key: string, value: string): Promise<void> {
    this.values.set(key, value);
  }

  async flush(): Promise<void> {}

  async waitForActiveRead(): Promise<void> {
    while (!this.activeReadStarted) {
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, 0));
    }
  }
}

function normalSession(): BrowserSessionSnapshot {
  return {
    version: 1,
    activeTabId: 'normal',
    tabs: [{
      id: 'normal',
      url: 'https://normal.example',
      lastValidUrl: 'https://normal.example',
      displayUrl: 'normal.example',
      pageSnapshot: '',
      title: 'Normal',
      isPrivate: false,
      createdAt: 1,
      lastAccessedAt: 1,
      thumbnailKey: '',
      residency: TabResidency.COLD
    }]
  };
}

export default function browserRepositoryTest() {
  describe('BrowserRepository', () => {
    it('falls back to the previous complete session slot', 0, async () => {
      const valid: BrowserSessionSnapshot = normalSession();
      const store: FakeKeyValueStore = new FakeKeyValueStore(new Map([
        ['session.active', 'b'],
        ['session.a', JSON.stringify(valid)],
        ['session.b', '{broken']
      ]));
      const repository: BrowserRepository = new BrowserRepository(store);
      const session: BrowserSessionSnapshot | undefined = await repository.loadSession();
      expect(session?.tabs.length).assertEqual(1);
      expect(session?.activeTabId).assertEqual('normal');
    });

    it('clears both persisted session slots for browser exit', 0, async () => {
      const store: FakeKeyValueStore = new FakeKeyValueStore();
      const repository: BrowserRepository = new BrowserRepository(store);
      await repository.saveSession(normalSession());
      await repository.clearSession();
      expect(await repository.loadSession()).assertUndefined();
      expect(store.allValues().join('').includes('https://normal.example')).assertFalse();
    });

    it('does not restore tabs saved by a previous app process', 0, async () => {
      const repository: BrowserRepository = new BrowserRepository(new FakeKeyValueStore());
      await repository.saveSession(normalSession());

      await repository.clearSessionForColdStart();

      expect(await repository.loadSession()).assertUndefined();
    });

    it('serializes an exit clear after an in-flight session save', 0, async () => {
      const store: ExitRaceKeyValueStore = new ExitRaceKeyValueStore();
      const repository: BrowserRepository = new BrowserRepository(store);
      const savePromise: Promise<void> = repository.saveSession(normalSession());
      await store.waitForActiveRead();
      await repository.clearSession();
      await savePromise;
      expect(await repository.loadSession()).assertUndefined();
    });

    it('does not persist private tabs or private history', 0, async () => {
      const store: FakeKeyValueStore = new FakeKeyValueStore();
      const repository: BrowserRepository = new BrowserRepository(store);
      const privateSession: BrowserSessionSnapshot = {
        version: 1,
        activeTabId: 'private',
        tabs: [{
          id: 'private',
          url: 'https://private.example',
          lastValidUrl: 'https://private.example',
          displayUrl: 'private.example',
          pageSnapshot: '',
          title: 'Private',
          isPrivate: true,
          createdAt: 1,
          lastAccessedAt: 1,
          thumbnailKey: '',
          residency: TabResidency.COLD
        }]
      };
      const history: HistoryRecord = {
        url: 'https://private.example',
        title: 'Private',
        visitedAt: 1
      };
      await repository.saveSession(privateSession);
      await repository.recordHistory(history, true);
      expect(store.allValues().join('').includes('https://private.example')).assertFalse();
    });

    it('keeps history newest-first, collapses consecutive URLs and bounds it', 0, async () => {
      const repository: BrowserRepository = new BrowserRepository(new FakeKeyValueStore());
      await repository.recordHistory({ url: 'https://same.example', title: 'old', visitedAt: 1 }, false);
      await repository.recordHistory({ url: 'https://same.example', title: 'new', visitedAt: 2 }, false);
      const collapsed: HistoryRecord[] = await repository.listHistory();
      expect(collapsed.length).assertEqual(1);
      expect(collapsed[0].title).assertEqual('new');
      for (let index: number = 0; index < 2001; index += 1) {
        await repository.recordHistory({
          url: `https://host-${index}.example`,
          title: `${index}`,
          visitedAt: index + 3
        }, false);
      }
      const bounded: HistoryRecord[] = await repository.listHistory();
      expect(bounded.length).assertEqual(2000);
      expect(bounded[0].url).assertEqual('https://host-2000.example');
    });

    it('removes only the selected history record when a URL appears again later', 0, async () => {
      const repository: BrowserRepository = new BrowserRepository(new FakeKeyValueStore());
      const first: HistoryRecord = {
        url: 'https://repeat.example',
        title: 'First visit',
        visitedAt: 1
      };
      const middle: HistoryRecord = {
        url: 'https://middle.example',
        title: 'Middle visit',
        visitedAt: 2
      };
      const second: HistoryRecord = {
        url: 'https://repeat.example',
        title: 'Second visit',
        visitedAt: 3
      };
      await repository.recordHistory(first, false);
      await repository.recordHistory(middle, false);
      await repository.recordHistory(second, false);

      await repository.removeHistoryEntry({
        url: first.url,
        title: 'Updated display title',
        visitedAt: first.visitedAt
      });

      const history: HistoryRecord[] = await repository.listHistory();
      expect(history.length).assertEqual(2);
      expect(history.some((record: HistoryRecord) => record.title === 'First visit')).assertFalse();
      expect(history.some((record: HistoryRecord) => record.title === 'Second visit')).assertTrue();
      expect(history.some((record: HistoryRecord) => record.title === 'Middle visit')).assertTrue();
    });

    it('serializes history recording after an in-flight single-record deletion', 0, async () => {
      const repository: BrowserRepository = new BrowserRepository(new FakeKeyValueStore());
      const oldRecord: HistoryRecord = {
        url: 'https://old.example',
        title: 'Old',
        visitedAt: 1
      };
      await repository.recordHistory(oldRecord, false);

      const removePromise: Promise<void> = repository.removeHistoryEntry(oldRecord);
      const recordPromise: Promise<void> = repository.recordHistory({
        url: 'https://new.example',
        title: 'New',
        visitedAt: 2
      }, false);
      await Promise.all([removePromise, recordPromise]);

      const history: HistoryRecord[] = await repository.listHistory();
      expect(history.length).assertEqual(1);
      expect(history[0].url).assertEqual('https://new.example');
    });

    it('deletes history before, from, and across an empty collection idempotently', 0, async () => {
      const store: FakeKeyValueStore = new FakeKeyValueStore();
      const repository: BrowserRepository = new BrowserRepository(store);
      await repository.recordHistory({ url: 'https://new.example', title: 'New', visitedAt: 30 }, false);
      await repository.recordHistory({ url: 'https://middle.example', title: 'Middle', visitedAt: 20 }, false);
      await repository.recordHistory({ url: 'https://old.example', title: 'Old', visitedAt: 10 }, false);

      await repository.removeHistoryBefore(20);
      let history: HistoryRecord[] = await repository.listHistory();
      expect(history.length).assertEqual(2);
      expect(history.some((record: HistoryRecord) => record.url === 'https://old.example')).assertFalse();

      await repository.removeHistoryFrom(30);
      history = await repository.listHistory();
      expect(history.length).assertEqual(1);
      expect(history[0].url).assertEqual('https://middle.example');

      await repository.removeHistoryFrom(30);
      await repository.clearHistory();
      await repository.clearHistory();
      expect((await repository.listHistory()).length).assertEqual(0);
    });

    it('deduplicates bookmarks while preserving insertion order', 0, async () => {
      const repository: BrowserRepository = new BrowserRepository(new FakeKeyValueStore());
      const first: BookmarkRecord = { url: 'https://a.example', title: 'A', createdAt: 1 };
      const second: BookmarkRecord = { url: 'https://b.example', title: 'B', createdAt: 2 };
      await repository.addBookmark(first);
      await repository.addBookmark(first);
      await repository.addBookmark(second);
      let bookmarks: BookmarkRecord[] = await repository.listBookmarks();
      expect(bookmarks.length).assertEqual(2);
      expect(bookmarks[0].url).assertEqual('https://a.example');
      await repository.removeBookmark(first.url);
      bookmarks = await repository.listBookmarks();
      expect(bookmarks.length).assertEqual(1);
      expect(bookmarks[0].url).assertEqual('https://b.example');
    });

    it('updates a saved bookmark in place and persists its title URL and original creation time', 0, async () => {
      const store: FakeKeyValueStore = new FakeKeyValueStore();
      const repository: BrowserRepository = new BrowserRepository(store);
      await repository.addBookmark({ url: 'https://first.example', title: 'First', createdAt: 1 });
      await repository.addBookmark({ url: 'https://edit.example', title: 'Old', createdAt: 2 });
      await repository.addBookmark({ url: 'https://last.example', title: 'Last', createdAt: 3 });

      expect(await repository.updateBookmark('https://edit.example', '  New name  ', ' https://new.example/page ')).assertTrue();
      const saved: BookmarkRecord[] = await new BrowserRepository(store).listBookmarks();
      expect(saved.length).assertEqual(3);
      expect(saved[0].url).assertEqual('https://first.example');
      expect(saved[1].url).assertEqual('https://new.example/page');
      expect(saved[1].title).assertEqual('New name');
      expect(saved[1].createdAt).assertEqual(2);
      expect(saved[2].url).assertEqual('https://last.example');
      expect(await repository.updateBookmark('https://new.example/page', ' ', 'https://new.example/page')).assertTrue();
      expect((await repository.listBookmarks())[1].title).assertEqual('https://new.example/page');
    });

    it('rejects invalid edits without losing existing bookmarks', 0, async () => {
      const store: FakeKeyValueStore = new FakeKeyValueStore();
      const repository: BrowserRepository = new BrowserRepository(store);
      await repository.addBookmark({ url: 'https://edit.example', title: 'Edit', createdAt: 1 });
      await repository.addBookmark({ url: 'https://keep.example', title: 'Keep', createdAt: 2 });
      const before: string = store.allValues().join('');
      expect(await repository.updateBookmark('https://edit.example', 'Bad', 'https://keep.example')).assertFalse();
      expect(await repository.updateBookmark('https://edit.example', 'Bad', '')).assertFalse();
      expect(await repository.updateBookmark('https://edit.example', 'Bad', 'about:blank')).assertFalse();
      expect(await repository.updateBookmark('https://edit.example', 'Bad', 'javascript:alert(1)')).assertFalse();
      expect(await repository.updateBookmark('https://missing.example', 'Bad', 'https://new.example')).assertFalse();
      expect(store.allValues().join('')).assertEqual(before);
      expect((await repository.listBookmarks()).length).assertEqual(2);
    });

    it('keeps legacy bookmarks in the default folder and preserves an assigned folder', 0, async () => {
      const store: FakeKeyValueStore = new FakeKeyValueStore(new Map([
        ['bookmarks.v1', JSON.stringify([
          { url: 'https://legacy.example', title: 'Legacy', createdAt: 1 }
        ])]
      ]));
      const repository: BrowserRepository = new BrowserRepository(store);
      const folder: BookmarkFolderRecord | undefined = await repository.createBookmarkFolder('Reading');
      expect(folder === undefined).assertFalse();
      await repository.addBookmark({
        url: 'https://folder.example',
        title: 'Folder item',
        createdAt: 2,
        folderId: folder?.id
      });

      const saved: BookmarkRecord[] = await new BrowserRepository(store).listBookmarks();
      expect(saved.length).assertEqual(2);
      expect(saved[0].folderId).assertUndefined();
      expect(saved[1].folderId).assertEqual(folder?.id);
    });

    it('trims and persists folder names while rejecting invalid and duplicate names under concurrent creation', 0, async () => {
      const store: FakeKeyValueStore = new FakeKeyValueStore();
      const repository: BrowserRepository = new BrowserRepository(store);
      const results: Array<BookmarkFolderRecord | undefined> = await Promise.all([
        repository.createBookmarkFolder('  Reading  '),
        repository.createBookmarkFolder('Reading'),
        repository.createBookmarkFolder('Archive')
      ]);
      expect(results[0] === undefined).assertFalse();
      expect(results[1]).assertUndefined();
      expect(results[2] === undefined).assertFalse();
      expect(await repository.createBookmarkFolder('   ')).assertUndefined();
      expect(await repository.createBookmarkFolder('书签')).assertUndefined();
      expect(await repository.createBookmarkFolder('x'.repeat(61))).assertUndefined();

      const folders: BookmarkFolderRecord[] = await repository.listBookmarkFolders();
      expect(folders.length).assertEqual(2);
      expect(folders[0].name).assertEqual('Reading');
      expect(folders[1].name).assertEqual('Archive');
      expect(folders[0].id.length > 0).assertTrue();
      expect(folders[0].id === folders[1].id).assertFalse();
      const restored: BookmarkFolderRecord[] = await new BrowserRepository(store).listBookmarkFolders();
      expect(restored.length).assertEqual(2);
      expect(restored[0].id).assertEqual(folders[0].id);
      expect(restored[1].name).assertEqual('Archive');
    });

    it('preserves bookmark folders on edits, moves explicitly, and rejects unknown folders without writes', 0, async () => {
      const store: FakeKeyValueStore = new FakeKeyValueStore();
      const repository: BrowserRepository = new BrowserRepository(store);
      const reading: BookmarkFolderRecord | undefined = await repository.createBookmarkFolder('Reading');
      const archive: BookmarkFolderRecord | undefined = await repository.createBookmarkFolder('Archive');
      expect(reading === undefined).assertFalse();
      expect(archive === undefined).assertFalse();
      await repository.addBookmark({
        url: 'https://edit.example', title: 'Old', createdAt: 7, folderId: reading?.id
      });

      expect(await repository.updateBookmark('https://edit.example', ' Renamed ', 'https://renamed.example')).assertTrue();
      let saved: BookmarkRecord[] = await repository.listBookmarks();
      expect(saved[0].folderId).assertEqual(reading?.id);
      expect(saved[0].title).assertEqual('Renamed');
      expect(saved[0].createdAt).assertEqual(7);

      expect(await repository.updateBookmark('https://renamed.example', 'Moved', 'https://moved.example', archive?.id)).assertTrue();
      saved = await new BrowserRepository(store).listBookmarks();
      expect(saved[0].folderId).assertEqual(archive?.id);
      expect(saved[0].url).assertEqual('https://moved.example');
      expect(await repository.updateBookmark('https://moved.example', 'Root', 'https://root.example', '')).assertTrue();
      saved = await repository.listBookmarks();
      expect(saved[0].folderId).assertUndefined();

      const before: string = store.allValues().join('');
      expect(await repository.updateBookmark('https://root.example', 'Invalid', 'https://bad-folder.example', 'missing-folder')).assertFalse();
      expect(store.allValues().join('')).assertEqual(before);
    });

    it('skips malformed bookmark folder rows without failing the folder list', 0, async () => {
      const store: FakeKeyValueStore = new FakeKeyValueStore(new Map([
        ['bookmark-folders.v1', JSON.stringify([
          { id: 'valid', name: 'Reading', createdAt: 1 },
          null,
          { id: '', name: 'No ID', createdAt: 2 },
          { id: 'duplicate', name: '  Reading  ', createdAt: 3 },
          { id: 'root', name: '书签', createdAt: 4 }
        ])]
      ]));
      const folders: BookmarkFolderRecord[] = await new BrowserRepository(store).listBookmarkFolders();
      expect(folders.length).assertEqual(1);
      expect(folders[0].id).assertEqual('valid');
      expect(folders[0].name).assertEqual('Reading');
    });

    it('discards malformed rows instead of failing the collection', 0, async () => {
      const store: FakeKeyValueStore = new FakeKeyValueStore(new Map([
        ['history.v1', JSON.stringify([
          { url: 'https://valid.example', title: 'valid', visitedAt: 1 },
          { url: '', title: 'invalid', visitedAt: 2 },
          { url: 'https://bad-time.example', title: 'invalid', visitedAt: 'bad' }
        ])],
        ['bookmarks.v1', JSON.stringify([
          { url: 'https://bookmark.example', title: 'valid', createdAt: 3 },
          { url: 'https://bad.example', title: 'invalid', createdAt: null }
        ])]
      ]));
      const repository: BrowserRepository = new BrowserRepository(store);
      expect((await repository.listHistory()).length).assertEqual(1);
      expect((await repository.listBookmarks()).length).assertEqual(1);
    });
  });
}
