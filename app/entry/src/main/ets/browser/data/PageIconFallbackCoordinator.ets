import { PageIconRecord } from '../model/PageIconModels';

export type PageIconFallbackWork = (url: string) => Promise<PageIconRecord | undefined>;
export type PageIconFallbackSiteKey = (url: string) => string;
export type PageIconFallbackCacheCheck = (url: string) => boolean;

interface PageIconFallbackRequest {
  siteKey: string;
  url: string;
}

/** Deduplicates fallback icon lookups by site and bounds concurrent requests. */
export class PageIconFallbackCoordinator {
  private readonly siteKeyForUrl: PageIconFallbackSiteKey;
  private readonly hasCachedIcon: PageIconFallbackCacheCheck;
  private readonly work: PageIconFallbackWork;
  private readonly maxConcurrent: number;
  private readonly pending: PageIconFallbackRequest[] = [];
  private readonly queuedSiteKeys: Set<string> = new Set<string>();
  private readonly activeSiteKeys: Set<string> = new Set<string>();
  private readonly failedSiteKeys: Set<string> = new Set<string>();
  private activeCount: number = 0;

  constructor(
    siteKeyForUrl: PageIconFallbackSiteKey,
    hasCachedIcon: PageIconFallbackCacheCheck,
    work: PageIconFallbackWork,
    maxConcurrent: number = 3
  ) {
    this.siteKeyForUrl = siteKeyForUrl;
    this.hasCachedIcon = hasCachedIcon;
    this.work = work;
    const requestedLimit: number = Math.floor(maxConcurrent);
    this.maxConcurrent = requestedLimit > 0 ? requestedLimit : 1;
  }

  request(url: string): void {
    const normalizedUrl: string = url.trim();
    if (normalizedUrl.length === 0) {
      return;
    }

    let siteKey: string;
    try {
      siteKey = this.siteKeyForUrl(normalizedUrl);
    } catch (_error) {
      return;
    }
    if (siteKey.length === 0 || this.queuedSiteKeys.has(siteKey) ||
      this.activeSiteKeys.has(siteKey) || this.failedSiteKeys.has(siteKey)) {
      return;
    }

    let cached: boolean = false;
    try {
      cached = this.hasCachedIcon(normalizedUrl);
    } catch (_error) {
      cached = false;
    }
    if (cached) {
      return;
    }

    this.pending.push({ siteKey, url: normalizedUrl });
    this.queuedSiteKeys.add(siteKey);
    this.pump();
  }

  resetFailedSites(): void {
    this.failedSiteKeys.clear();
  }

  private pump(): void {
    while (this.activeCount < this.maxConcurrent && this.pending.length > 0) {
      const request: PageIconFallbackRequest | undefined = this.pending.shift();
      if (request === undefined) {
        return;
      }
      this.queuedSiteKeys.delete(request.siteKey);
      if (this.failedSiteKeys.has(request.siteKey) || this.activeSiteKeys.has(request.siteKey)) {
        continue;
      }
      this.activeSiteKeys.add(request.siteKey);
      this.activeCount += 1;
      void this.run(request);
    }
  }

  private async run(request: PageIconFallbackRequest): Promise<void> {
    let succeeded: boolean = false;
    try {
      succeeded = (await this.work(request.url)) !== undefined;
    } catch (_error) {
      succeeded = false;
    }

    this.activeSiteKeys.delete(request.siteKey);
    this.activeCount = Math.max(0, this.activeCount - 1);
    if (!succeeded) {
      this.failedSiteKeys.add(request.siteKey);
    }
    this.pump();
  }
}
