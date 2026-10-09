import {
  BookmarkRecord,
  BookmarkFolderRecord,
  BrowserSessionSnapshot,
  BrowserTabRecord,
  displayUrlFor,
  HistoryRecord,
  lastValidUrlForTab,
  loadableUrlFor,
  TabResidency
} from '../model/BrowserTypes';
import {
  BrowserSettings,
  copyBrowserSettings,
  DEFAULT_BROWSER_SETTINGS,
  normalizeBrowserSettings
} from '../model/BrowserSettings';
import { sortStartPageItems, StartPageItem, validStartPageItem } from '../model/StartPageModels';
import {
  copyPageIconRecord,
  PageIconRecord,
  upsertPageIconRecord,
  validPageIconRecord
} from '../model/PageIconModels';
import { ClosedTabRecord } from './ClosedTabStack';
import { KeyValueStore } from './KeyValueStore';
import { normalizeSiteSearchTemplates, SiteSearchTemplate, upsertSiteSearchTemplate } from '../model/SiteSearchModels';

const ACTIVE_SLOT_KEY: string = 'session.active';
const SLOT_A_KEY: string = 'session.a';
const SLOT_B_KEY: string = 'session.b';
const HISTORY_KEY: string = 'history.v1';
const BOOKMARKS_KEY: string = 'bookmarks.v1';
const BOOKMARK_FOLDERS_KEY: string = 'bookmark-folders.v1';
const SETTINGS_KEY: string = 'browser.settings.v1';
const START_PAGE_KEY: string = 'start.page.items.v1';
const PAGE_ICONS_KEY: string = 'page.icons.v1';
const CLOSED_TABS_KEY: string = 'closed.tabs.v1';
const SITE_SEARCH_TEMPLATES_KEY: string = 'site.search.templates.v1';
const MAX_HISTORY: number = 2000;
const MAX_PAGE_ICONS: number = 256;
const MAX_CLOSED_TABS: number = 20;
const MAX_BOOKMARK_FOLDER_NAME_LENGTH: number = 60;

export class BrowserRepository {
  private readonly store: KeyValueStore;
  private siteSearchOperation: Promise<void> = Promise.resolve();
  private sessionOperation: Promise<void> = Promise.resolve();
  private historyOperation: Promise<void> = Promise.resolve();
  private pageIconOperation: Promise<void> = Promise.resolve();
  private bookmarkFolderOperation: Promise<void> = Promise.resolve();
  private nextBookmarkFolderId: number = 0;

  constructor(store: KeyValueStore) {
    this.store = store;
  }

  async loadSession(): Promise<BrowserSessionSnapshot | undefined> {
    const active: string = await this.store.getString(ACTIVE_SLOT_KEY, 'a');
    const firstKey: string = active === 'b' ? SLOT_B_KEY : SLOT_A_KEY;
    const secondKey: string = firstKey === SLOT_A_KEY ? SLOT_B_KEY : SLOT_A_KEY;
    const first: BrowserSessionSnapshot | undefined = this.parseSession(
      await this.store.getString(firstKey, '')
    );
    if (first !== undefined) {
      return first;
    }
    return this.parseSession(await this.store.getString(secondKey, ''));
  }

  async saveSession(snapshot: BrowserSessionSnapshot): Promise<void> {
    await this.enqueueSessionOperation(async (): Promise<void> => {
      const tabs: BrowserTabRecord[] = snapshot.tabs
        .filter((tab: BrowserTabRecord) => !tab.isPrivate)
        .map((tab: BrowserTabRecord) => this.copyTab(tab));
      if (tabs.length === 0) {
        return;
      }
      const activeTabId: string = tabs.some((tab: BrowserTabRecord) => tab.id === snapshot.activeTabId)
        ? snapshot.activeTabId
        : tabs[0].id;
      const safeSnapshot: BrowserSessionSnapshot = {
        version: 1,
        activeTabId,
        tabs
      };
      const active: string = await this.store.getString(ACTIVE_SLOT_KEY, 'a');
      const targetKey: string = active === 'b' ? SLOT_A_KEY : SLOT_B_KEY;
      const targetMarker: string = targetKey === SLOT_A_KEY ? 'a' : 'b';
      await this.store.putString(targetKey, JSON.stringify(safeSnapshot));
      await this.store.flush();
      await this.store.putString(ACTIVE_SLOT_KEY, targetMarker);
      await this.store.flush();
    });
  }

  /** Clear both session slots so a destroyed browser window cannot restore old tabs. */
  async clearSession(): Promise<void> {
    await this.enqueueSessionOperation(async (): Promise<void> => {
      await this.store.putString(SLOT_A_KEY, '');
      await this.store.putString(SLOT_B_KEY, '');
      await this.store.putString(ACTIVE_SLOT_KEY, 'a');
      await this.store.flush();
    });
  }

  /**
   * A new app process starts with no open tabs. Returning from background does
   * not call this method, so the live in-memory session remains untouched.
   */
  async clearSessionForColdStart(): Promise<void> {
    await this.clearSession();
  }

  /** Serialize save and exit-clear writes so a late save cannot restore a closed session. */
  private enqueueSessionOperation(operation: () => Promise<void>): Promise<void> {
    const next: Promise<void> = this.sessionOperation.then(operation, operation);
    this.sessionOperation = next.then(() => undefined, () => undefined);
    return next;
  }

  /** Serialize history read-modify-write operations so deletion cannot be overwritten by a visit. */
  private enqueueHistoryOperation(operation: () => Promise<void>): Promise<void> {
    const next: Promise<void> = this.historyOperation.then(operation, operation);
    this.historyOperation = next.then(() => undefined, () => undefined);
    return next;
  }

  /** Serialize favicon cache read-modify-write operations from concurrent tabs. */
  private enqueuePageIconOperation(operation: () => Promise<void>): Promise<void> {
    const next: Promise<void> = this.pageIconOperation.then(operation, operation);
    this.pageIconOperation = next.then(() => undefined, () => undefined);
    return next;
  }

  /** Serialize folder creation so concurrent requests cannot overwrite one another. */
  private enqueueBookmarkFolderOperation(operation: () => Promise<void>): Promise<void> {
    const next: Promise<void> = this.bookmarkFolderOperation.then(operation, operation);
    this.bookmarkFolderOperation = next.then(() => undefined, () => undefined);
    return next;
  }

  async recordHistory(record: HistoryRecord, isPrivate: boolean): Promise<void> {
    if (isPrivate || !this.validHistory(record)) {
      return;
    }
    await this.enqueueHistoryOperation(async (): Promise<void> => {
      const history: HistoryRecord[] = await this.listHistory();
      const latest: HistoryRecord | undefined = history[0];
      if (latest !== undefined && latest.url === record.url) {
        history[0] = this.copyHistory(record);
      } else {
        history.unshift(this.copyHistory(record));
      }
      const bounded: HistoryRecord[] = history.slice(0, MAX_HISTORY);
      await this.writeJson(HISTORY_KEY, bounded);
    });
  }

  async listHistory(): Promise<HistoryRecord[]> {
    const raw: string = await this.store.getString(HISTORY_KEY, '[]');
    try {
      const parsed: HistoryRecord[] = JSON.parse(raw) as HistoryRecord[];
      if (!Array.isArray(parsed)) {
        return [];
      }
      return parsed
        .filter((record: HistoryRecord) => this.validHistory(record))
        .map((record: HistoryRecord) => this.copyHistory(record))
        .slice(0, MAX_HISTORY);
    } catch (_error) {
      return [];
    }
  }

  async removeHistory(url: string): Promise<void> {
    const target: string = url.trim();
    if (target.length === 0) {
      return;
    }
    await this.enqueueHistoryOperation(async (): Promise<void> => {
      const history: HistoryRecord[] = await this.listHistory();
      const remaining: HistoryRecord[] = history.filter((record: HistoryRecord) => record.url !== target);
      if (remaining.length !== history.length) {
        await this.writeJson(HISTORY_KEY, remaining);
      }
    });
  }

  /** Remove exactly the history row selected by the library UI. */
  async removeHistoryEntry(record: HistoryRecord): Promise<void> {
    if (!this.validHistory(record)) {
      return;
    }
    await this.enqueueHistoryOperation(async (): Promise<void> => {
      const history: HistoryRecord[] = await this.listHistory();
      let removed: boolean = false;
      const remaining: HistoryRecord[] = history.filter((candidate: HistoryRecord) => {
        const matches: boolean = !removed && candidate.url === record.url &&
          candidate.visitedAt === record.visitedAt;
        if (matches) {
          removed = true;
          return false;
        }
        return true;
      });
      if (removed) {
        await this.writeJson(HISTORY_KEY, remaining);
      }
    });
  }

  async removeHistoryBefore(cutoff: number): Promise<void> {
    if (!Number.isFinite(cutoff)) {
      return;
    }
    await this.enqueueHistoryOperation(async (): Promise<void> => {
      const history: HistoryRecord[] = await this.listHistory();
      const remaining: HistoryRecord[] = history.filter((record: HistoryRecord) => record.visitedAt >= cutoff);
      if (remaining.length !== history.length) {
        await this.writeJson(HISTORY_KEY, remaining);
      }
    });
  }

  /** Removes records at or after a local-calendar cutoff, used by batch menus. */
  async removeHistoryFrom(cutoff: number): Promise<void> {
    if (!Number.isFinite(cutoff)) {
      return;
    }
    await this.enqueueHistoryOperation(async (): Promise<void> => {
      const history: HistoryRecord[] = await this.listHistory();
      const remaining: HistoryRecord[] = history.filter((record: HistoryRecord) => record.visitedAt < cutoff);
      if (remaining.length !== history.length) {
        await this.writeJson(HISTORY_KEY, remaining);
      }
    });
  }

  async clearHistory(): Promise<void> {
    await this.enqueueHistoryOperation(async (): Promise<void> => {
      const history: HistoryRecord[] = await this.listHistory();
      if (history.length > 0) {
        await this.writeJson(HISTORY_KEY, []);
      }
    });
  }

  async addBookmark(record: BookmarkRecord, isPrivate: boolean = false): Promise<void> {
    if (isPrivate || !this.validBookmark(record)) {
      return;
    }
    const bookmarks: BookmarkRecord[] = await this.listBookmarks();
    if (bookmarks.some((item: BookmarkRecord) => item.url === record.url)) {
      return;
    }
    bookmarks.push(this.copyBookmark(record));
    await this.writeJson(BOOKMARKS_KEY, bookmarks);
  }

  async listBookmarkFolders(): Promise<BookmarkFolderRecord[]> {
    const raw: string = await this.store.getString(BOOKMARK_FOLDERS_KEY, '[]');
    try {
      const parsed: BookmarkFolderRecord[] = JSON.parse(raw) as BookmarkFolderRecord[];
      if (!Array.isArray(parsed)) {
        return [];
      }
      const folders: BookmarkFolderRecord[] = [];
      const ids: Set<string> = new Set<string>();
      const names: Set<string> = new Set<string>();
      for (let index: number = 0; index < parsed.length; index += 1) {
        const folder: BookmarkFolderRecord = parsed[index];
        if (!this.validBookmarkFolder(folder)) {
          continue;
        }
        const name: string = folder.name.trim();
        if (ids.has(folder.id) || names.has(name) || name === '书签') {
          continue;
        }
        ids.add(folder.id);
        names.add(name);
        folders.push({ id: folder.id, name, createdAt: folder.createdAt });
      }
      return folders;
    } catch (_error) {
      return [];
    }
  }

  async createBookmarkFolder(name: string): Promise<BookmarkFolderRecord | undefined> {
    const normalizedName: string = name.trim();
    if (normalizedName.length === 0 || normalizedName.length > MAX_BOOKMARK_FOLDER_NAME_LENGTH ||
      normalizedName === '书签') {
      return undefined;
    }
    let created: BookmarkFolderRecord | undefined;
    await this.enqueueBookmarkFolderOperation(async (): Promise<void> => {
      const folders: BookmarkFolderRecord[] = await this.listBookmarkFolders();
      if (folders.some((folder: BookmarkFolderRecord) => folder.name === normalizedName)) {
        return;
      }
      let id: string = '';
      do {
        this.nextBookmarkFolderId += 1;
        id = `bookmark-folder-${Date.now()}-${this.nextBookmarkFolderId}`;
      } while (folders.some((folder: BookmarkFolderRecord) => folder.id === id));
      created = { id, name: normalizedName, createdAt: Date.now() };
      folders.push(created);
      await this.writeJson(BOOKMARK_FOLDERS_KEY, folders);
    });
    return created;
  }

  /** Replace the original bookmark once, retaining its order and creation time. */
  async updateBookmark(originalUrl: string, title: string, url: string, folderId?: string): Promise<boolean> {
    const normalizedUrl: string | undefined = loadableUrlFor(url);
    if (normalizedUrl === undefined || normalizedUrl === 'about:blank') {
      return false;
    }
    const bookmarks: BookmarkRecord[] = await this.listBookmarks();
    const index: number = bookmarks.findIndex((record: BookmarkRecord) => record.url === originalUrl);
    if (index < 0 || bookmarks.some((record: BookmarkRecord, position: number) =>
      position !== index && record.url === normalizedUrl)) {
      return false;
    }
    const existingFolderId: string | undefined = bookmarks[index].folderId;
    const targetFolderId: string | undefined = folderId === undefined ? existingFolderId :
      (folderId.length === 0 ? undefined : folderId);
    if (targetFolderId !== undefined) {
      const folders: BookmarkFolderRecord[] = await this.listBookmarkFolders();
      if (!folders.some((folder: BookmarkFolderRecord) => folder.id === targetFolderId)) {
        return false;
      }
    }
    const updated: BookmarkRecord = {
      url: normalizedUrl,
      title: title.trim().length > 0 ? title.trim() : normalizedUrl,
      createdAt: bookmarks[index].createdAt
    };
    if (targetFolderId !== undefined) {
      updated.folderId = targetFolderId;
    }
    bookmarks[index] = updated;
    await this.writeJson(BOOKMARKS_KEY, bookmarks);
    return true;
  }

  async removeBookmark(url: string): Promise<void> {
    if (url.length === 0) {
      return;
    }
    const bookmarks: BookmarkRecord[] = await this.listBookmarks();
    const remaining: BookmarkRecord[] = bookmarks.filter((item: BookmarkRecord) => item.url !== url);
    if (remaining.length !== bookmarks.length) {
      await this.writeJson(BOOKMARKS_KEY, remaining);
    }
  }

  async listBookmarks(): Promise<BookmarkRecord[]> {
    const raw: string = await this.store.getString(BOOKMARKS_KEY, '[]');
    try {
      const parsed: BookmarkRecord[] = JSON.parse(raw) as BookmarkRecord[];
      if (!Array.isArray(parsed)) {
        return [];
      }
      return parsed
        .filter((record: BookmarkRecord) => this.validBookmark(record))
        .map((record: BookmarkRecord) => this.copyBookmark(record));
    } catch (_error) {
      return [];
    }
  }

  async loadSettings(): Promise<BrowserSettings> {
    const raw: string = await this.store.getString(SETTINGS_KEY, '');
    if (raw.length === 0) {
      return copyBrowserSettings(DEFAULT_BROWSER_SETTINGS);
    }
    try {
      return normalizeBrowserSettings(JSON.parse(raw) as Object);
    } catch (_error) {
      return copyBrowserSettings(DEFAULT_BROWSER_SETTINGS);
    }
  }

  async saveSettings(settings: BrowserSettings): Promise<void> {
    await this.writeJson(SETTINGS_KEY, copyBrowserSettings(settings));
  }

  async loadSiteSearchTemplates(): Promise<SiteSearchTemplate[]> {
    const raw: string = await this.store.getString(SITE_SEARCH_TEMPLATES_KEY, '[]');
    try { return normalizeSiteSearchTemplates(JSON.parse(raw) as Object); } catch (_error) { return []; }
  }

  async saveSiteSearchTemplates(templates: SiteSearchTemplate[]): Promise<void> {
    await this.writeJson(SITE_SEARCH_TEMPLATES_KEY, normalizeSiteSearchTemplates(templates as Object));
  }

  async upsertSiteSearchTemplate(template: SiteSearchTemplate): Promise<void> {
    const operation = async (): Promise<void> => {
      const current: SiteSearchTemplate[] = await this.loadSiteSearchTemplates();
      await this.writeJson(SITE_SEARCH_TEMPLATES_KEY, upsertSiteSearchTemplate(current, template));
    };
    const next: Promise<void> = this.siteSearchOperation.then(operation, operation);
    this.siteSearchOperation = next.then(() => undefined, () => undefined);
    await next;
  }

  async listStartPageItems(): Promise<StartPageItem[]> {
    const raw: string = await this.store.getString(START_PAGE_KEY, '[]');
    return this.parseStartPageItems(raw);
  }

  async saveStartPageItems(items: StartPageItem[]): Promise<void> {
    const valid: StartPageItem[] = items.filter((item: StartPageItem) => validStartPageItem(item));
    await this.writeJson(START_PAGE_KEY, sortStartPageItems(valid));
  }

  async listPageIcons(): Promise<PageIconRecord[]> {
    const raw: string = await this.store.getString(PAGE_ICONS_KEY, '[]');
    try {
      const parsed: PageIconRecord[] = JSON.parse(raw) as PageIconRecord[];
      if (!Array.isArray(parsed)) {
        return [];
      }
      return parsed
        .filter((record: PageIconRecord) => validPageIconRecord(record))
        .map((record: PageIconRecord) => copyPageIconRecord(record))
        .slice(-MAX_PAGE_ICONS);
    } catch (_error) {
      return [];
    }
  }

  async savePageIcon(record: PageIconRecord): Promise<void> {
    if (!validPageIconRecord(record)) {
      return;
    }
    await this.enqueuePageIconOperation(async (): Promise<void> => {
      const records: PageIconRecord[] = await this.listPageIcons();
      await this.writeJson(PAGE_ICONS_KEY, upsertPageIconRecord(records, record, MAX_PAGE_ICONS));
    });
  }

  async loadClosedTabs(): Promise<ClosedTabRecord[]> {
    const raw: string = await this.store.getString(CLOSED_TABS_KEY, '[]');
    try {
      const parsed: ClosedTabRecord[] = JSON.parse(raw) as ClosedTabRecord[];
      if (!Array.isArray(parsed)) {
        return [];
      }
      return parsed
        .filter((record: ClosedTabRecord) => this.validClosedTab(record))
        .map((record: ClosedTabRecord) => this.copyClosedTab(record))
        .sort((left: ClosedTabRecord, right: ClosedTabRecord) => right.closedAt - left.closedAt)
        .slice(0, MAX_CLOSED_TABS);
    } catch (_error) {
      return [];
    }
  }

  async saveClosedTabs(records: ClosedTabRecord[]): Promise<void> {
    const valid: ClosedTabRecord[] = records
      .filter((record: ClosedTabRecord) => this.validClosedTab(record))
      .filter((record: ClosedTabRecord) => !record.isPrivate)
      .map((record: ClosedTabRecord) => this.copyClosedTab(record))
      .sort((left: ClosedTabRecord, right: ClosedTabRecord) => right.closedAt - left.closedAt)
      .slice(0, MAX_CLOSED_TABS);
    await this.writeJson(CLOSED_TABS_KEY, valid);
  }

  private async writeJson(key: string, value: Object): Promise<void> {
    await this.store.putString(key, JSON.stringify(value));
    await this.store.flush();
  }

  private parseStartPageItems(raw: string): StartPageItem[] {
    try {
      const parsed: StartPageItem[] = JSON.parse(raw) as StartPageItem[];
      if (!Array.isArray(parsed)) {
        return [];
      }
      return sortStartPageItems(parsed.filter((item: StartPageItem) => validStartPageItem(item)));
    } catch (_error) {
      return [];
    }
  }

  private validClosedTab(record: ClosedTabRecord): boolean {
    return record !== undefined && typeof record.id === 'string' && record.id.length > 0 &&
      typeof record.url === 'string' && record.url.length > 0 && typeof record.title === 'string' &&
      typeof record.isPrivate === 'boolean' && typeof record.closedAt === 'number' &&
      Number.isFinite(record.closedAt) && typeof record.thumbnailKey === 'string';
  }

  private copyClosedTab(record: ClosedTabRecord): ClosedTabRecord {
    return {
      id: record.id,
      url: record.url,
      title: record.title,
      isPrivate: record.isPrivate,
      closedAt: record.closedAt,
      thumbnailKey: record.thumbnailKey
    };
  }

  private parseSession(raw: string): BrowserSessionSnapshot | undefined {
    if (raw.length === 0) {
      return undefined;
    }
    try {
      const parsed: BrowserSessionSnapshot = JSON.parse(raw) as BrowserSessionSnapshot;
      if (parsed.version !== 1 || !Array.isArray(parsed.tabs)) {
        return undefined;
      }
      const tabs: BrowserTabRecord[] = parsed.tabs
        .filter((tab: BrowserTabRecord) => this.validNormalTab(tab))
        .map((tab: BrowserTabRecord) => this.copyTab(tab));
      if (tabs.length === 0) {
        return undefined;
      }
      const activeTabId: string = typeof parsed.activeTabId === 'string' &&
        tabs.some((tab: BrowserTabRecord) => tab.id === parsed.activeTabId)
        ? parsed.activeTabId
        : tabs[0].id;
      return {
        version: 1,
        activeTabId,
        tabs
      };
    } catch (_error) {
      return undefined;
    }
  }

  private validNormalTab(tab: BrowserTabRecord): boolean {
    return tab !== undefined && typeof tab.id === 'string' && tab.id.length > 0 &&
      typeof tab.url === 'string' && tab.url.length > 0 && typeof tab.title === 'string' &&
      tab.isPrivate === false && typeof tab.createdAt === 'number' && Number.isFinite(tab.createdAt) &&
      typeof tab.lastAccessedAt === 'number' && Number.isFinite(tab.lastAccessedAt);
  }

  private validHistory(record: HistoryRecord): boolean {
    return record !== undefined && typeof record.url === 'string' && record.url.length > 0 &&
      record.url !== 'about:blank' &&
      typeof record.title === 'string' && typeof record.visitedAt === 'number' &&
      Number.isFinite(record.visitedAt);
  }

  private validBookmark(record: BookmarkRecord): boolean {
    return record !== undefined && typeof record.url === 'string' && record.url.length > 0 &&
      typeof record.title === 'string' && typeof record.createdAt === 'number' &&
      Number.isFinite(record.createdAt) &&
      (record.folderId === undefined || typeof record.folderId === 'string');
  }

  private validBookmarkFolder(folder: BookmarkFolderRecord): boolean {
    return folder !== undefined && folder !== null && typeof folder.id === 'string' && folder.id.trim().length > 0 &&
      typeof folder.name === 'string' && folder.name.trim().length > 0 &&
      folder.name.trim().length <= MAX_BOOKMARK_FOLDER_NAME_LENGTH &&
      typeof folder.createdAt === 'number' && Number.isFinite(folder.createdAt);
  }

  private copyTab(tab: BrowserTabRecord): BrowserTabRecord {
    const canonicalUrl: string = lastValidUrlForTab(tab);
    return {
      id: tab.id,
      url: canonicalUrl,
      lastValidUrl: canonicalUrl,
      displayUrl: displayUrlFor(canonicalUrl),
      pageSnapshot: tab.pageSnapshot === undefined ? tab.thumbnailKey : tab.pageSnapshot,
      title: tab.title,
      isPrivate: false,
      createdAt: tab.createdAt,
      lastAccessedAt: tab.lastAccessedAt,
      thumbnailKey: tab.thumbnailKey,
      residency: TabResidency.COLD,
      addressSource: tab.addressSource,
      addressQuery: tab.addressQuery
    };
  }

  private copyHistory(record: HistoryRecord): HistoryRecord {
    return {
      url: record.url,
      title: record.title,
      visitedAt: record.visitedAt
    };
  }

  private copyBookmark(record: BookmarkRecord): BookmarkRecord {
    const copy: BookmarkRecord = {
      url: record.url,
      title: record.title,
      createdAt: record.createdAt
    };
    if (record.folderId !== undefined && record.folderId.length > 0) {
      copy.folderId = record.folderId;
    }
    return copy;
  }
}
