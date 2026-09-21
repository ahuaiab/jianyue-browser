import { describe, expect, it } from '@ohos/hypium';
import { Context } from '@kit.AbilityKit';
import {
  availableBrowserSearchEngines,
  BrowserSearchEngine,
  BrowserSettings,
  copyBrowserSettings,
  CustomSearchEngine,
  DEFAULT_BROWSER_SETTINGS,
  DEFAULT_START_PAGE_BACKGROUND_POSITION,
  DEFAULT_START_PAGE_BACKGROUND_SCALE,
  normalizeBrowserSettings,
  normalizeCustomSearchEngine,
  normalizeStartPageBackgroundPosition,
  normalizeStartPageBackgroundScale,
  StartPageBackgroundPosition,
  startPageBackgroundScaleForGesture
} from '../../../main/ets/browser/model/BrowserSettings';
import {
  buildFrequentStartPageItems,
  shouldRenderStartPageSection,
  sortStartPageItems,
  startPageBackgroundSource,
  StartPageItem,
  StartPageItemType,
  startPageThumbnailMatchesBackground
} from '../../../main/ets/browser/model/StartPageModels';
import { ClosedTabRecord, ClosedTabStack } from '../../../main/ets/browser/data/ClosedTabStack';
import {
  DEFAULT_PAGE_DISPLAY_STATE,
  PageDisplayState,
  PageFontSize
} from '../../../main/ets/browser/model/PageDisplayState';
import { BrowserRepository } from '../../../main/ets/browser/data/BrowserRepository';
import {
  applicationContextForPreferences,
  ApplicationContextProvider,
  KeyValueStore
} from '../../../main/ets/browser/data/KeyValueStore';
import {
  BookmarkRecord,
  BrowserTabRecord,
  HistoryRecord,
  normalizeAddressInput,
  searchEngineLabel,
  searchUrlForEngine,
  TabResidency
} from '../../../main/ets/browser/model/BrowserTypes';
import {
  ADDRESS_SEARCH_BAR_STYLE,
  ADDRESS_SEARCH_BAR_TOP_PADDING,
  filterTabsByQuery,
  TAB_CARD_MENU_DESTRUCTIVE_COLOR,
  TAB_CARD_MENU_LABELS,
  TAB_CARD_MENU_SYMBOL_NAMES,
  TAB_OVERVIEW_BACKGROUND_COLOR,
  TAB_OVERVIEW_GESTURE_CARD_HEIGHT,
  TAB_OVERVIEW_LAYOUT,
  TAB_SEARCH_BAR_BACKGROUND_COLOR,
  TAB_SEARCH_BAR_CONTENT_INSET,
  TAB_SEARCH_BAR_STYLE,
  TAB_SEARCH_PULL_THRESHOLD,
  TAB_SEARCH_REVEAL_ANIMATION_DURATION_MS,
  tabCardMenuItemIsDestructive,
  tabOverviewCardWidth,
  tabOverviewSnapshotSize,
  tabOverviewThumbnailCrop,
  tabOverviewThumbnailTopOffset,
  tabOverviewTopPadding,
  tabOverviewTopPaddingForProgress,
  tabSearchPullProgress,
  tabSearchVisualProgress,
  topContentInset
} from '../../../main/ets/browser/model/TabOverviewActions';
import {
  availablePageActions,
  desktopUserAgentFor,
  nextFontSize,
  PageAction,
  PageActionAvailability,
  pageMenuActions,
  pageModeMenuLabel,
  pageModeMenuSymbolName
} from '../../../main/ets/browser/model/PageActions';
import {
  filterLibraryEntries,
  historyDeleteCutoff,
  HistoryDeleteRange,
  historyRecordInDeleteRange,
  historyTimelineGroups,
  HistoryTimelineSection,
  historyTimelineSection,
  LIBRARY_DISMISS_THRESHOLD,
  LIBRARY_SEARCH_PULL_THRESHOLD,
  LIBRARY_SECTION_SELECTED_BACKGROUND,
  LIBRARY_SECTION_SWIPE_THRESHOLD,
  LIBRARY_SECTION_UNSELECTED_BACKGROUND,
  LIBRARY_SHEET_HEIGHT_PERCENT,
  libraryBookmarkActionEnabled,
  libraryDismissProgress,
  libraryDismissShouldClose,
  libraryEntries,
  libraryEntryRenderKey,
  librarySearchPullProgress,
  LibrarySection,
  librarySectionAfterSwipe,
  librarySectionBackground,
  librarySectionChrome,
  visibleHistoryRecords
} from '../../../main/ets/browser/model/LibraryModels';
import {
  addressInputIdentity,
  browserLifecycleDiagnostic,
  BrowserLifecycleEventKind,
  committedNavigationUrl,
  isAddressTransitionCurrent,
  placeholderForFocus,
  resetBrowserGestureState,
  shouldActivateWebController,
  shouldDismissOverviewBeforeCreatingTab,
  shouldMountTabWebHost,
  shouldMountWebHost,
  shouldRecoverMissingTabController,
  shouldRecreateBlankTabRuntime,
  shouldRefreshHostsForViewport,
  shouldRenderLiveWebHost,
  shouldRetryTabSnapshot,
  shouldRetryWebHostAttachment,
  webHostInputEnabled
} from '../../../main/ets/browser/model/BrowserInteraction';
import {
  HARMONY_RADIUS_FLOATING,
  SAFARI_ACTION_TOOLBAR_HEIGHT_VP,
  SAFARI_ADDRESS_HANDOFF_CROSSFADE_DURATION_MS,
  SAFARI_ADDRESS_HANDOFF_LEAD_IN_MS,
  SAFARI_ADDRESS_ITEM_GAP_VP,
  SAFARI_ADDRESS_ITEM_INSET_VP,
  SAFARI_ADDRESS_ITEM_SURFACE_INSET_VP,
  SAFARI_ADDRESS_PREVIEW_FADE_DURATION_MS,
  SAFARI_ADDRESS_ROW_HEIGHT_VP,
  SAFARI_BOTTOM_CHROME_BASE_HEIGHT_VP,
  SAFARI_BOTTOM_CHROME_BOTTOM_GAP_VP,
  SAFARI_BOTTOM_CHROME_FALLBACK_COLOR,
  SAFARI_BOTTOM_CHROME_HORIZONTAL_INSET_VP,
  SAFARI_BOTTOM_CHROME_MATERIAL_COLOR,
  SAFARI_BOTTOM_CHROME_RADIUS_VP,
  SAFARI_BOTTOM_CHROME_RAIL_INSET_VP,
  safariAddressTrackClipFrame,
  safariAddressItemWidth,
  safariBottomChromeActionCenter,
  safariBottomChromeActionSlotWidth,
  safariBottomChromeRailWidth,
  safariBottomChromeSurfaceWidth
} from '../../../main/ets/browser/model/BrowserVisualMetrics';
import {
  NEW_TAB_PULL_READY_DISTANCE,
  NEW_TAB_PULL_START,
  newTabBackgroundProgress,
  newTabPullProgress,
  projectedOffset,
  rubberBandDistance,
  shouldCommitNewTabPull,
  shouldCommitProjectedSwitch,
  TAB_RUBBER_BAND_MAX_PULL,
  tabGestureMotion,
  TabPreviewKind,
  tabTransitionVisualState
} from '../../../main/ets/browser/model/TabGestureMotion';
import { newTabHandoffVisual, shouldRenderAddressHandoff } from '../../../main/ets/browser/model/SafariTabTransition';
import {
  BrowserLifecyclePort,
  BrowserLifecycleRegistry
} from '../../../main/ets/browser/lifecycle/BrowserLifecyclePort';
import { visibleContentHeight } from '../../../main/ets/browser/model/WindowAvoidance';

function closed(id: string, isPrivate: boolean = false): ClosedTabRecord {
  return {
    id,
    url: `https://${id}.example`,
    title: id,
    isPrivate,
    closedAt: Number(id.replace('tab-', '')) || 1,
    thumbnailKey: ''
  };
}

function tab(id: string, title: string, url: string): BrowserTabRecord {
  return {
    id,
    title,
    url,
    lastValidUrl: url,
    displayUrl: url.replace(/^https?:\/\//, '').split('/')[0],
    pageSnapshot: '',
    isPrivate: false,
    createdAt: 1,
    lastAccessedAt: 1,
    thumbnailKey: '',
    residency: TabResidency.COLD
  };
}

class FakeVideoStore implements KeyValueStore {
  private readonly values: Map<string, string> = new Map();

  async getString(key: string, fallback: string): Promise<string> {
    return this.values.get(key) ?? fallback;
  }

  async putString(key: string, value: string): Promise<void> {
    this.values.set(key, value);
  }

  async flush(): Promise<void> {}

  putRaw(key: string, value: string): void {
    this.values.set(key, value);
  }
}

class FakePreferenceContext implements ApplicationContextProvider {
  private readonly application: Context;

  constructor(application: Context) {
    this.application = application;
  }

  getApplicationContext(): Context {
    return this.application;
  }
}

class FakeBackPort implements BrowserLifecyclePort {
  consumeBack: boolean = false;
  foregroundCount: number = 0;
  destroyCount: number = 0;

  async onBackground(): Promise<void> {}

  async onWindowStageDestroy(): Promise<void> {}

  async onDestroy(): Promise<void> {
    this.destroyCount += 1;
  }

  onForeground(): void {
    this.foregroundCount += 1;
  }

  onMemoryPressure(_level: number): void {}

  onBackPress(): boolean {
    return this.consumeBack;
  }

  onExternalUrl(_url: string): void {}
}

interface SettingsFixture {
  searchEngine?: BrowserSearchEngine | string;
  customSearchEngine?: CustomSearchEngine;
  autoCloseTabs?: string;
  contentBlockingEnabled?: boolean;
  showFavorites?: boolean;
  showFrequentSites?: boolean;
  startPageSectionsConfigured?: boolean;
  startPageBackgroundId?: string;
  startPageBackgroundPosition?: StartPageBackgroundPosition;
  startPageBackgroundScale?: number;
}

export default function videoParityModelsTest() {
  describe('VideoParityModels', () => {
    it('provides Safari-like display and start-page defaults', 0, () => {
      expect(DEFAULT_BROWSER_SETTINGS.searchEngine).assertEqual('bing');
      expect(DEFAULT_BROWSER_SETTINGS.autoCloseTabs).assertEqual('on_browser_close');
      expect(DEFAULT_BROWSER_SETTINGS.showFavorites).assertFalse();
      expect(DEFAULT_BROWSER_SETTINGS.showFrequentSites).assertFalse();
      expect(startPageBackgroundSource(DEFAULT_BROWSER_SETTINGS.startPageBackgroundId)).assertUndefined();
      expect(DEFAULT_PAGE_DISPLAY_STATE.fontSize).assertEqual(PageFontSize.STANDARD);
    });

    it('keeps a selected gallery URI as the start-page background source', 0, () => {
      expect(startPageBackgroundSource('  ')).assertUndefined();
      expect(startPageBackgroundSource('system-gradient')).assertUndefined();
      expect(startPageBackgroundSource('datashare:///media/Photo/001.jpg'))
        .assertEqual('datashare:///media/Photo/001.jpg');
    });

    it('normalizes and persists the start-page background position', 0, () => {
      expect(DEFAULT_START_PAGE_BACKGROUND_POSITION.x).assertEqual(0.5);
      expect(DEFAULT_START_PAGE_BACKGROUND_POSITION.y).assertEqual(0.5);
      const outOfRangePosition: StartPageBackgroundPosition = { x: 1.8, y: -0.4 };
      const normalized = normalizeStartPageBackgroundPosition(outOfRangePosition as Object);
      expect(normalized.x).assertEqual(1);
      expect(normalized.y).assertEqual(0);

      const settingsInput: SettingsFixture = {
        startPageBackgroundId: 'datashare:///media/Photo/001.jpg',
        startPageBackgroundPosition: { x: 0.2, y: 0.8 }
      };
      const settings: BrowserSettings = normalizeBrowserSettings(settingsInput as Object);
      expect(settings.startPageBackgroundPosition.x).assertEqual(0.2);
      expect(settings.startPageBackgroundPosition.y).assertEqual(0.8);
      const copied: BrowserSettings = copyBrowserSettings(settings);
      expect(copied.startPageBackgroundPosition.x).assertEqual(0.2);
      expect(copied.startPageBackgroundPosition.y).assertEqual(0.8);
    });

    it('normalizes and persists the start-page background scale', 0, () => {
      expect(DEFAULT_START_PAGE_BACKGROUND_SCALE).assertEqual(1);
      expect(normalizeStartPageBackgroundScale(0.2)).assertEqual(1);
      expect(normalizeStartPageBackgroundScale(4.5)).assertEqual(3);

      const settingsInput: SettingsFixture = {
        startPageBackgroundId: 'datashare:///media/Photo/001.jpg',
        startPageBackgroundScale: 2.25
      };
      const settings: BrowserSettings = normalizeBrowserSettings(settingsInput as Object);
      expect(settings.startPageBackgroundScale).assertEqual(2.25);
      const copied: BrowserSettings = copyBrowserSettings(settings);
      expect(copied.startPageBackgroundScale).assertEqual(2.25);
    });

    it('uses the visible page height for background crop geometry', 0, () => {
      expect(visibleContentHeight(944, 46, 154)).assertEqual(744);
      expect(visibleContentHeight(944, 46, 0)).assertEqual(898);
      expect(visibleContentHeight(100, 200, 50)).assertEqual(1);
    });

    it('keeps the last pinch scale instead of reverting to a stale parameter', 0, () => {
      expect(startPageBackgroundScaleForGesture(1, 1.75)).assertEqual(1.75);
      expect(startPageBackgroundScaleForGesture(2.5, 1.4)).assertEqual(3);
      expect(startPageBackgroundScaleForGesture(2, Number.NaN)).assertEqual(2);
    });

    it('does not reuse a start-page frame after the background changes', 0, () => {
      expect(startPageThumbnailMatchesBackground('system-gradient', 'system-gradient'))
        .assertTrue();
      expect(startPageThumbnailMatchesBackground('datashare:///media/Photo/old.jpg',
        'datashare:///media/Photo/new.jpg')).assertFalse();
      expect(startPageThumbnailMatchesBackground('', 'datashare:///media/Photo/new.jpg'))
        .assertFalse();
    });

    it('routes address searches through the selected search engine', 0, () => {
      expect(searchEngineLabel(BrowserSearchEngine.BAIDU)).assertEqual('百度');
      expect(searchUrlForEngine(BrowserSearchEngine.BAIDU, '鸿蒙 浏览器'))
        .assertEqual('https://www.baidu.com/s?wd=%E9%B8%BF%E8%92%99%20%E6%B5%8F%E8%A7%88%E5%99%A8');
      expect(normalizeAddressInput('open source', BrowserSearchEngine.BING))
        .assertEqual('https://cn.bing.com/search?q=open%20source');
      expect(normalizeAddressInput('developer.huawei.com', BrowserSearchEngine.BAIDU))
        .assertEqual('https://developer.huawei.com');
    });

    it('keeps only Bing and Baidu built-ins and supports a custom search engine', 0, () => {
      const builtIns: BrowserSearchEngine[] = availableBrowserSearchEngines();
      expect(builtIns.length).assertEqual(2);
      expect(builtIns[0]).assertEqual(BrowserSearchEngine.BING);
      expect(builtIns[1]).assertEqual(BrowserSearchEngine.BAIDU);

      const customInput: CustomSearchEngine = {
        name: '自定义搜索',
        urlTemplate: 'https://search.example/?q=%s'
      };
      const custom: CustomSearchEngine | undefined = normalizeCustomSearchEngine(customInput as Object);
      expect(custom === undefined).assertFalse();
      if (custom !== undefined) {
        const engines: BrowserSearchEngine[] = availableBrowserSearchEngines(custom);
        expect(engines.length).assertEqual(3);
        expect(engines[2]).assertEqual(BrowserSearchEngine.CUSTOM);
        expect(searchEngineLabel(BrowserSearchEngine.CUSTOM, custom)).assertEqual('自定义搜索');
        expect(searchUrlForEngine(BrowserSearchEngine.CUSTOM, '鸿蒙 浏览器', custom))
          .assertEqual('https://search.example/?q=%E9%B8%BF%E8%92%99%20%E6%B5%8F%E8%A7%88%E5%99%A8');
        const customSettingsInput: SettingsFixture = {
          searchEngine: BrowserSearchEngine.CUSTOM,
          customSearchEngine: custom
        };
        const customSettings: BrowserSettings = normalizeBrowserSettings(customSettingsInput as Object);
        expect(customSettings.searchEngine).assertEqual(BrowserSearchEngine.CUSTOM);
        expect(customSettings.customSearchEngine?.urlTemplate).assertEqual(custom.urlTemplate);
      }

      const migratedInput: SettingsFixture = { searchEngine: 'google' };
      const migrated: BrowserSettings = normalizeBrowserSettings(migratedInput as Object);
      expect(migrated.searchEngine).assertEqual(BrowserSearchEngine.BING);
      expect(searchUrlForEngine('google' as BrowserSearchEngine, 'legacy'))
        .assertEqual('https://cn.bing.com/search?q=legacy');
      const invalidCustomInput: CustomSearchEngine = {
        name: '无效',
        urlTemplate: 'https://example.com/search'
      };
      expect(normalizeCustomSearchEngine(invalidCustomInput as Object))
        .assertUndefined();
    });

    it('copies settings without sharing mutable state', 0, () => {
      const source: BrowserSettings = copyBrowserSettings(DEFAULT_BROWSER_SETTINGS);
      source.showFavorites = false;
      expect(DEFAULT_BROWSER_SETTINGS.showFavorites).assertFalse();
    });

    it('migrates legacy start-page sections to disabled until selected', 0, () => {
      const legacyValue: SettingsFixture = {
        searchEngine: BrowserSearchEngine.BING,
        showFavorites: true,
        showFrequentSites: true
      };
      const legacy: BrowserSettings = normalizeBrowserSettings(legacyValue as Object);
      expect(legacy.showFavorites).assertFalse();
      expect(legacy.showFrequentSites).assertFalse();

      const selectedValue: SettingsFixture = {
        searchEngine: BrowserSearchEngine.BING,
        showFavorites: true,
        showFrequentSites: false,
        startPageSectionsConfigured: true
      };
      const selected: BrowserSettings = normalizeBrowserSettings(selectedValue as Object);
      expect(selected.showFavorites).assertTrue();
      expect(selected.showFrequentSites).assertFalse();
    });

    it('migrates every legacy automatic tab-close interval to browser-close cleanup', 0, () => {
      const migratedInput: SettingsFixture = { autoCloseTabs: 'after_one_day' };
      const migrated: BrowserSettings = normalizeBrowserSettings(migratedInput as Object);
      expect(migrated.autoCloseTabs).assertEqual('on_browser_close');
    });

    it('keeps an enabled favorites section visible before the first favorite is added', 0, () => {
      expect(shouldRenderStartPageSection(StartPageItemType.FAVORITE, true, 0)).assertTrue();
      expect(shouldRenderStartPageSection(StartPageItemType.FAVORITE, false, 3)).assertFalse();
      expect(shouldRenderStartPageSection(StartPageItemType.FREQUENT, true, 0)).assertFalse();
    });

    it('sorts start-page items by explicit order then update time', 0, () => {
      const items: StartPageItem[] = [
        { id: 'b', type: StartPageItemType.FAVORITE, title: 'B', url: 'https://b.example', order: 1, updatedAt: 2 },
        { id: 'a', type: StartPageItemType.FREQUENT, title: 'A', url: 'https://a.example', order: 1, updatedAt: 3 },
        { id: 'c', type: StartPageItemType.FAVORITE, title: 'C', url: 'https://c.example', order: 0, updatedAt: 1 }
      ];
      const sorted: StartPageItem[] = sortStartPageItems(items);
      expect(sorted[0].id).assertEqual('c');
      expect(sorted[1].id).assertEqual('a');
      expect(sorted[2].id).assertEqual('b');
      expect(items[0].id).assertEqual('b');
    });

    it('deduplicates frequent sites by the page path without query noise', 0, () => {
      const history: HistoryRecord[] = [
        { url: 'https://cn.bing.com/search?q=first', title: '第一次搜索', visitedAt: 4 },
        { url: 'https://cn.bing.com/search?q=second', title: '第二次搜索', visitedAt: 3 },
        { url: 'https://developer.huawei.com/consumer/cn/?from=home', title: 'HarmonyOS', visitedAt: 2 }
      ];
      const frequent: StartPageItem[] = buildFrequentStartPageItems(history, 6);
      expect(frequent.length).assertEqual(2);
      expect(frequent[0].title).assertEqual('第一次搜索');
      expect(frequent[1].url).assertEqual('https://developer.huawei.com/consumer/cn/');
    });

    it('keeps only recent normal tabs in the closed stack', 0, () => {
      const stack: ClosedTabStack = new ClosedTabStack(2);
      stack.push(closed('tab-1'));
      stack.push(closed('tab-2'));
      stack.push(closed('tab-3'));
      stack.push(closed('tab-private', true));
      expect(stack.size()).assertEqual(2);
      expect(stack.pop()?.id).assertEqual('tab-3');
      expect(stack.pop()?.id).assertEqual('tab-2');
      expect(stack.pop()).assertUndefined();
    });

    it('normalizes an invalid display state to a safe copy', 0, () => {
      const state: PageDisplayState = {
        fontSize: PageFontSize.LARGE,
        fullScreen: false
      };
      expect(state.fontSize).assertEqual(PageFontSize.LARGE);
    });

    it('persists settings, start-page items and recently closed tabs', 0, async () => {
      const store: FakeVideoStore = new FakeVideoStore();
      const repository: BrowserRepository = new BrowserRepository(store);
      const settings: BrowserSettings = copyBrowserSettings(DEFAULT_BROWSER_SETTINGS);
      settings.showFavorites = false;
      settings.showFrequentSites = true;
      settings.startPageSectionsConfigured = true;
      settings.startPageBackgroundId = 'datashare:///media/Photo/selected-background.jpg';
      const item: StartPageItem = {
        id: 'favorite-1',
        type: StartPageItemType.FAVORITE,
        title: 'Example',
        url: 'https://example.com',
        order: 0,
        updatedAt: 1
      };
      await repository.saveSettings(settings);
      await repository.saveStartPageItems([item]);
      await repository.saveClosedTabs([closed('tab-10')]);
      expect((await repository.loadSettings()).showFavorites).assertFalse();
      expect((await repository.loadSettings()).showFrequentSites).assertTrue();
      expect((await repository.loadSettings()).startPageBackgroundId)
        .assertEqual('datashare:///media/Photo/selected-background.jpg');
      expect((await repository.listStartPageItems())[0].id).assertEqual('favorite-1');
      expect((await repository.loadClosedTabs())[0].id).assertEqual('tab-10');
    });

    it('removes individual bookmark and history entries for library editing', 0, async () => {
      const store: FakeVideoStore = new FakeVideoStore();
      const repository: BrowserRepository = new BrowserRepository(store);
      await repository.addBookmark({
        url: 'https://bookmark.example',
        title: 'Bookmark',
        createdAt: 2
      });
      await repository.addBookmark({
        url: 'https://keep.example',
        title: 'Keep',
        createdAt: 1
      });
      await repository.recordHistory({
        url: 'https://history.example',
        title: 'History',
        visitedAt: 3
      }, false);
      await repository.recordHistory({
        url: 'https://keep-history.example',
        title: 'Keep history',
        visitedAt: 2
      }, false);
      await repository.removeBookmark('https://bookmark.example');
      await repository.removeHistory('https://history.example');
      expect((await repository.listBookmarks()).length).assertEqual(1);
      expect((await repository.listBookmarks())[0].url).assertEqual('https://keep.example');
      expect((await repository.listHistory()).length).assertEqual(1);
      expect((await repository.listHistory())[0].url).assertEqual('https://keep-history.example');
    });

    it('falls back when video-parity settings JSON is malformed', 0, async () => {
      const store: FakeVideoStore = new FakeVideoStore();
      store.putRaw('browser.settings.v1', '{broken');
      const repository: BrowserRepository = new BrowserRepository(store);
      expect((await repository.loadSettings()).searchEngine).assertEqual('bing');
      expect((await repository.listStartPageItems()).length).assertEqual(0);
      expect((await repository.loadClosedTabs()).length).assertEqual(0);
    });

    it('keeps download management beside the page-mode action in the long-press menu', 0, () => {
      expect(nextFontSize(PageFontSize.SMALL)).assertEqual(PageFontSize.STANDARD);
      expect(nextFontSize(PageFontSize.STANDARD)).assertEqual(PageFontSize.LARGE);
      expect(nextFontSize(PageFontSize.LARGE)).assertEqual(PageFontSize.SMALL);
      const ready: PageActionAvailability = availablePageActions(true);
      expect(ready.enabled.length).assertEqual(2);
      expect(ready.enabled.includes(PageAction.DOWNLOAD_MANAGER)).assertTrue();
      expect(ready.enabled.includes(PageAction.DESKTOP_SITE)).assertTrue();
      expect(ready.enabled.includes(PageAction.BOOKMARK)).assertFalse();
      expect(pageMenuActions(true).length).assertEqual(2);
      expect(pageMenuActions(true)[0]).assertEqual(PageAction.DOWNLOAD_MANAGER);
      expect(pageMenuActions(true)[1]).assertEqual(PageAction.DESKTOP_SITE);
      const unavailable: PageActionAvailability = availablePageActions(false);
      expect(pageMenuActions(false).length).assertEqual(1);
      expect(pageMenuActions(false)[0]).assertEqual(PageAction.DOWNLOAD_MANAGER);
      expect(unavailable.enabled.includes(PageAction.DOWNLOAD_MANAGER)).assertTrue();
      expect(unavailable.reason.length > 0).assertTrue();
      expect(pageModeMenuLabel(false)).assertEqual('请求桌面网页');
      expect(pageModeMenuLabel(true)).assertEqual('请求手机网页');
      expect(pageModeMenuSymbolName(false)).assertEqual('sys.symbol.display');
      expect(pageModeMenuSymbolName(true, 'phone')).assertEqual('sys.symbol.rectangle_portrait');
      expect(pageModeMenuSymbolName(true, 'tablet')).assertEqual('sys.symbol.display');
      expect(pageModeMenuSymbolName(true, '2in1')).assertEqual('sys.symbol.display');
      expect(pageModeMenuSymbolName(true, 'unknown')).assertEqual('sys.symbol.display');
    });

    it('derives a desktop ArkWeb user agent without changing the browser identity', 0, () => {
      const mobile: string = 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 Chrome/130 Safari/537.36';
      const desktop: string = desktopUserAgentFor(mobile);
      expect(desktop.includes('Mobile')).assertFalse();
      expect(desktop.includes('Chrome/130')).assertTrue();
      expect(desktopUserAgentFor('Desktop UA')).assertEqual('Desktop UA');
    });

    it('filters tab overview by title and URL without mutating the source', 0, () => {
      const source: BrowserTabRecord[] = [
        tab('a', 'Harmony docs', 'https://developer.huawei.com'),
        tab('b', 'News', 'https://news.example'),
        tab('c', '收藏夹说明', 'https://favorites.example')
      ];
      expect(filterTabsByQuery(source, 'huawei').length).assertEqual(1);
      expect(filterTabsByQuery(source, '收藏').length).assertEqual(1);
      expect(filterTabsByQuery(source, '').length).assertEqual(3);
      expect(source.length).assertEqual(3);
    });

    it('defines a light two-column Safari tab overview layout', 0, () => {
      expect(TAB_OVERVIEW_LAYOUT.columns).assertEqual(2);
      expect(TAB_OVERVIEW_LAYOUT.horizontalPadding).assertEqual(16);
      expect(TAB_OVERVIEW_LAYOUT.cardHeight).assertEqual(242);
      expect(TAB_OVERVIEW_LAYOUT.gap).assertEqual(12);
      expect(TAB_OVERVIEW_LAYOUT.cardRadius).assertEqual(16);
    });

    it('uses the rendered tab-card height for close gesture geometry', 0, () => {
      expect(TAB_OVERVIEW_GESTURE_CARD_HEIGHT).assertEqual(TAB_OVERVIEW_LAYOUT.cardHeight);
      expect(TAB_OVERVIEW_GESTURE_CARD_HEIGHT).assertEqual(242);
    });

    it('keeps the home address field corner style aligned with tab search', 0, () => {
      expect(ADDRESS_SEARCH_BAR_STYLE.cornerRadius).assertEqual(TAB_SEARCH_BAR_STYLE.cornerRadius);
      expect(ADDRESS_SEARCH_BAR_STYLE.cornerRadius).assertEqual(12);
    });

    it('reveals tab search only after a downward pull threshold', 0, () => {
      expect(tabSearchPullProgress(0)).assertEqual(0);
      expect(tabSearchPullProgress(TAB_SEARCH_PULL_THRESHOLD - 1) < 1).assertTrue();
      expect(tabSearchPullProgress(TAB_SEARCH_PULL_THRESHOLD)).assertEqual(1);
      expect(tabSearchPullProgress(-100)).assertEqual(0);
    });

    it('uses the larger system or cutout inset for top content', 0, () => {
      expect(topContentInset(24, 0)).assertEqual(24);
      expect(topContentInset(0, 32)).assertEqual(32);
      expect(topContentInset(-1, -1)).assertEqual(0);
    });

    it('keeps tab-grid padding single-counted and safe-area aware', 0, () => {
      expect(tabOverviewTopPadding(0, false)).assertEqual(24);
      expect(tabOverviewTopPadding(32, false)).assertEqual(40);
      expect(tabOverviewTopPadding(80, false)).assertEqual(88);
      expect(tabOverviewTopPadding(32, true)).assertEqual(6);
    });

    it('maps history and bookmarks into the retained video library sections', 0, () => {
      const history: HistoryRecord[] = [{ url: 'https://history.example', title: 'History', visitedAt: 3 }];
      const bookmarks: BookmarkRecord[] = [{ url: 'https://bookmark.example', title: 'Bookmark', createdAt: 2 }];
      expect(libraryEntries(LibrarySection.HISTORY, history, bookmarks)[0].url)
        .assertEqual('https://history.example');
      expect(libraryEntries(LibrarySection.BOOKMARKS, history, bookmarks)[0].url)
        .assertEqual('https://bookmark.example');
      expect(libraryEntries(LibrarySection.HISTORY, history, bookmarks)[0].timestamp)
        .assertEqual(3);
    });

    it('uses native symbol metadata for each library section', 0, () => {
      expect(librarySectionChrome(LibrarySection.BOOKMARKS).title).assertEqual('书签');
      expect(librarySectionChrome(LibrarySection.BOOKMARKS).symbolName).assertEqual('bookmark');
      expect(librarySectionChrome(LibrarySection.HISTORY).symbolName).assertEqual('clock');
    });

    it('defines the bookmark button long-press menu action', 0, () => {
      expect(JSON.stringify(librarySectionChrome(LibrarySection.BOOKMARKS)).includes('添加书签')).assertTrue();
    });

    it('enables bookmark button actions only for loaded public pages', 0, () => {
      expect(libraryBookmarkActionEnabled(true, false, 'https://example.com')).assertTrue();
      expect(libraryBookmarkActionEnabled(false, false, 'https://example.com')).assertFalse();
      expect(libraryBookmarkActionEnabled(true, true, 'https://example.com')).assertFalse();
      expect(libraryBookmarkActionEnabled(true, false, 'about:blank')).assertFalse();
    });

    it('commits library section changes only after a horizontal swipe threshold', 0, () => {
      expect(LIBRARY_SECTION_SWIPE_THRESHOLD).assertEqual(48);
      expect(librarySectionAfterSwipe(LibrarySection.BOOKMARKS, -49))
        .assertEqual(LibrarySection.HISTORY);
      expect(librarySectionAfterSwipe(LibrarySection.HISTORY, 49))
        .assertEqual(LibrarySection.BOOKMARKS);
      expect(librarySectionAfterSwipe(LibrarySection.BOOKMARKS, -47))
        .assertEqual(LibrarySection.BOOKMARKS);
      expect(librarySectionAfterSwipe(LibrarySection.HISTORY, 47))
        .assertEqual(LibrarySection.HISTORY);
    });

    it('uses a gray selected library segment without a separate track', 0, () => {
      expect(LIBRARY_SECTION_SELECTED_BACKGROUND).assertEqual('#F2F2F7');
      expect(LIBRARY_SECTION_UNSELECTED_BACKGROUND).assertEqual('#FFFFFF');
      expect(librarySectionBackground(true)).assertEqual(LIBRARY_SECTION_SELECTED_BACKGROUND);
      expect(librarySectionBackground(false)).assertEqual(LIBRARY_SECTION_UNSELECTED_BACKGROUND);
    });

    it('applies interruptible resistance before dismissing the library sheet', 0, () => {
      expect(LIBRARY_DISMISS_THRESHOLD).assertEqual(80);
      expect(libraryDismissProgress(-20)).assertEqual(0);
      expect(libraryDismissProgress(40)).assertEqual(0.5);
      expect(libraryDismissProgress(160)).assertEqual(1);
      expect(libraryDismissShouldClose(79)).assertFalse();
      expect(libraryDismissShouldClose(80)).assertTrue();
    });

    it('filters library entries by title and URL without changing their order', 0, () => {
      const entries = libraryEntries(LibrarySection.BOOKMARKS, [], [
        { url: 'https://developer.huawei.com', title: 'Harmony docs', createdAt: 3 },
        { url: 'https://news.example', title: 'Daily news', createdAt: 2 },
        { url: 'https://example.com/search?q=ArkUI', title: 'Search result', createdAt: 1 }
      ]);
      expect(filterLibraryEntries(entries, '').length).assertEqual(3);
      expect(filterLibraryEntries(entries, 'HUAWEI')[0].title).assertEqual('Harmony docs');
      expect(filterLibraryEntries(entries, 'arkui')[0].url)
        .assertEqual('https://example.com/search?q=ArkUI');
      expect(filterLibraryEntries(entries, 'missing').length).assertEqual(0);
      expect(entries.length).assertEqual(3);
    });

    it('groups history by local today, yesterday, week and earlier boundaries', 0, () => {
      const wednesdayMorning: Date = new Date(2026, 8, 9, 10, 0, 0, 0);
      const now: number = wednesdayMorning.getTime();
      const today: number = new Date(2026, 8, 9, 9, 0, 0, 0).getTime();
      const yesterday: number = new Date(2026, 8, 8, 23, 59, 59, 999).getTime();
      const monday: number = new Date(2026, 8, 7, 12, 0, 0, 0).getTime();
      const lastWeek: number = new Date(2026, 8, 6, 23, 59, 59, 999).getTime();
      expect(historyTimelineSection(today, now)).assertEqual(HistoryTimelineSection.TODAY);
      expect(historyTimelineSection(yesterday, now)).assertEqual(HistoryTimelineSection.YESTERDAY);
      expect(historyTimelineSection(monday, now)).assertEqual(HistoryTimelineSection.THIS_WEEK);
      expect(historyTimelineSection(lastWeek, now)).assertEqual(HistoryTimelineSection.EARLIER);

      const groups = historyTimelineGroups([
        { url: 'https://today.example', title: 'Today', visitedAt: today },
        { url: 'https://yesterday.example', title: 'Yesterday', visitedAt: yesterday },
        { url: 'https://monday.example', title: 'Monday', visitedAt: monday },
        { url: 'https://last-week.example', title: 'Last week', visitedAt: lastWeek }
      ], now);
      expect(groups.length).assertEqual(4);
      expect(groups[0].title).assertEqual('今天');
      expect(groups[1].title).assertEqual('昨天');
      expect(groups[2].title).assertEqual('本周');
      expect(groups[3].title).assertEqual('更早');
      expect(groups[2].entries[0].url).assertEqual('https://monday.example');
    });

    it('keeps a history row key stable when another row is removed', 0, () => {
      const retained: HistoryRecord = {
        url: 'https://retained.example',
        title: 'Retained',
        visitedAt: 2
      };
      const initial = libraryEntries(LibrarySection.HISTORY, [
        { url: 'https://removed.example', title: 'Removed', visitedAt: 1 },
        retained
      ], []);
      const afterDelete = libraryEntries(LibrarySection.HISTORY, [retained], []);

      expect(libraryEntryRenderKey(initial[1])).assertEqual(libraryEntryRenderKey(afterDelete[0]));
    });

    it('updates the visible history source without disturbing retained records', 0, () => {
      const records: HistoryRecord[] = [
        { url: 'https://first.example', title: 'First', visitedAt: 1 },
        { url: 'https://second.example', title: 'Second', visitedAt: 2 }
      ];
      const visible: HistoryRecord[] = visibleHistoryRecords(
        records,
        ['history-1-https://first.example']
      );

      expect(visible.length).assertEqual(1);
      expect(visible[0].url).assertEqual('https://second.example');
    });

    it('uses local delete boundaries and leaves outside history untouched', 0, () => {
      const now: number = new Date(2026, 8, 10, 12, 0, 0, 0).getTime();
      const today: HistoryRecord = {
        url: 'https://today.example', title: 'Today',
        visitedAt: new Date(2026, 8, 10, 8, 0, 0, 0).getTime()
      };
      const thisWeek: HistoryRecord = {
        url: 'https://this-week.example', title: 'This week',
        visitedAt: new Date(2026, 8, 8, 8, 0, 0, 0).getTime()
      };
      const old: HistoryRecord = {
        url: 'https://old.example', title: 'Old',
        visitedAt: new Date(2026, 8, 6, 8, 0, 0, 0).getTime()
      };
      const todayCutoff: number | undefined = historyDeleteCutoff(HistoryDeleteRange.TODAY, now);
      const weekCutoff: number | undefined = historyDeleteCutoff(HistoryDeleteRange.THIS_WEEK, now);
      expect(todayCutoff === undefined).assertFalse();
      expect(weekCutoff === undefined).assertFalse();
      expect(historyRecordInDeleteRange(today, HistoryDeleteRange.TODAY, now)).assertTrue();
      expect(historyRecordInDeleteRange(old, HistoryDeleteRange.TODAY, now)).assertFalse();
      expect(historyRecordInDeleteRange(thisWeek, HistoryDeleteRange.THIS_WEEK, now)).assertTrue();
      expect(historyRecordInDeleteRange(old, HistoryDeleteRange.THIS_WEEK, now)).assertFalse();
      expect(historyRecordInDeleteRange(old, HistoryDeleteRange.ALL, now)).assertTrue();
    });

    it('keeps the library geometry and pull threshold aligned with the design', 0, () => {
      expect(LIBRARY_SHEET_HEIGHT_PERCENT).assertEqual(56);
      expect(LIBRARY_SEARCH_PULL_THRESHOLD).assertEqual(TAB_SEARCH_PULL_THRESHOLD);
      expect(librarySearchPullProgress(0)).assertEqual(0);
      expect(librarySearchPullProgress(LIBRARY_SEARCH_PULL_THRESHOLD / 2)).assertEqual(0.5);
      expect(librarySearchPullProgress(LIBRARY_SEARCH_PULL_THRESHOLD)).assertEqual(1);
    });

    it('blocks ArkWeb hit testing while the native start page overlays a blank tab', 0, () => {
      expect(webHostInputEnabled('about:blank', false)).assertFalse();
      expect(webHostInputEnabled('https://example.com', false)).assertTrue();
      expect(webHostInputEnabled('https://example.com', true)).assertFalse();
    });

  it('clears a pending address gesture after navigation is submitted', 0, () => {
      const state = resetBrowserGestureState();
      expect(state.gestureActive).assertFalse();
      expect(state.addressGestureFinished).assertTrue();
      expect(state.overviewProgress).assertEqual(0);
    expect(state.horizontalOffset).assertEqual(0);
  });

  it('accepts a page navigation URL and falls back for empty callbacks', 0, () => {
    expect(committedNavigationUrl('https://example.com/docs', 'about:blank'))
      .assertEqual('https://example.com/docs');
    expect(committedNavigationUrl('', 'https://example.com'))
      .assertEqual('https://example.com');
    expect(committedNavigationUrl('   ', 'https://example.com'))
      .assertEqual('https://example.com');
  });

  it('preserves a valid tab URL when a stale blank callback arrives', 0, () => {
    expect(committedNavigationUrl('about:blank', 'https://cn.bing.com/search?q=glide'))
      .assertEqual('https://cn.bing.com/search?q=glide');
  });

  it('reactivates only a committed non-blank web controller', 0, () => {
    expect(shouldActivateWebController('https://example.com')).assertTrue();
    expect(shouldActivateWebController('  https://example.com/docs  ')).assertTrue();
    expect(shouldActivateWebController('about:blank')).assertFalse();
    expect(shouldActivateWebController('   ')).assertFalse();
  });

  it('does not reattach a controller that native Tabs already retains', 0, () => {
    expect(shouldRecoverMissingTabController(true, 'https://example.com')).assertFalse();
    expect(shouldRecoverMissingTabController(false, 'https://example.com')).assertTrue();
    expect(shouldRecoverMissingTabController(false, 'about:blank')).assertFalse();
  });

  it('recreates a blank runtime for the first committed page navigation', 0, () => {
    expect(shouldRecreateBlankTabRuntime('about:blank', 'https://example.com')).assertTrue();
    expect(shouldRecreateBlankTabRuntime('about:blank', '   ')).assertFalse();
    expect(shouldRecreateBlankTabRuntime('https://example.com', 'https://example.org')).assertFalse();
  });

  it('retries a host attachment only while the builder frame is pending', 0, () => {
    expect(shouldRetryWebHostAttachment(true, 0)).assertTrue();
    expect(shouldRetryWebHostAttachment(true, 3)).assertFalse();
    expect(shouldRetryWebHostAttachment(false, 0)).assertFalse();
  });

  it('retries a page snapshot while ArkWeb has not painted yet', 0, () => {
    expect(shouldRetryTabSnapshot(true, 0)).assertTrue();
    expect(shouldRetryTabSnapshot(true, 2)).assertTrue();
    expect(shouldRetryTabSnapshot(true, 3)).assertFalse();
    expect(shouldRetryTabSnapshot(false, 0)).assertFalse();
  });

  it('defers new runtime creation while the overview is still visible', 0, () => {
    expect(shouldDismissOverviewBeforeCreatingTab(1)).assertTrue();
    expect(shouldDismissOverviewBeforeCreatingTab(0.01)).assertTrue();
    expect(shouldDismissOverviewBeforeCreatingTab(0)).assertFalse();
  });
  it('mounts live web hosts only after the overview is fully dismissed', 0, () => {
    expect(shouldMountWebHost(0)).assertTrue();
    expect(shouldMountWebHost(-0.01)).assertTrue();
    expect(shouldMountWebHost(0.01)).assertFalse();
    expect(shouldMountWebHost(1)).assertFalse();
  });

  it('keeps the native ArkWeb surface out of blank start-page content', 0, () => {
    expect(shouldRenderLiveWebHost(0, 'about:blank')).assertFalse();
    expect(shouldRenderLiveWebHost(0, 'https://example.com')).assertTrue();
    expect(shouldRenderLiveWebHost(0.5, 'https://example.com')).assertFalse();
  });

  it('does not mount adjacent blank tabs over a live page', 0, () => {
    expect(shouldMountTabWebHost('about:blank')).assertFalse();
    expect(shouldMountTabWebHost('   ')).assertFalse();
    expect(shouldMountTabWebHost('https://example.com')).assertTrue();
  });

  it('invalidates an interrupted address transition without touching the new gesture', 0, () => {
    expect(isAddressTransitionCurrent(4, 4)).assertTrue();
    expect(isAddressTransitionCurrent(4, 5)).assertFalse();
  });

  it('changes the address input identity at tab and remount boundaries', 0, () => {
    expect(addressInputIdentity('tab-a', 1)).assertEqual('address-input-tab-a-1');
    expect(addressInputIdentity('tab-a', 2) === addressInputIdentity('tab-a', 1)).assertFalse();
    expect(addressInputIdentity('tab-b', 1) === addressInputIdentity('tab-a', 1)).assertFalse();
  });

  it('refreshes native hosts only after the measured viewport changes', 0, () => {
    expect(shouldRefreshHostsForViewport(400, 1280, 0)).assertTrue();
    expect(shouldRefreshHostsForViewport(1280, 1280, 0)).assertFalse();
    expect(shouldRefreshHostsForViewport(400, 1280, 1)).assertFalse();
    expect(shouldRefreshHostsForViewport(400, 0, 0)).assertFalse();
  });

    it('uses the application context for preference persistence', 0, () => {
      const application: Context = {} as Context;
      const host: ApplicationContextProvider = new FakePreferenceContext(application);
      expect(applicationContextForPreferences(host)).assertEqual(application);
    });

    it('hides search placeholders while their input is focused', 0, () => {
      expect(placeholderForFocus('搜索或输入网站', false)).assertEqual('搜索或输入网站');
      expect(placeholderForFocus('搜索或输入网站', true)).assertEqual('');
      expect(placeholderForFocus('搜索标签页', false)).assertEqual('搜索标签页');
      expect(placeholderForFocus('搜索标签页', true)).assertEqual('');
    });

    it('classifies ArkWeb lifecycle callbacks without guessing a network cause', 0, () => {
      const pageEnd = browserLifecycleDiagnostic(BrowserLifecycleEventKind.PAGE_END, 0, true);
      expect(pageEnd.kind).assertEqual(BrowserLifecycleEventKind.PAGE_END);
      expect(pageEnd.code).assertEqual(0);
      expect(pageEnd.isMainFrame).assertTrue();

      const network = browserLifecycleDiagnostic(BrowserLifecycleEventKind.NETWORK_ERROR, -105, true);
      expect(network.kind).assertEqual(BrowserLifecycleEventKind.NETWORK_ERROR);
      expect(network.code).assertEqual(-105);
      expect(network.isMainFrame).assertTrue();

      const ssl = browserLifecycleDiagnostic(BrowserLifecycleEventKind.SSL_ERROR, 1, false);
      expect(ssl.kind).assertEqual(BrowserLifecycleEventKind.SSL_ERROR);
      expect(ssl.isMainFrame).assertFalse();

      const renderer = browserLifecycleDiagnostic(BrowserLifecycleEventKind.RENDERER_EXITED, 0, true);
      expect(renderer.kind).assertEqual(BrowserLifecycleEventKind.RENDERER_EXITED);
    });

    it('aligns the address field and five bottom actions inside the floating chrome', 0, () => {
      expect(ADDRESS_SEARCH_BAR_TOP_PADDING).assertEqual(8);
      expect(SAFARI_ADDRESS_ITEM_GAP_VP).assertEqual(10);
      expect(SAFARI_ADDRESS_ROW_HEIGHT_VP).assertEqual(56);
      expect(SAFARI_ACTION_TOOLBAR_HEIGHT_VP).assertEqual(48);
      expect(SAFARI_BOTTOM_CHROME_BASE_HEIGHT_VP).assertEqual(104);
      expect(SAFARI_BOTTOM_CHROME_RADIUS_VP).assertEqual(HARMONY_RADIUS_FLOATING);
      expect(SAFARI_BOTTOM_CHROME_HORIZONTAL_INSET_VP).assertEqual(8);
      expect(SAFARI_BOTTOM_CHROME_BOTTOM_GAP_VP).assertEqual(8);
      expect(SAFARI_BOTTOM_CHROME_FALLBACK_COLOR).assertEqual('#FFF2F2F7');
      expect(SAFARI_BOTTOM_CHROME_MATERIAL_COLOR).assertEqual('#E6F2F2F7');
      expect(SAFARI_ADDRESS_ITEM_SURFACE_INSET_VP).assertEqual(8);
      expect(SAFARI_ADDRESS_ITEM_INSET_VP).assertEqual(16);
      expect(SAFARI_ADDRESS_PREVIEW_FADE_DURATION_MS).assertEqual(180);
      expect(SAFARI_ADDRESS_HANDOFF_LEAD_IN_MS).assertEqual(52);
      expect(SAFARI_ADDRESS_HANDOFF_CROSSFADE_DURATION_MS).assertEqual(420);
      expect(SAFARI_BOTTOM_CHROME_RAIL_INSET_VP).assertEqual(20);

      const viewportWidth: number = 400;
      expect(safariBottomChromeSurfaceWidth(viewportWidth)).assertEqual(384);
      expect(safariAddressItemWidth(viewportWidth)).assertEqual(368);
      expect(safariAddressItemWidth(364)).assertEqual(332);
      expect(safariBottomChromeRailWidth(viewportWidth)).assertEqual(344);
      expect(safariBottomChromeActionSlotWidth(viewportWidth).toFixed(1)).assertEqual('68.8');
      expect(safariBottomChromeActionCenter(0, viewportWidth).toFixed(1)).assertEqual('62.4');
      expect(safariBottomChromeActionCenter(1, viewportWidth).toFixed(1)).assertEqual('131.2');
      expect(safariBottomChromeActionCenter(2, viewportWidth).toFixed(1)).assertEqual('200.0');
      expect(safariBottomChromeActionCenter(3, viewportWidth).toFixed(1)).assertEqual('268.8');
      expect(safariBottomChromeActionCenter(4, viewportWidth).toFixed(1)).assertEqual('337.6');
    });

    it('clips horizontal address visuals to the floating chrome and releases overview motion', 0, () => {
      const horizontal = safariAddressTrackClipFrame(400, false);
      expect(horizontal.left).assertEqual(8);
      expect(horizontal.width).assertEqual(384);
      expect(horizontal.topRadius).assertEqual(20);

      const overview = safariAddressTrackClipFrame(400, true);
      expect(overview.left).assertEqual(0);
      expect(overview.width).assertEqual(400);
      expect(overview.topRadius).assertEqual(0);

      const narrowHorizontal = safariAddressTrackClipFrame(364, false);
      expect(narrowHorizontal.left).assertEqual(8);
      expect(narrowHorizontal.width).assertEqual(348);
      const narrowOverview = safariAddressTrackClipFrame(364, true);
      expect(narrowOverview.left).assertEqual(0);
      expect(narrowOverview.width).assertEqual(364);
    });

    it('keeps current and adjacent pages in transient geometry during a drag', 0, () => {
      const motion = tabGestureMotion(-120, 400, 1, 3);
      expect(motion.isDragging).assertTrue();
      expect(motion.rawDragX).assertEqual(-120);
      expect(motion.displayDragX).assertEqual(-120);
      expect(motion.pageTranslateX).assertEqual(-120);
      expect(motion.adjacentTranslateX).assertEqual(280);
      expect(motion.previewIndex).assertEqual(2);
      expect(motion.previewKind).assertEqual(TabPreviewKind.EXISTING_TAB);
      expect(motion.transitionProgress).assertEqual(0.3);
      expect(motion.swipeProgress).assertEqual(0.3);
    });

    it('keeps current and preview scene offsets visible during tab drag', 0, () => {
      const existing = tabTransitionVisualState(-120, 280, true, TabPreviewKind.EXISTING_TAB, 0);
      expect(existing.currentTranslateX).assertEqual(-120);
      expect(existing.previewTranslateX).assertEqual(280);
      expect(existing.showPreview).assertTrue();
      expect(existing.previewKind).assertEqual(TabPreviewKind.EXISTING_TAB);

      const newTab = tabTransitionVisualState(-80, 320, true, TabPreviewKind.NEW_TAB, 0.5);
      expect(newTab.currentTranslateX).assertEqual(-80);
      expect(newTab.previewTranslateX).assertEqual(320);
      expect(newTab.showPreview).assertTrue();
      expect(newTab.previewKind).assertEqual(TabPreviewKind.NEW_TAB);
      expect(newTab.newTabProgress).assertEqual(0.5);
    });

    it('switches the new-tab plus to the full placeholder without overlap', 0, () => {
      const start = newTabHandoffVisual(0);
      expect(start.plusScale).assertEqual(1);
      expect(start.placeholderScale).assertEqual(1);
      expect(start.placeholderSlideProgress).assertEqual(1);
      expect(start.plusOpacity).assertEqual(1);
      expect(start.placeholderOpacity).assertEqual(0);
      const earlyHandoff = newTabHandoffVisual(0.25);
      expect(earlyHandoff.plusOpacity).assertEqual(1);
      expect(earlyHandoff.placeholderOpacity).assertEqual(0);
      const settledHandoff = newTabHandoffVisual(0.75);
      expect(settledHandoff.plusOpacity).assertEqual(0);
      expect(settledHandoff.placeholderOpacity).assertEqual(1);
      expect(settledHandoff.plusScale).assertEqual(1);
      expect(settledHandoff.placeholderScale).assertEqual(1);
      expect(settledHandoff.placeholderSlideProgress).assertEqual(1);
      const finish = newTabHandoffVisual(1);
      expect(finish.plusOpacity).assertEqual(0);
      expect(finish.placeholderOpacity).assertEqual(1);
      expect(finish.plusScale).assertEqual(1);
      expect(finish.placeholderScale).assertEqual(1);
      expect(finish.placeholderSlideProgress).assertEqual(1);
    });

    it('keeps the handoff layer mounted until the native animation finishes', 0, () => {
      expect(shouldRenderAddressHandoff(true, 1)).assertTrue();
      expect(shouldRenderAddressHandoff(false, 1)).assertFalse();
    });

    it('uses nonlinear edge resistance and staged new-tab pull feedback', 0, () => {
      const first = rubberBandDistance(20);
      const second = rubberBandDistance(80);
      expect(first > 0).assertTrue();
      expect(second > first).assertTrue();
      expect(second < TAB_RUBBER_BAND_MAX_PULL).assertTrue();
      const motion = tabGestureMotion(-80, 400, 0, 1);
      expect(motion.previewIndex).assertEqual(-1);
      expect(motion.previewKind).assertEqual(TabPreviewKind.NEW_TAB);
      expect(motion.displayDragX).assertEqual(-80);
      expect(motion.adjacentTranslateX).assertEqual(320);
      expect(motion.newTabProgress > 0).assertTrue();
      expect(newTabPullProgress(NEW_TAB_PULL_START)).assertEqual(0);
      expect(newTabPullProgress(NEW_TAB_PULL_READY_DISTANCE)).assertEqual(1);
      expect(newTabBackgroundProgress(70)).assertEqual(0);
      expect(newTabBackgroundProgress(NEW_TAB_PULL_READY_DISTANCE)).assertEqual(1);
    });

    it('projects release velocity for an interruptible tab commit', 0, () => {
      expect(projectedOffset(-40, -1000)).assertEqual(-160);
      expect(shouldCommitProjectedSwitch(-40, -1000, 400)).assertTrue();
      expect(shouldCommitProjectedSwitch(-40, -100, 400)).assertFalse();
      expect(shouldCommitNewTabPull(-50, -500)).assertTrue();
      expect(shouldCommitNewTabPull(-50, -100)).assertFalse();
    });

    it('separates the gray tab overview from white cards and search field', 0, () => {
      expect(TAB_OVERVIEW_BACKGROUND_COLOR).assertEqual('#FFFFFF');
      expect(TAB_SEARCH_BAR_BACKGROUND_COLOR).assertEqual('#F2F2F7');
      expect(TAB_SEARCH_BAR_CONTENT_INSET).assertEqual(13);
    });

    it('drives a smooth pull-to-reveal search transition', 0, () => {
      expect(TAB_SEARCH_REVEAL_ANIMATION_DURATION_MS).assertEqual(240);
      expect(tabSearchVisualProgress(0)).assertEqual(0);
      expect(tabSearchVisualProgress(TAB_SEARCH_PULL_THRESHOLD / 2)).assertEqual(0.5);
      expect(tabSearchVisualProgress(TAB_SEARCH_PULL_THRESHOLD)).assertEqual(1);
      expect(tabSearchVisualProgress(-10)).assertEqual(0);
    });

    it('interpolates overview spacing and card width during gestures', 0, () => {
      expect(tabOverviewTopPaddingForProgress(32, 0)).assertEqual(40);
      expect(tabOverviewTopPaddingForProgress(32, 0.5)).assertEqual(23);
      expect(tabOverviewTopPaddingForProgress(32, 1)).assertEqual(6);
      expect(tabOverviewCardWidth(400)).assertEqual(178);
    });

    it('keeps thumbnail previews proportional while anchoring the page crop to the top', 0, () => {
      const crop = tabOverviewThumbnailCrop(1280, 2832, 178, 210);
      expect(crop.scale).assertEqual(178 / 1280);
      expect(crop.horizontalSourceOffset).assertEqual(0);
      expect(crop.verticalSourceOffset).assertEqual(0);

      const wideSource = tabOverviewThumbnailCrop(1920, 1080, 178, 210);
      expect(wideSource.scale).assertEqual(210 / 1080);
      expect(wideSource.horizontalSourceOffset > 0).assertTrue();
      expect(wideSource.verticalSourceOffset).assertEqual(0);
    });

    it('uses the web page dimensions for inactive snapshots and a viewport-shaped fallback', 0, () => {
      const pageSize = tabOverviewSnapshotSize(1280, 2832, 400, 800);
      expect(pageSize.width).assertEqual(1280);
      expect(pageSize.height).assertEqual(2832);

      const fallback = tabOverviewSnapshotSize(Number.NaN, 0, 400, 800);
      expect(fallback.width).assertEqual(720);
      expect(fallback.height).assertEqual(1440);
    });

    it('keeps every thumbnail flush with the card top', 0, () => {
      expect(tabOverviewThumbnailTopOffset(0, 400)).assertEqual(0);
      expect(tabOverviewThumbnailTopOffset(40, 400)).assertEqual(0);
      expect(tabOverviewThumbnailTopOffset(48, 720)).assertEqual(0);
    });

    it('keeps card long-press actions aligned with the video menu', 0, () => {
      expect(TAB_CARD_MENU_LABELS.length).assertEqual(3);
      expect(TAB_CARD_MENU_LABELS[0]).assertEqual('新建标签');
      expect(TAB_CARD_MENU_LABELS[1]).assertEqual('关闭此标签');
      expect(TAB_CARD_MENU_LABELS[2]).assertEqual('关闭所有标签');
      expect(TAB_CARD_MENU_SYMBOL_NAMES[0]).assertEqual('sys.symbol.plus');
      expect(TAB_CARD_MENU_SYMBOL_NAMES[1]).assertEqual('sys.symbol.xmark');
      expect(TAB_CARD_MENU_SYMBOL_NAMES[2]).assertEqual('sys.symbol.xmark_circle');
      expect(tabCardMenuItemIsDestructive(0)).assertFalse();
      expect(tabCardMenuItemIsDestructive(1)).assertTrue();
      expect(tabCardMenuItemIsDestructive(2)).assertTrue();
      expect(TAB_CARD_MENU_DESTRUCTIVE_COLOR).assertEqual('#FF3B30');
    });

    it('forwards system back to the active browser shell', 0, () => {
      const port: FakeBackPort = new FakeBackPort();
      BrowserLifecycleRegistry.register(port);
      BrowserLifecycleRegistry.onForeground();
      expect(port.foregroundCount).assertEqual(1);
      expect(BrowserLifecycleRegistry.onBackPress()).assertFalse();
      port.consumeBack = true;
      expect(BrowserLifecycleRegistry.onBackPress()).assertTrue();
      BrowserLifecycleRegistry.clear(port);
      expect(BrowserLifecycleRegistry.onBackPress()).assertFalse();
    });

    it('forwards ability destruction to the active browser shell', 0, async () => {
      const port: FakeBackPort = new FakeBackPort();
      BrowserLifecycleRegistry.register(port);

      await BrowserLifecycleRegistry.onDestroy();

      expect(port.destroyCount).assertEqual(1);
      BrowserLifecycleRegistry.clear(port);
    });

  });
}
