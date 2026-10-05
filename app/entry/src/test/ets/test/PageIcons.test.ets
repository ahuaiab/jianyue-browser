import { describe, expect, it } from '@ohos/hypium';
import { image } from '@kit.ImageKit';
import { BrowserRepository } from '../../../main/ets/browser/data/BrowserRepository';
import { KeyValueStore } from '../../../main/ets/browser/data/KeyValueStore';
import {
  PageIconFallbackFetcher,
  PageIconFileStorePort,
  PageIconHttpPort,
  PageIconHttpResponse,
  PageIconImageDecoderPort
} from '../../../main/ets/browser/data/PageIconFallbackFetcher';
import {
  PageIconFallbackCoordinator,
  PageIconFallbackWork
} from '../../../main/ets/browser/data/PageIconFallbackCoordinator';
import { ensurePageIconDirectory } from '../../../main/ets/browser/data/PageIconDirectory';
import {
  historyTimelineGroups,
  libraryEntries,
  LibrarySection
} from '../../../main/ets/browser/model/LibraryModels';
import {
  PageIconRecord,
  pageIconSiteKeyForUrl,
  pageIconPathForUrl,
  upsertPageIconRecord,
  validPageIconRecord
} from '../../../main/ets/browser/model/PageIconModels';
import {
  resolveDeclaredPageIconUrl,
  resolveDefaultPageIconUrl,
  resolvePageIconHref
} from '../../../main/ets/browser/model/PageIconUrlResolver';
import {
  PageIconDiagnosticEvent,
  PageIconDiagnostics,
  PageIconDiagnosticStage,
  PageIconFailureCategory,
  pageIconDiagnosticHostForUrl
} from '../../../main/ets/browser/model/PageIconDiagnostics';

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

class FakePageIconHttpPort implements PageIconHttpPort {
  readonly textResponses: Map<string, PageIconHttpResponse> = new Map();
  readonly byteResponses: Map<string, PageIconHttpResponse> = new Map();
  readonly textFailures: Set<string> = new Set();
  readonly byteFailures: Set<string> = new Set();
  readonly textUrls: string[] = [];
  readonly byteUrls: string[] = [];

  async requestText(url: string): Promise<PageIconHttpResponse> {
    this.textUrls.push(url);
    if (this.textFailures.has(url)) {
      throw new Error('fake page request failure');
    }
    return this.textResponses.get(url) ?? { responseCode: 404 };
  }

  async requestBytes(url: string): Promise<PageIconHttpResponse> {
    this.byteUrls.push(url);
    if (this.byteFailures.has(url)) {
      throw new Error('fake icon request failure');
    }
    return this.byteResponses.get(url) ?? { responseCode: 404 };
  }
}

class FakePageIconImageDecoder implements PageIconImageDecoderPort {
  private readonly pixelMap: image.PixelMap = {} as image.PixelMap;
  shouldFail: boolean = false;
  decodeCount: number = 0;

  async decode(_bytes: ArrayBuffer): Promise<image.PixelMap> {
    this.decodeCount += 1;
    if (this.shouldFail) {
      throw new Error('fake invalid image');
    }
    return this.pixelMap;
  }
}

class FakePageIconFileStore implements PageIconFileStorePort {
  savePath: string | undefined = '/cache/site-icon.png';
  fileExists: boolean = true;
  savedUrl: string = '';

  async save(url: string, _pixelMap: image.PixelMap): Promise<string | undefined> {
    this.savedUrl = url;
    return this.savePath;
  }

  exists(path: string): boolean {
    return this.fileExists && path === this.savePath;
  }
}

class FakeFileOperationError extends Error {
  readonly code: number;

  constructor(code: number) {
    super('fake file operation error');
    this.code = code;
  }
}

function createTestPageIconFetcher(
  http: FakePageIconHttpPort,
  decoder: FakePageIconImageDecoder,
  fileStore: FakePageIconFileStore,
  events: PageIconDiagnosticEvent[]
): PageIconFallbackFetcher {
  const diagnostics: PageIconDiagnostics = new PageIconDiagnostics(
    (event: PageIconDiagnosticEvent): void => {
      events.push(event);
    }
  );
  return new PageIconFallbackFetcher(http, decoder, fileStore, diagnostics);
}

async function flushPageIconCoordinator(): Promise<void> {
  await Promise.resolve();
  await Promise.resolve();
}

export default function pageIconsTest() {
  describe('PageIcons', () => {
    it('skips creating the icon directory when it already exists', 0, () => {
      let mkdirCount: number = 0;
      ensurePageIconDirectory(
        (): boolean => true,
        (): void => { mkdirCount += 1; }
      );

      expect(mkdirCount).assertEqual(0);
    });

    it('creates the icon directory when it is missing', 0, () => {
      let directoryExists: boolean = false;
      let mkdirCount: number = 0;
      ensurePageIconDirectory(
        (): boolean => {
          if (!directoryExists) {
            throw new FakeFileOperationError(13900002);
          }
          return true;
        },
        (): void => {
          mkdirCount += 1;
          directoryExists = true;
        }
      );

      expect(directoryExists).assertTrue();
      expect(mkdirCount).assertEqual(1);
    });

    it('accepts a concurrent directory creation only after rechecking it', 0, () => {
      let directoryExists: boolean = false;
      let mkdirCount: number = 0;
      ensurePageIconDirectory(
        (): boolean => {
          if (!directoryExists) {
            throw new FakeFileOperationError(13900002);
          }
          return true;
        },
        (): void => {
          mkdirCount += 1;
          directoryExists = true;
          throw new FakeFileOperationError(13900015);
        }
      );

      expect(mkdirCount).assertEqual(1);
    });

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

    it('parses icon links regardless of tag, attribute order, and case', 0, () => {
      const pageUrl: string = 'https://news.bjd.com.cn/news/2026/story.html';
      const html: string = '<LINK href="icons/bjd.png" sizes="32x32" REL="SHORTCUT ICON">';
      expect(resolveDeclaredPageIconUrl(pageUrl, html))
        .assertEqual('https://news.bjd.com.cn/news/2026/icons/bjd.png');
    });

    it('skips unsafe icon candidates and chooses the first usable icon', 0, () => {
      const pageUrl: string = 'https://news.bjd.com.cn/article';
      const html: string = '<link rel="icon" href="javascript:alert(1)">' +
        '<link href="https://static.bjd.com.cn/favicon.png" rel="icon">';

      expect(resolveDeclaredPageIconUrl(pageUrl, html))
        .assertEqual('https://static.bjd.com.cn/favicon.png');
    });

    it('ignores icon tags inside HTML comments', 0, () => {
      const pageUrl: string = 'https://news.bjd.com.cn/article';
      const html: string = '<!-- <link rel="icon" href="https://wrong.example/icon.png"> -->' +
        '<link rel="icon" href="/right.png">';

      expect(resolveDeclaredPageIconUrl(pageUrl, html))
        .assertEqual('https://news.bjd.com.cn/right.png');
    });

    it('resolves protocol-relative icons using the page protocol', 0, () => {
      expect(resolvePageIconHref('https://news.bjd.com.cn/article', '//cdn.example.com/icon.png'))
        .assertEqual('https://cdn.example.com/icon.png');
      expect(resolvePageIconHref('http://news.bjd.com.cn/article', '//cdn.example.com/icon.png'))
        .assertEqual('http://cdn.example.com/icon.png');
      expect(resolvePageIconHref(
        'https://news.bjd.com.cn/news/2026/story.html', '../icons/site.png'
      )).assertEqual('https://news.bjd.com.cn/news/icons/site.png');
      expect(resolvePageIconHref('https://news.bjd.com.cn/news//page', 'icon.png'))
        .assertEqual('https://news.bjd.com.cn/news//icon.png');
    });

    it('rejects non-web icon schemes and HTTPS to HTTP downgrade', 0, () => {
      expect(resolvePageIconHref('https://news.bjd.com.cn/', 'javascript:alert(1)'))
        .assertUndefined();
      expect(resolvePageIconHref('https://news.bjd.com.cn/', 'data:image/png;base64,AAAA'))
        .assertUndefined();
      expect(resolvePageIconHref('https://news.bjd.com.cn/', 'http://cdn.example.com/icon.png'))
        .assertUndefined();
    });

    it('builds the default favicon candidate from the page origin', 0, () => {
      expect(resolveDefaultPageIconUrl('https://news.bjd.com.cn:8443/news/page?id=private#part'))
        .assertEqual('https://news.bjd.com.cn:8443/favicon.ico');
      expect(resolveDefaultPageIconUrl('file:///news/page')).assertUndefined();
    });

    it('exports the existing site key behavior without changing its scheme and authority rules', 0, () => {
      expect(pageIconSiteKeyForUrl('HTTPS://NEWS.BJD.COM.CN:8443/news?id=1#part'))
        .assertEqual('https://news.bjd.com.cn:8443');
      expect(pageIconSiteKeyForUrl('data:text/plain,private')).assertEqual('');
    });

    it('reduces page URLs to a host before recording diagnostics', 0, () => {
      expect(pageIconDiagnosticHostForUrl(
        'https://user:password@news.bjd.com.cn:8443/article?token=secret#part'
      )).assertEqual('news.bjd.com.cn');

      const events: PageIconDiagnosticEvent[] = [];
      const diagnostics: PageIconDiagnostics = new PageIconDiagnostics(
        (event: PageIconDiagnosticEvent): void => {
          events.push(event);
        }
      );
      diagnostics.record(
        PageIconDiagnosticStage.FALLBACK_START,
        'https://user:password@news.bjd.com.cn:8443/article?token=secret#part'
      );
      diagnostics.record(
        PageIconDiagnosticStage.ICON_RESPONSE,
        'https://news.bjd.com.cn/article?token=secret',
        PageIconFailureCategory.HTTP_STATUS
      );

      expect(events.length).assertEqual(2);
      expect(events[0].host).assertEqual('news.bjd.com.cn');
      expect(events[0].category).assertUndefined();
      expect(events[1].host).assertEqual('news.bjd.com.cn');
      expect(events[1].category).assertEqual(PageIconFailureCategory.HTTP_STATUS);
    });

    it('fetches a declared cross-site icon and associates it with the original page URL', 0, async () => {
      const pageUrl: string = 'https://news.bjd.com.cn/news/story?token=private#section';
      const pageRequestUrl: string = 'https://news.bjd.com.cn/news/story';
      const iconUrl: string = 'https://static.bjd.com.cn/icons/site.png';
      const http: FakePageIconHttpPort = new FakePageIconHttpPort();
      http.textResponses.set(pageRequestUrl, {
        responseCode: 200,
        textBody: '<link rel="icon" href="https://static.bjd.com.cn/icons/site.png">'
      });
      http.byteResponses.set(iconUrl, { responseCode: 200, binaryBody: new ArrayBuffer(8) });
      const decoder: FakePageIconImageDecoder = new FakePageIconImageDecoder();
      const fileStore: FakePageIconFileStore = new FakePageIconFileStore();
      const events: PageIconDiagnosticEvent[] = [];
      const fetcher: PageIconFallbackFetcher =
        createTestPageIconFetcher(http, decoder, fileStore, events);

      const record: PageIconRecord | undefined = await fetcher.fetch(pageUrl);

      expect(http.textUrls.length).assertEqual(1);
      expect(http.textUrls[0]).assertEqual(pageRequestUrl);
      expect(http.byteUrls.length).assertEqual(1);
      expect(http.byteUrls[0]).assertEqual(iconUrl);
      expect(decoder.decodeCount).assertEqual(1);
      expect(fileStore.savedUrl).assertEqual(pageUrl);
      expect(record?.url).assertEqual(pageUrl);
      expect(record?.localPath).assertEqual('/cache/site-icon.png');
      expect(events[0].host).assertEqual('news.bjd.com.cn');
      expect(events[2].host).assertEqual('static.bjd.com.cn');
      expect(events[events.length - 1].host).assertEqual('news.bjd.com.cn');
      expect(events[0].host.indexOf('private')).assertEqual(-1);
    });

    it('tries the site-root favicon when the page declares no icon', 0, async () => {
      const pageUrl: string = 'http://example.org/news/page?from=history#top';
      const pageRequestUrl: string = 'http://example.org/news/page';
      const defaultIconUrl: string = 'http://example.org/favicon.ico';
      const http: FakePageIconHttpPort = new FakePageIconHttpPort();
      http.textResponses.set(pageRequestUrl, { responseCode: 200, textBody: '<html></html>' });
      http.byteResponses.set(defaultIconUrl, {
        responseCode: 200,
        binaryBody: new ArrayBuffer(4)
      });
      const decoder: FakePageIconImageDecoder = new FakePageIconImageDecoder();
      const fileStore: FakePageIconFileStore = new FakePageIconFileStore();
      const events: PageIconDiagnosticEvent[] = [];
      const fetcher: PageIconFallbackFetcher =
        createTestPageIconFetcher(http, decoder, fileStore, events);

      const record: PageIconRecord | undefined = await fetcher.fetch(pageUrl);

      expect(http.textUrls[0]).assertEqual(pageRequestUrl);
      expect(http.byteUrls[0]).assertEqual(defaultIconUrl);
      expect(record?.url).assertEqual(pageUrl);
    });

    it('tries every declared icon before falling back to the site-root favicon', 0, async () => {
      const pageUrl: string = 'https://multi-icon.example/article';
      const firstIconUrl: string = 'https://multi-icon.example/broken.ico';
      const secondIconUrl: string = 'https://multi-icon.example/alternate.png';
      const defaultIconUrl: string = 'https://multi-icon.example/favicon.ico';
      const http: FakePageIconHttpPort = new FakePageIconHttpPort();
      http.textResponses.set(pageUrl, {
        responseCode: 200,
        textBody: '<link rel="icon" href="/broken.ico">' +
          '<link rel="shortcut icon" href="/alternate.png">'
      });
      http.byteResponses.set(firstIconUrl, { responseCode: 404 });
      http.byteResponses.set(secondIconUrl, { responseCode: 404 });
      http.byteResponses.set(defaultIconUrl, {
        responseCode: 200,
        binaryBody: new ArrayBuffer(4)
      });
      const decoder: FakePageIconImageDecoder = new FakePageIconImageDecoder();
      const fileStore: FakePageIconFileStore = new FakePageIconFileStore();
      const events: PageIconDiagnosticEvent[] = [];
      const fetcher: PageIconFallbackFetcher =
        createTestPageIconFetcher(http, decoder, fileStore, events);

      const record: PageIconRecord | undefined = await fetcher.fetch(pageUrl);

      expect(http.byteUrls.length).assertEqual(3);
      expect(http.byteUrls[0]).assertEqual(firstIconUrl);
      expect(http.byteUrls[1]).assertEqual(secondIconUrl);
      expect(http.byteUrls[2]).assertEqual(defaultIconUrl);
      expect(decoder.decodeCount).assertEqual(1);
      expect(fileStore.savedUrl).assertEqual(pageUrl);
      expect(record?.localPath).assertEqual('/cache/site-icon.png');
    });

    it('uses a later declared site icon when the first candidate is unavailable', 0, async () => {
      const pageUrl: string = 'https://alternate-icon.example/article';
      const firstIconUrl: string = 'https://alternate-icon.example/missing.ico';
      const secondIconUrl: string = 'https://alternate-icon.example/brand.png';
      const http: FakePageIconHttpPort = new FakePageIconHttpPort();
      http.textResponses.set(pageUrl, {
        responseCode: 200,
        textBody: '<link rel="icon" href="/missing.ico">' +
          '<link rel="shortcut icon" href="/brand.png">'
      });
      http.byteResponses.set(firstIconUrl, { responseCode: 404 });
      http.byteResponses.set(secondIconUrl, {
        responseCode: 200,
        binaryBody: new ArrayBuffer(4)
      });
      const decoder: FakePageIconImageDecoder = new FakePageIconImageDecoder();
      const fileStore: FakePageIconFileStore = new FakePageIconFileStore();
      const events: PageIconDiagnosticEvent[] = [];
      const fetcher: PageIconFallbackFetcher =
        createTestPageIconFetcher(http, decoder, fileStore, events);

      const record: PageIconRecord | undefined = await fetcher.fetch(pageUrl);

      expect(http.byteUrls.length).assertEqual(2);
      expect(http.byteUrls[0]).assertEqual(firstIconUrl);
      expect(http.byteUrls[1]).assertEqual(secondIconUrl);
      expect(decoder.decodeCount).assertEqual(1);
      expect(record?.localPath).assertEqual('/cache/site-icon.png');
    });

    it('returns no icon for HTTP failures and records a stable status category', 0, async () => {
      const pageUrl: string = 'https://news.bjd.com.cn/article';
      const http: FakePageIconHttpPort = new FakePageIconHttpPort();
      http.textResponses.set(pageUrl, { responseCode: 503, textBody: 'private response' });
      const events: PageIconDiagnosticEvent[] = [];
      const fetcher: PageIconFallbackFetcher = createTestPageIconFetcher(
        http, new FakePageIconImageDecoder(), new FakePageIconFileStore(), events
      );

      expect(await fetcher.fetch(pageUrl)).assertUndefined();
      expect(http.byteUrls.length).assertEqual(0);
      expect(events[events.length - 1].category).assertEqual(PageIconFailureCategory.HTTP_STATUS);
    });

    it('turns transport exceptions into silent network failures', 0, async () => {
      const pageUrl: string = 'https://news.bjd.com.cn/article';
      const http: FakePageIconHttpPort = new FakePageIconHttpPort();
      http.textFailures.add(pageUrl);
      const events: PageIconDiagnosticEvent[] = [];
      const fetcher: PageIconFallbackFetcher = createTestPageIconFetcher(
        http, new FakePageIconImageDecoder(), new FakePageIconFileStore(), events
      );

      expect(await fetcher.fetch(pageUrl)).assertUndefined();
      expect(events[events.length - 1].category).assertEqual(PageIconFailureCategory.NETWORK_ERROR);
      expect(events[events.length - 1].host).assertEqual('news.bjd.com.cn');
    });

    it('stops redirect cycles without repeating the page request', 0, async () => {
      const pageUrl: string = 'https://news.bjd.com.cn/page';
      const secondUrl: string = 'https://news.bjd.com.cn/next';
      const http: FakePageIconHttpPort = new FakePageIconHttpPort();
      http.textResponses.set(pageUrl, { responseCode: 302, location: '/next' });
      http.textResponses.set(secondUrl, { responseCode: 301, location: '/page' });
      const events: PageIconDiagnosticEvent[] = [];
      const fetcher: PageIconFallbackFetcher = createTestPageIconFetcher(
        http, new FakePageIconImageDecoder(), new FakePageIconFileStore(), events
      );

      expect(await fetcher.fetch(pageUrl)).assertUndefined();
      expect(http.textUrls.length).assertEqual(2);
      expect(http.textUrls[1]).assertEqual(secondUrl);
      expect(events[events.length - 1].category).assertEqual(PageIconFailureCategory.REDIRECT_LIMIT);
    });

    it('stops after five redirects even when each destination is unique', 0, async () => {
      const pageUrl: string = 'https://news.bjd.com.cn/page';
      const redirect1: string = 'https://news.bjd.com.cn/r1';
      const redirect2: string = 'https://news.bjd.com.cn/r2';
      const redirect3: string = 'https://news.bjd.com.cn/r3';
      const redirect4: string = 'https://news.bjd.com.cn/r4';
      const redirect5: string = 'https://news.bjd.com.cn/r5';
      const http: FakePageIconHttpPort = new FakePageIconHttpPort();
      http.textResponses.set(pageUrl, { responseCode: 302, location: '/r1' });
      http.textResponses.set(redirect1, { responseCode: 302, location: '/r2' });
      http.textResponses.set(redirect2, { responseCode: 302, location: '/r3' });
      http.textResponses.set(redirect3, { responseCode: 302, location: '/r4' });
      http.textResponses.set(redirect4, { responseCode: 302, location: '/r5' });
      http.textResponses.set(redirect5, { responseCode: 302, location: '/r6' });
      const events: PageIconDiagnosticEvent[] = [];
      const fetcher: PageIconFallbackFetcher = createTestPageIconFetcher(
        http, new FakePageIconImageDecoder(), new FakePageIconFileStore(), events
      );

      expect(await fetcher.fetch(pageUrl)).assertUndefined();
      expect(http.textUrls.length).assertEqual(6);
      expect(http.textUrls[5]).assertEqual(redirect5);
      expect(events[events.length - 1].category).assertEqual(PageIconFailureCategory.REDIRECT_LIMIT);
    });

    it('rejects an HTTPS page redirecting to HTTP before requesting the downgraded URL', 0, async () => {
      const pageUrl: string = 'https://news.bjd.com.cn/page';
      const http: FakePageIconHttpPort = new FakePageIconHttpPort();
      http.textResponses.set(pageUrl, {
        responseCode: 302,
        location: 'http://untrusted.example/page'
      });
      const events: PageIconDiagnosticEvent[] = [];
      const fetcher: PageIconFallbackFetcher = createTestPageIconFetcher(
        http, new FakePageIconImageDecoder(), new FakePageIconFileStore(), events
      );

      expect(await fetcher.fetch(pageUrl)).assertUndefined();
      expect(http.textUrls.length).assertEqual(1);
      expect(events[events.length - 1].category).assertEqual(PageIconFailureCategory.HTTPS_DOWNGRADE);
    });

    it('rejects undecodable image data and records the decode failure', 0, async () => {
      const pageUrl: string = 'https://news.bjd.com.cn/page';
      const iconUrl: string = 'https://news.bjd.com.cn/icon.png';
      const http: FakePageIconHttpPort = new FakePageIconHttpPort();
      http.textResponses.set(pageUrl, {
        responseCode: 200,
        textBody: '<link rel="icon" href="/icon.png">'
      });
      http.byteResponses.set(iconUrl, { responseCode: 200, binaryBody: new ArrayBuffer(3) });
      const decoder: FakePageIconImageDecoder = new FakePageIconImageDecoder();
      decoder.shouldFail = true;
      const events: PageIconDiagnosticEvent[] = [];
      const fetcher: PageIconFallbackFetcher = createTestPageIconFetcher(
        http, decoder, new FakePageIconFileStore(), events
      );

      expect(await fetcher.fetch(pageUrl)).assertUndefined();
      let decodeFailureRecorded: boolean = false;
      for (let index: number = 0; index < events.length; index += 1) {
        if (events[index].category === PageIconFailureCategory.INVALID_IMAGE) {
          decodeFailureRecorded = true;
        }
      }
      expect(decodeFailureRecorded).assertTrue();
      expect(http.byteUrls.length).assertEqual(2);
      expect(http.byteUrls[1]).assertEqual('https://news.bjd.com.cn/favicon.ico');
    });

    it('rejects a file-store failure instead of returning an unusable icon path', 0, async () => {
      const pageUrl: string = 'https://news.bjd.com.cn/page';
      const iconUrl: string = 'https://news.bjd.com.cn/icon.png';
      const http: FakePageIconHttpPort = new FakePageIconHttpPort();
      http.textResponses.set(pageUrl, {
        responseCode: 200,
        textBody: '<link rel="icon" href="/icon.png">'
      });
      http.byteResponses.set(iconUrl, { responseCode: 200, binaryBody: new ArrayBuffer(3) });
      const fileStore: FakePageIconFileStore = new FakePageIconFileStore();
      fileStore.savePath = undefined;
      const events: PageIconDiagnosticEvent[] = [];
      const fetcher: PageIconFallbackFetcher = createTestPageIconFetcher(
        http, new FakePageIconImageDecoder(), fileStore, events
      );

      expect(await fetcher.fetch(pageUrl)).assertUndefined();
      expect(events[events.length - 1].category).assertEqual(PageIconFailureCategory.FILE_WRITE_FAILED);
    });

    it('checks that the saved icon path exists before returning it', 0, async () => {
      const pageUrl: string = 'https://news.bjd.com.cn/page';
      const iconUrl: string = 'https://news.bjd.com.cn/icon.png';
      const http: FakePageIconHttpPort = new FakePageIconHttpPort();
      http.textResponses.set(pageUrl, {
        responseCode: 200,
        textBody: '<link rel="icon" href="/icon.png">'
      });
      http.byteResponses.set(iconUrl, { responseCode: 200, binaryBody: new ArrayBuffer(3) });
      const fileStore: FakePageIconFileStore = new FakePageIconFileStore();
      fileStore.fileExists = false;
      const events: PageIconDiagnosticEvent[] = [];
      const fetcher: PageIconFallbackFetcher = createTestPageIconFetcher(
        http, new FakePageIconImageDecoder(), fileStore, events
      );

      expect(await fetcher.fetch(pageUrl)).assertUndefined();
      expect(fileStore.savedUrl).assertEqual(pageUrl);
      expect(events[events.length - 1].category).assertEqual(PageIconFailureCategory.FILE_WRITE_FAILED);
    });

    it('runs only one fallback for concurrent rows from the same site', 0, async () => {
      let attempts: number = 0;
      let releaseWork: ((record: PageIconRecord | undefined) => void) | undefined;
      const work: PageIconFallbackWork = (_url: string): Promise<PageIconRecord | undefined> => {
        attempts += 1;
        return new Promise<PageIconRecord | undefined>((resolve) => {
          releaseWork = resolve;
        });
      };
      const coordinator: PageIconFallbackCoordinator = new PageIconFallbackCoordinator(
        pageIconSiteKeyForUrl,
        (_url: string): boolean => false,
        work
      );

      coordinator.request('https://news.bjd.com.cn/article/one');
      coordinator.request('https://news.bjd.com.cn/article/two');
      expect(attempts).assertEqual(1);
      if (releaseWork !== undefined) {
        releaseWork(undefined);
      }
      await flushPageIconCoordinator();
    });

    it('keeps concurrent fallback work within the configured limit', 0, async () => {
      const urls: string[] = [
        'https://one.example/page',
        'https://two.example/page',
        'https://three.example/page',
        'https://four.example/page',
        'https://five.example/page'
      ];
      const started: string[] = [];
      const resolvers: Map<string, (record: PageIconRecord | undefined) => void> = new Map();
      let active: number = 0;
      let maxActive: number = 0;
      const work: PageIconFallbackWork = (url: string): Promise<PageIconRecord | undefined> => {
        started.push(url);
        active += 1;
        maxActive = Math.max(maxActive, active);
        return new Promise<PageIconRecord | undefined>((resolve) => {
          resolvers.set(url, resolve);
        });
      };
      const coordinator: PageIconFallbackCoordinator = new PageIconFallbackCoordinator(
        pageIconSiteKeyForUrl,
        (_url: string): boolean => false,
        work,
        3
      );
      for (let index: number = 0; index < urls.length; index += 1) {
        coordinator.request(urls[index]);
      }

      expect(started.length).assertEqual(3);
      if (resolvers.has(urls[0])) {
        active -= 1;
        resolvers.get(urls[0])?.(undefined);
      }
      await flushPageIconCoordinator();
      expect(started.length).assertEqual(4);
      if (resolvers.has(urls[1])) {
        active -= 1;
        resolvers.get(urls[1])?.(undefined);
      }
      await flushPageIconCoordinator();
      expect(started.length).assertEqual(5);

      for (let index: number = 2; index < urls.length; index += 1) {
        const resolver: ((record: PageIconRecord | undefined) => void) | undefined =
          resolvers.get(urls[index]);
        if (resolver !== undefined) {
          active -= 1;
          resolver(undefined);
        }
      }
      await flushPageIconCoordinator();
      expect(maxActive).assertEqual(3);
      expect(active).assertEqual(0);
    });

    it('skips a fallback when the site already has a usable cached icon', 0, () => {
      let attempts: number = 0;
      const work: PageIconFallbackWork = async (_url: string): Promise<PageIconRecord | undefined> => {
        attempts += 1;
        return undefined;
      };
      const coordinator: PageIconFallbackCoordinator = new PageIconFallbackCoordinator(
        pageIconSiteKeyForUrl,
        (url: string): boolean => url === 'https://cached.example/page',
        work
      );

      coordinator.request('https://cached.example/page');
      expect(attempts).assertEqual(0);
    });

    it('suppresses failed sites until the library session is reset', 0, async () => {
      let attempts: number = 0;
      const work: PageIconFallbackWork = async (_url: string): Promise<PageIconRecord | undefined> => {
        attempts += 1;
        return undefined;
      };
      const coordinator: PageIconFallbackCoordinator = new PageIconFallbackCoordinator(
        pageIconSiteKeyForUrl,
        (_url: string): boolean => false,
        work
      );

      coordinator.request('https://failed.example/first');
      await flushPageIconCoordinator();
      coordinator.request('https://failed.example/second');
      await flushPageIconCoordinator();
      expect(attempts).assertEqual(1);

      coordinator.resetFailedSites();
      coordinator.request('https://failed.example/third');
      await flushPageIconCoordinator();
      expect(attempts).assertEqual(2);
    });
  });
}
