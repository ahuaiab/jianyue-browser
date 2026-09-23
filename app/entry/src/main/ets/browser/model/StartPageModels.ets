import { BookmarkRecord, HistoryRecord } from './BrowserTypes';
import {
  SAFARI_TRANSPARENT_SURFACE_COLOR,
  safariChromeSurfaceBackgroundColor
} from './BrowserVisualMetrics';

const START_PAGE_SYSTEM_BACKGROUND_ID: string = 'system-gradient';

/**
 * Converts the persisted background choice into an Image source.
 *
 * The system choice is deliberately represented by undefined so callers can
 * keep the default native page surface without mounting an Image node.
 */
export function startPageBackgroundSource(backgroundId: string): string | undefined {
  const normalized: string = backgroundId.trim();
  if (normalized.length === 0 || normalized === START_PAGE_SYSTEM_BACKGROUND_ID) {
    return undefined;
  }
  return normalized;
}

/** Add a light material surface when start-page content sits over a wallpaper. */
export function startPageContentSurfaceColor(
  backgroundId: string,
  immersiveMaterialSupported: boolean = false
): string {
  return startPageUsesImmersiveSurface(backgroundId)
    ? safariChromeSurfaceBackgroundColor(immersiveMaterialSupported)
    : SAFARI_TRANSPARENT_SURFACE_COLOR;
}

/** Native immersive light sensing is meaningful only when a wallpaper is mounted. */
export function startPageUsesImmersiveSurface(backgroundId: string): boolean {
  return startPageBackgroundSource(backgroundId) !== undefined;
}

/** A cached start-page frame is valid only for the background it captured. */
export function startPageThumbnailMatchesBackground(
  thumbnailBackgroundId: string,
  currentBackgroundId: string
): boolean {
  const captured: string = thumbnailBackgroundId.trim();
  const current: string = currentBackgroundId.trim();
  return captured.length > 0 && captured === current;
}

export enum StartPageItemType {
  FAVORITE = 'favorite',
  FREQUENT = 'frequent'
}

/** The favorites section is user-enabled even before its first item exists. */
export function shouldRenderStartPageSection(
  type: StartPageItemType,
  visible: boolean,
  itemCount: number
): boolean {
  return visible && (type === StartPageItemType.FAVORITE || itemCount > 0);
}

export interface StartPageItem {
  id: string;
  type: StartPageItemType;
  title: string;
  url: string;
  order: number;
  updatedAt: number;
}

/** Use the saved tile title while the destination page is still loading. */
export function startPageItemNavigationTitle(item: StartPageItem): string {
  const title: string = item.title.trim();
  return title.length > 0 ? title : item.url;
}

/**
 * Projects the bookmark library onto the start page while retaining the
 * user's existing tile order. The bookmark library is the source of truth for
 * title and URL; persisted start-page items only provide stable ids and order.
 */
export function mergeBookmarkedStartPageItems(
  existingItems: StartPageItem[],
  bookmarks: BookmarkRecord[]
): StartPageItem[] {
  const currentBookmarks: BookmarkRecord[] = [];
  const seenUrls: Set<string> = new Set();
  for (const record of bookmarks) {
    const url: string = record.url.trim();
    if (url.length === 0 || seenUrls.has(url)) {
      continue;
    }
    seenUrls.add(url);
    currentBookmarks.push({
      url,
      title: record.title.trim(),
      createdAt: record.createdAt
    });
  }

  const bookmarkByUrl: Map<string, BookmarkRecord> = new Map();
  currentBookmarks.forEach((record: BookmarkRecord) => bookmarkByUrl.set(record.url, record));

  const existingFavorites: StartPageItem[] = sortStartPageItems(existingItems.filter(
    (item: StartPageItem) => item.type === StartPageItemType.FAVORITE
  ));
  const mergedFavorites: StartPageItem[] = [];
  const mergedUrls: Set<string> = new Set();

  // Preserve the order the user already established in the editor.
  for (const item of existingFavorites) {
    const url: string = item.url.trim();
    const record: BookmarkRecord | undefined = bookmarkByUrl.get(url);
    if (record === undefined || mergedUrls.has(url)) {
      continue;
    }
    mergedUrls.add(url);
    mergedFavorites.push({
      id: item.id,
      type: StartPageItemType.FAVORITE,
      title: record.title.length > 0 ? record.title : record.url,
      url: record.url,
      order: mergedFavorites.length,
      updatedAt: record.createdAt
    });
  }

  // New library bookmarks are appended instead of reordering existing tiles.
  for (const record of currentBookmarks) {
    if (mergedUrls.has(record.url)) {
      continue;
    }
    mergedUrls.add(record.url);
    mergedFavorites.push({
      id: `bookmark-${encodeURIComponent(record.url)}`,
      type: StartPageItemType.FAVORITE,
      title: record.title.length > 0 ? record.title : record.url,
      url: record.url,
      order: mergedFavorites.length,
      updatedAt: record.createdAt
    });
  }

  // Keep other future start-page sections intact; each section owns its order.
  const otherItems: StartPageItem[] = sortStartPageItems(existingItems.filter(
    (item: StartPageItem) => item.type !== StartPageItemType.FAVORITE
  ));
  return [...mergedFavorites, ...otherItems];
}

export function copyStartPageItem(item: StartPageItem): StartPageItem {
  return {
    id: item.id,
    type: item.type,
    title: item.title,
    url: item.url,
    order: item.order,
    updatedAt: item.updatedAt
  };
}

export function sortStartPageItems(items: StartPageItem[]): StartPageItem[] {
  return items.map((item: StartPageItem) => copyStartPageItem(item)).sort((left: StartPageItem, right: StartPageItem) => {
    if (left.order !== right.order) {
      return left.order - right.order;
    }
    if (left.updatedAt !== right.updatedAt) {
      return right.updatedAt - left.updatedAt;
    }
    return left.id.localeCompare(right.id);
  });
}

/**
 * Builds the start-page frequent-site list from history without allowing
 * every search query to become a visually identical destination entry.
 */
export function buildFrequentStartPageItems(history: HistoryRecord[], maxItems: number = 6): StartPageItem[] {
  const limit: number = Math.max(0, Math.floor(maxItems));
  if (limit === 0) {
    return [];
  }
  const seen: Set<string> = new Set();
  const frequent: StartPageItem[] = [];
  for (const record of history) {
    const rawUrl: string = record.url.trim();
    if (rawUrl.length === 0 || rawUrl === 'about:blank') {
      continue;
    }
    const queryIndex: number = rawUrl.indexOf('?');
    const fragmentIndex: number = rawUrl.indexOf('#');
    let endIndex: number = rawUrl.length;
    if (queryIndex >= 0) {
      endIndex = Math.min(endIndex, queryIndex);
    }
    if (fragmentIndex >= 0) {
      endIndex = Math.min(endIndex, fragmentIndex);
    }
    const normalizedUrl: string = rawUrl.slice(0, endIndex);
    const key: string = normalizedUrl.toLowerCase();
    if (normalizedUrl.length === 0 || seen.has(key)) {
      continue;
    }
    seen.add(key);
    frequent.push({
      id: `frequent-${encodeURIComponent(normalizedUrl)}`,
      type: StartPageItemType.FREQUENT,
      title: record.title.trim().length > 0 ? record.title.trim() : normalizedUrl,
      url: normalizedUrl,
      order: frequent.length,
      updatedAt: record.visitedAt
    });
    if (frequent.length >= limit) {
      break;
    }
  }
  return frequent;
}

export function validStartPageItem(item: StartPageItem): boolean {
  return item !== undefined && typeof item.id === 'string' && item.id.length > 0 &&
    (item.type === StartPageItemType.FAVORITE || item.type === StartPageItemType.FREQUENT) &&
    typeof item.title === 'string' &&
    typeof item.url === 'string' && item.url.length > 0 && typeof item.order === 'number' &&
    Number.isFinite(item.order) && typeof item.updatedAt === 'number' && Number.isFinite(item.updatedAt);
}
