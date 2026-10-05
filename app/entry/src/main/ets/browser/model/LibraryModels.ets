import { BookmarkRecord, HistoryRecord } from './BrowserTypes';
import { pageIconPathForUrl, PageIconRecord } from './PageIconModels';

/** The two native library views retained by the browser. */
export enum LibrarySection {
  HISTORY = 'history',
  BOOKMARKS = 'bookmarks'
}

export function librarySectionIconColor(selected: boolean): string {
  return selected ? '#007AFF' : '#AAB2BD';
}

/** Downward pulls reveal search; they never dismiss the shared library sheet. */
export function librarySheetPullDismissEnabled(): boolean {
  return false;
}

/** Horizontal travel, in vp, required to commit a section swipe. */
export const LIBRARY_SECTION_SWIPE_THRESHOLD: number = 48;

/** Downward drag distance, in vp, required to dismiss the library sheet. */
export const LIBRARY_DISMISS_THRESHOLD: number = 80;

/** Height and pull distance shared by the native library bottom sheet. */
export const LIBRARY_SHEET_HEIGHT_PERCENT: number = 56;
export const LIBRARY_SEARCH_PULL_THRESHOLD: number = 72;
export const LIBRARY_SEARCH_REVEAL_ANIMATION_DURATION_MS: number = 240;

export function librarySearchPullProgress(
  offsetY: number,
  threshold: number = LIBRARY_SEARCH_PULL_THRESHOLD
): number {
  const denominator: number = Math.max(1, threshold);
  return Math.min(1, Math.max(0, offsetY) / denominator);
}

export interface LibrarySearchScrollFrameResult {
  searchOffset: number;
  offsetRemain: number;
}

/** Consume scroll frames with the search slot first, then pass the remainder to the list. */
export function librarySearchScrollFrame(
  offset: number,
  searchOffset: number,
  listOffsetY: number,
  canRevealSearch: boolean
): LibrarySearchScrollFrameResult {
  const normalizedSearchOffset: number = Number.isFinite(searchOffset)
    ? Math.min(LIBRARY_SEARCH_PULL_THRESHOLD, Math.max(0, searchOffset))
    : 0;
  const normalizedOffset: number = Number.isFinite(offset) ? offset : 0;
  if (normalizedOffset > 0 && normalizedSearchOffset > 0) {
    const consumedBySearch: number = Math.min(normalizedOffset, normalizedSearchOffset);
    return {
      searchOffset: normalizedSearchOffset - consumedBySearch,
      offsetRemain: normalizedOffset - consumedBySearch
    };
  }
  if (normalizedOffset < 0 && canRevealSearch) {
    if (!Number.isFinite(listOffsetY)) {
      return { searchOffset: normalizedSearchOffset, offsetRemain: normalizedOffset };
    }
    const distanceToListTop: number = Math.max(0, listOffsetY);
    const listScrollOffset: number = -Math.min(-normalizedOffset, distanceToListTop);
    const searchRevealOffset: number = Math.max(0, -normalizedOffset + listScrollOffset);
    return {
      searchOffset: Math.min(LIBRARY_SEARCH_PULL_THRESHOLD, normalizedSearchOffset + searchRevealOffset),
      offsetRemain: listScrollOffset
    };
  }
  return { searchOffset: normalizedSearchOffset, offsetRemain: normalizedOffset };
}

/**
 * A hidden search opens only on a downward pull at the active list's top edge.
 * Once revealed, an upward pull closes it regardless of the current list
 * offset, so the close gesture also works while history is scrolled.
 */
export function librarySearchPullShouldCaptureGesture(
  scrollOffsetY: number,
  gestureOffsetY: number,
  searchRevealed: boolean = false
): boolean {
  if (!Number.isFinite(gestureOffsetY)) {
    return false;
  }
  if (searchRevealed) {
    return gestureOffsetY < 0;
  }
  return Number.isFinite(scrollOffsetY) && scrollOffsetY <= 0 && gestureOffsetY > 0;
}

/** Close a visible library search after a deliberate vertical upward touch. */
export function librarySearchSwipeShouldClose(
  deltaX: number,
  deltaY: number,
  searchVisible: boolean
): boolean {
  const closeThreshold: number = LIBRARY_SEARCH_PULL_THRESHOLD / 2;
  return searchVisible && Number.isFinite(deltaX) && Number.isFinite(deltaY) &&
    deltaY <= -closeThreshold && Math.abs(deltaY) > Math.abs(deltaX);
}

/** Keep partial collapse between gestures; close once the remaining slot is consumed. */
export function librarySearchSwipeReleaseOffset(
  offsetAfterSwipe: number,
  deltaX: number,
  deltaY: number,
  searchVisible: boolean
): number {
  if (!searchVisible) {
    return 0;
  }
  const normalizedOffset: number = Number.isFinite(offsetAfterSwipe)
    ? Math.min(LIBRARY_SEARCH_PULL_THRESHOLD, Math.max(0, offsetAfterSwipe))
    : LIBRARY_SEARCH_PULL_THRESHOLD;
  const upwardVerticalSwipe: boolean = Number.isFinite(deltaX) && Number.isFinite(deltaY) &&
    deltaY < 0 && Math.abs(deltaY) > Math.abs(deltaX);
  const shouldClose: boolean = librarySearchSwipeShouldClose(deltaX, deltaY, true) ||
    (upwardVerticalSwipe && normalizedOffset <= 0);
  return shouldClose ? 0 : normalizedOffset;
}

/** Track the visible search slot with a primarily vertical touch gesture. */
export function librarySearchSwipePullOffset(
  startOffset: number,
  deltaX: number,
  deltaY: number
): number {
  const normalizedStart: number = Number.isFinite(startOffset)
    ? Math.min(LIBRARY_SEARCH_PULL_THRESHOLD, Math.max(0, startOffset))
    : 0;
  if (!Number.isFinite(deltaX) || !Number.isFinite(deltaY) || Math.abs(deltaY) <= Math.abs(deltaX)) {
    return normalizedStart;
  }
  return Math.min(LIBRARY_SEARCH_PULL_THRESHOLD, Math.max(0, normalizedStart + deltaY));
}

/**
 * Convert a downward drag into a bounded sheet transition progress. The
 * progress reaches its terminal state at the dismiss threshold, while a
 * shorter drag remains reversible and can animate back to its origin.
 */
export function libraryDismissProgress(
  offsetY: number,
  threshold: number = LIBRARY_DISMISS_THRESHOLD
): number {
  const denominator: number = Math.max(1, threshold);
  return Math.min(1, Math.max(0, offsetY) / denominator);
}

export function libraryDismissShouldClose(
  offsetY: number,
  threshold: number = LIBRARY_DISMISS_THRESHOLD
): boolean {
  return offsetY >= Math.max(1, threshold);
}

/**
 * Resolve the section selected by a horizontal drag without mutating UI state.
 * A short drag stays on the current section so an interrupted gesture can
 * animate back to its origin instead of changing the list unexpectedly.
 */
export function librarySectionAfterSwipe(
  section: LibrarySection,
  offsetX: number,
  threshold: number = LIBRARY_SECTION_SWIPE_THRESHOLD
): LibrarySection {
  if (Math.abs(offsetX) < Math.max(1, threshold)) {
    return section;
  }
  if (section === LibrarySection.BOOKMARKS && offsetX < 0) {
    return LibrarySection.HISTORY;
  }
  if (section === LibrarySection.HISTORY && offsetX > 0) {
    return LibrarySection.BOOKMARKS;
  }
  return section;
}

/** Static chrome metadata used by the Safari-like library sheet. */
export const LIBRARY_BOOKMARK_BUTTON_MENU_LABEL: string = '添加书签';

export function libraryBookmarkActionEnabled(
  pageReady: boolean,
  isPrivate: boolean,
  url: string
): boolean {
  return pageReady && !isPrivate && url.trim().length > 0 && url !== 'about:blank';
}

export interface LibrarySectionChrome {
  title: string;
  symbolName: string;
  longPressMenuLabel: string;
}

export function librarySectionChrome(section: LibrarySection): LibrarySectionChrome {
  if (section === LibrarySection.BOOKMARKS) {
    return {
      title: '书签',
      symbolName: 'bookmark',
      longPressMenuLabel: LIBRARY_BOOKMARK_BUTTON_MENU_LABEL
    };
  }
  return { title: '历史记录', symbolName: 'clock', longPressMenuLabel: '' };
}

export enum HistoryTimelineSection {
  TODAY = 'today',
  YESTERDAY = 'yesterday',
  THIS_WEEK = 'this_week',
  EARLIER = 'earlier'
}

export enum HistoryDeleteRange {
  TODAY = 'today',
  THIS_WEEK = 'this_week',
  ALL = 'all'
}

export interface HistoryTimelineGroup {
  section: HistoryTimelineSection;
  title: string;
  entries: LibraryEntry[];
}

export interface LibraryEntry {
  id: string;
  section: LibrarySection;
  title: string;
  url: string;
  timestamp: number;
  timeText?: string;
  shortUrl?: string;
  iconPath?: string;
}

/** Keep a library row attached to the same UI node while neighboring rows change. */
export function libraryEntryRenderKey(entry: LibraryEntry): string {
  return entry.id;
}

/** Build the history source used by the sheet after an optimistic deletion. */
export function visibleHistoryRecords(
  records: HistoryRecord[],
  hiddenEntryIds: string[]
): HistoryRecord[] {
  return records.filter((record: HistoryRecord) =>
    hiddenEntryIds.indexOf(`history-${record.visitedAt}-${record.url}`) < 0);
}

function copyEntry(entry: LibraryEntry): LibraryEntry {
  return {
    id: entry.id,
    section: entry.section,
    title: entry.title,
    url: entry.url,
    timestamp: entry.timestamp,
    timeText: entry.timeText,
    shortUrl: entry.shortUrl,
    iconPath: entry.iconPath
  };
}

function validEntry(entry: LibraryEntry): boolean {
  return entry !== undefined && typeof entry.id === 'string' && entry.id.length > 0 &&
    (entry.section === LibrarySection.HISTORY || entry.section === LibrarySection.BOOKMARKS) &&
    typeof entry.title === 'string' &&
    typeof entry.url === 'string' && entry.url.length > 0 && typeof entry.timestamp === 'number' &&
    Number.isFinite(entry.timestamp);
}

const HISTORY_WEEKDAY_LABELS: string[] = [
  '星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'
];

function twoDigitTimePart(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

function historyTimeText(timestamp: number): string {
  if (!Number.isFinite(timestamp)) {
    return '';
  }
  const date: Date = new Date(timestamp);
  if (!Number.isFinite(date.getTime())) {
    return '';
  }
  return `${twoDigitTimePart(date.getHours())}:${twoDigitTimePart(date.getMinutes())}`;
}

function historyShortUrl(url: string): string {
  const normalizedUrl: string = url.trim();
  if (normalizedUrl.length === 0) {
    return '';
  }
  const schemeSeparatorIndex: number = normalizedUrl.indexOf('://');
  let authority: string = schemeSeparatorIndex >= 0
    ? normalizedUrl.substring(schemeSeparatorIndex + 3)
    : normalizedUrl;
  if (authority.startsWith('//')) {
    authority = authority.substring(2);
  }
  let authorityEnd: number = authority.length;
  const pathIndex: number = authority.indexOf('/');
  const queryIndex: number = authority.indexOf('?');
  const fragmentIndex: number = authority.indexOf('#');
  if (pathIndex >= 0 && pathIndex < authorityEnd) {
    authorityEnd = pathIndex;
  }
  if (queryIndex >= 0 && queryIndex < authorityEnd) {
    authorityEnd = queryIndex;
  }
  if (fragmentIndex >= 0 && fragmentIndex < authorityEnd) {
    authorityEnd = fragmentIndex;
  }
  authority = authority.substring(0, authorityEnd);
  const userInfoIndex: number = authority.lastIndexOf('@');
  if (userInfoIndex >= 0) {
    authority = authority.substring(userInfoIndex + 1);
  }
  if (authority.toLowerCase().startsWith('www.')) {
    authority = authority.substring(4);
  }
  return authority.length > 0 ? authority.toLowerCase() : normalizedUrl;
}

function historyDateText(timestamp: number): string {
  const date: Date = new Date(timestamp);
  if (!Number.isFinite(date.getTime())) {
    return '';
  }
  const weekday: string = HISTORY_WEEKDAY_LABELS[date.getDay()] ?? '';
  return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日${weekday}`;
}

function historyToEntries(records: HistoryRecord[], pageIcons: PageIconRecord[]): LibraryEntry[] {
  return records.map((record: HistoryRecord): LibraryEntry => ({
    id: `history-${record.visitedAt}-${record.url}`,
    section: LibrarySection.HISTORY,
    title: record.title,
    url: record.url,
    timestamp: record.visitedAt,
    timeText: historyTimeText(record.visitedAt),
    shortUrl: historyShortUrl(record.url),
    iconPath: pageIconPathForUrl(pageIcons, record.url)
  }));
}

function bookmarksToEntries(records: BookmarkRecord[], pageIcons: PageIconRecord[]): LibraryEntry[] {
  return records.map((record: BookmarkRecord, index: number): LibraryEntry => ({
    id: `bookmark-${index}-${record.url}`,
    section: LibrarySection.BOOKMARKS,
    title: record.title,
    url: record.url,
    timestamp: record.createdAt,
    iconPath: pageIconPathForUrl(pageIcons, record.url)
  }));
}

/** Returns defensive copies so the sheet cannot mutate repository state. */
export function libraryEntries(
  section: LibrarySection,
  history: HistoryRecord[],
  bookmarks: BookmarkRecord[],
  pageIcons: PageIconRecord[] = []
): LibraryEntry[] {
  let entries: LibraryEntry[] = [];
  if (section === LibrarySection.HISTORY) {
    entries = historyToEntries(history, pageIcons);
  } else if (section === LibrarySection.BOOKMARKS) {
    entries = bookmarksToEntries(bookmarks, pageIcons);
  }
  return entries.filter((entry: LibraryEntry) => validEntry(entry)).map((entry: LibraryEntry) => copyEntry(entry));
}

/** Filter by the same visible fields used by the library search field. */
export function filterLibraryEntries(entries: LibraryEntry[], query: string): LibraryEntry[] {
  const normalized: string = query.trim().toLowerCase();
  if (normalized.length === 0) {
    return entries.map((entry: LibraryEntry) => copyEntry(entry));
  }
  return entries
    .filter((entry: LibraryEntry) =>
      entry.title.toLowerCase().includes(normalized) || entry.url.toLowerCase().includes(normalized))
    .map((entry: LibraryEntry) => copyEntry(entry));
}

function startOfLocalDay(timestamp: number): number {
  const date: Date = new Date(timestamp);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

function startOfLocalWeek(timestamp: number): number {
  const date: Date = new Date(timestamp);
  const daysFromMonday: number = (date.getDay() + 6) % 7;
  date.setDate(date.getDate() - daysFromMonday);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

export function historyTimelineSection(timestamp: number, now: number): HistoryTimelineSection {
  if (!Number.isFinite(timestamp) || !Number.isFinite(now)) {
    return HistoryTimelineSection.EARLIER;
  }
  const todayStart: number = startOfLocalDay(now);
  const yesterday: Date = new Date(todayStart);
  yesterday.setDate(yesterday.getDate() - 1);
  const yesterdayStart: number = yesterday.getTime();
  const weekStart: number = startOfLocalWeek(now);
  if (timestamp >= todayStart) {
    return HistoryTimelineSection.TODAY;
  }
  if (timestamp >= yesterdayStart) {
    return HistoryTimelineSection.YESTERDAY;
  }
  if (timestamp >= weekStart) {
    return HistoryTimelineSection.THIS_WEEK;
  }
  return HistoryTimelineSection.EARLIER;
}

function timelineTitle(section: HistoryTimelineSection, dateText: string): string {
  if (section === HistoryTimelineSection.TODAY) {
    return `今天 - ${dateText}`;
  }
  if (section === HistoryTimelineSection.YESTERDAY) {
    return `昨天 - ${dateText}`;
  }
  return dateText;
}

export function historyTimelineGroups(
  records: HistoryRecord[],
  now: number,
  pageIcons: PageIconRecord[] = []
): HistoryTimelineGroup[] {
  const entries: LibraryEntry[] = libraryEntries(LibrarySection.HISTORY, records, [], pageIcons);
  const dayStarts: number[] = [];
  const entriesByDay: Map<number, LibraryEntry[]> = new Map();
  entries.forEach((entry: LibraryEntry) => {
    const dayStart: number = startOfLocalDay(entry.timestamp);
    if (!Number.isFinite(dayStart)) {
      return;
    }
    let dayEntries: LibraryEntry[] | undefined = entriesByDay.get(dayStart);
    if (dayEntries === undefined) {
      dayEntries = [];
      entriesByDay.set(dayStart, dayEntries);
      dayStarts.push(dayStart);
    }
    dayEntries.push(copyEntry(entry));
  });
  dayStarts.sort((left: number, right: number): number => right - left);
  return dayStarts.map((dayStart: number): HistoryTimelineGroup => {
    const dayEntries: LibraryEntry[] = entriesByDay.get(dayStart) ?? [];
    dayEntries.sort((left: LibraryEntry, right: LibraryEntry): number => right.timestamp - left.timestamp);
    const section: HistoryTimelineSection = historyTimelineSection(dayStart, now);
    const dateText: string = historyDateText(dayStart);
    return {
      section,
      title: timelineTitle(section, dateText),
      entries: dayEntries.map((entry: LibraryEntry) => copyEntry(entry))
    };
  });
}

export function historyDeleteCutoff(
  range: HistoryDeleteRange,
  now: number
): number | undefined {
  if (!Number.isFinite(now) || range === HistoryDeleteRange.ALL) {
    return undefined;
  }
  if (range === HistoryDeleteRange.TODAY) {
    return startOfLocalDay(now);
  }
  return startOfLocalWeek(now);
}

export function historyRecordInDeleteRange(
  record: HistoryRecord,
  range: HistoryDeleteRange,
  now: number
): boolean {
  if (record === undefined || !Number.isFinite(record.visitedAt)) {
    return false;
  }
  if (range === HistoryDeleteRange.ALL) {
    return true;
  }
  const cutoff: number | undefined = historyDeleteCutoff(range, now);
  return cutoff !== undefined && record.visitedAt >= cutoff;
}
