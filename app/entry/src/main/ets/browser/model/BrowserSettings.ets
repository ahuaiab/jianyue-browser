/** User-facing browser settings mirrored from the video, kept independent of ArkWeb. */
export enum BrowserSearchEngine {
  BING = 'bing',
  BAIDU = 'baidu',
  CUSTOM = 'custom'
}

export interface CustomSearchEngine {
  name: string;
  /** HTTP(S) URL with one or more `%s` placeholders for an encoded query. */
  urlTemplate: string;
}

export interface StartPageBackgroundPosition {
  /** 0 is left/top and 1 is right/bottom within the cover crop. */
  x: number;
  y: number;
}

export const DEFAULT_START_PAGE_BACKGROUND_POSITION: StartPageBackgroundPosition = {
  x: 0.5,
  y: 0.5
};

export const DEFAULT_START_PAGE_BACKGROUND_SCALE: number = 1;
export const MIN_START_PAGE_BACKGROUND_SCALE: number = 1;
export const MAX_START_PAGE_BACKGROUND_SCALE: number = 3;

export function normalizeStartPageBackgroundPosition(value: Object | undefined): StartPageBackgroundPosition {
  if (value === undefined || value === null || typeof value !== 'object') {
    return {
      x: DEFAULT_START_PAGE_BACKGROUND_POSITION.x,
      y: DEFAULT_START_PAGE_BACKGROUND_POSITION.y
    };
  }
  const candidate: Partial<StartPageBackgroundPosition> = value as Partial<StartPageBackgroundPosition>;
  const x: number = typeof candidate.x === 'number' && Number.isFinite(candidate.x) ? candidate.x : 0.5;
  const y: number = typeof candidate.y === 'number' && Number.isFinite(candidate.y) ? candidate.y : 0.5;
  return {
    x: Math.max(0, Math.min(1, x)),
    y: Math.max(0, Math.min(1, y))
  };
}

export function normalizeStartPageBackgroundScale(value: number | undefined): number {
  if (value === undefined || !Number.isFinite(value)) {
    return DEFAULT_START_PAGE_BACKGROUND_SCALE;
  }
  return Math.max(MIN_START_PAGE_BACKGROUND_SCALE, Math.min(MAX_START_PAGE_BACKGROUND_SCALE, value));
}

/** Apply one pinch gesture without allowing an old component parameter to win. */
export function startPageBackgroundScaleForGesture(startScale: number, gestureScale: number): number {
  const baseScale: number = normalizeStartPageBackgroundScale(startScale);
  const safeGestureScale: number = Number.isFinite(gestureScale) && gestureScale > 0 ? gestureScale : 1;
  return normalizeStartPageBackgroundScale(baseScale * safeGestureScale);
}

export enum AutoCloseTabsPolicy {
  NEVER = 'never',
  AFTER_ONE_DAY = 'after_one_day',
  AFTER_ONE_WEEK = 'after_one_week',
  AFTER_ONE_MONTH = 'after_one_month'
}

/** Retained for persisted-settings compatibility; the app follows system appearance. */
export enum StartPageAppearance {
  LIGHT = 'light',
  FOLLOW_SYSTEM = 'follow_system'
}

export interface BrowserSettings {
  searchEngine: BrowserSearchEngine;
  customSearchEngine?: CustomSearchEngine;
  autoCloseTabs: AutoCloseTabsPolicy;
  contentBlockingEnabled: boolean;
  showFavorites: boolean;
  showFrequentSites: boolean;
  /** True after the user has explicitly visited/changed the start-page switches. */
  startPageSectionsConfigured: boolean;
  startPageBackgroundId: string;
  startPageBackgroundPosition: StartPageBackgroundPosition;
  startPageBackgroundScale: number;
  startPageAppearance: StartPageAppearance;
  defaultFontSize: string;
}

export const DEFAULT_BROWSER_SETTINGS: BrowserSettings = {
  searchEngine: BrowserSearchEngine.BING,
  customSearchEngine: undefined,
  autoCloseTabs: AutoCloseTabsPolicy.NEVER,
  contentBlockingEnabled: false,
  showFavorites: false,
  showFrequentSites: false,
  startPageSectionsConfigured: false,
  startPageBackgroundId: 'system-gradient',
  startPageBackgroundPosition: DEFAULT_START_PAGE_BACKGROUND_POSITION,
  startPageBackgroundScale: DEFAULT_START_PAGE_BACKGROUND_SCALE,
  startPageAppearance: StartPageAppearance.FOLLOW_SYSTEM,
  defaultFontSize: 'standard'
};

/** Normalize a user-defined search engine before it is persisted or used. */
export function normalizeCustomSearchEngine(value: Object | undefined): CustomSearchEngine | undefined {
  if (value === undefined || value === null || typeof value !== 'object') {
    return undefined;
  }
  const candidate: Partial<CustomSearchEngine> = value as Partial<CustomSearchEngine>;
  const name: string = typeof candidate.name === 'string' ? candidate.name.trim() : '';
  const urlTemplate: string = typeof candidate.urlTemplate === 'string'
    ? candidate.urlTemplate.trim()
    : '';
  const lowerTemplate: string = urlTemplate.toLowerCase();
  const schemeValid: boolean = lowerTemplate.startsWith('https://') || lowerTemplate.startsWith('http://');
  const schemeEnd: number = urlTemplate.indexOf('://');
  const hostStart: number = schemeEnd < 0 ? urlTemplate.length : schemeEnd + 3;
  const host: string = urlTemplate.slice(hostStart).split('/')[0].split('?')[0].split('#')[0];
  if (name.length === 0 || name.length > 32 || urlTemplate.length === 0 || urlTemplate.length > 512 ||
    !schemeValid || host.length === 0 || urlTemplate.includes('%s') === false ||
    urlTemplate.includes(' ') || urlTemplate.includes('\n') || urlTemplate.includes('\r')) {
    return undefined;
  }
  return { name, urlTemplate };
}

/** Search engines exposed by the settings UI; custom is shown after it is saved. */
export function availableBrowserSearchEngines(custom?: CustomSearchEngine): BrowserSearchEngine[] {
  const engines: BrowserSearchEngine[] = [BrowserSearchEngine.BING, BrowserSearchEngine.BAIDU];
  if (custom !== undefined) {
    engines.push(BrowserSearchEngine.CUSTOM);
  }
  return engines;
}

export function copyBrowserSettings(settings: BrowserSettings): BrowserSettings {
  return {
    searchEngine: settings.searchEngine,
    customSearchEngine: settings.customSearchEngine === undefined
      ? undefined
      : {
        name: settings.customSearchEngine.name,
        urlTemplate: settings.customSearchEngine.urlTemplate
      },
    autoCloseTabs: settings.autoCloseTabs,
    contentBlockingEnabled: settings.contentBlockingEnabled,
    showFavorites: settings.showFavorites,
    showFrequentSites: settings.showFrequentSites,
    startPageSectionsConfigured: settings.startPageSectionsConfigured,
    startPageBackgroundId: settings.startPageBackgroundId,
    startPageBackgroundPosition: {
      x: settings.startPageBackgroundPosition.x,
      y: settings.startPageBackgroundPosition.y
    },
    startPageBackgroundScale: normalizeStartPageBackgroundScale(settings.startPageBackgroundScale),
    // Appearance is no longer user-configurable; migrate old in-memory values too.
    startPageAppearance: StartPageAppearance.FOLLOW_SYSTEM,
    defaultFontSize: settings.defaultFontSize
  };
}

export function normalizeBrowserSettings(value: Object | undefined): BrowserSettings {
  if (value === undefined || value === null || typeof value !== 'object') {
    return copyBrowserSettings(DEFAULT_BROWSER_SETTINGS);
  }
  const candidate: Partial<BrowserSettings> = value as Partial<BrowserSettings>;
  const customSearchEngine: CustomSearchEngine | undefined = normalizeCustomSearchEngine(
    candidate.customSearchEngine as Object | undefined
  );
  const searchEngine: BrowserSearchEngine = candidate.searchEngine === BrowserSearchEngine.BAIDU
    ? BrowserSearchEngine.BAIDU
    : candidate.searchEngine === BrowserSearchEngine.CUSTOM && customSearchEngine !== undefined
      ? BrowserSearchEngine.CUSTOM
      : BrowserSearchEngine.BING;
  const autoCloseTabs: AutoCloseTabsPolicy = candidate.autoCloseTabs === AutoCloseTabsPolicy.AFTER_ONE_DAY ||
    candidate.autoCloseTabs === AutoCloseTabsPolicy.AFTER_ONE_WEEK ||
    candidate.autoCloseTabs === AutoCloseTabsPolicy.AFTER_ONE_MONTH
    ? candidate.autoCloseTabs
    : AutoCloseTabsPolicy.NEVER;
  // Before start-page switches were user-configurable, persisted settings
  // contained both flags as true without a marker. Treat that shape as the
  // old default so an upgrade starts with only the Edit action visible.
  const sectionsConfigured: boolean = candidate.startPageSectionsConfigured === true;
  const startPageAppearance: StartPageAppearance = StartPageAppearance.FOLLOW_SYSTEM;
  const startPageBackgroundPosition: StartPageBackgroundPosition = normalizeStartPageBackgroundPosition(
    candidate.startPageBackgroundPosition as Object | undefined
  );
  const startPageBackgroundScale: number = normalizeStartPageBackgroundScale(candidate.startPageBackgroundScale);
  return {
    searchEngine,
    customSearchEngine,
    autoCloseTabs,
    contentBlockingEnabled: candidate.contentBlockingEnabled === true,
    showFavorites: sectionsConfigured && candidate.showFavorites === true,
    showFrequentSites: sectionsConfigured && candidate.showFrequentSites === true,
    startPageSectionsConfigured: sectionsConfigured,
    startPageBackgroundId: typeof candidate.startPageBackgroundId === 'string' &&
      candidate.startPageBackgroundId.length > 0
      ? candidate.startPageBackgroundId
      : DEFAULT_BROWSER_SETTINGS.startPageBackgroundId,
    startPageBackgroundPosition,
    startPageBackgroundScale,
    startPageAppearance,
    defaultFontSize: typeof candidate.defaultFontSize === 'string' && candidate.defaultFontSize.length > 0
      ? candidate.defaultFontSize
      : DEFAULT_BROWSER_SETTINGS.defaultFontSize
  };
}
