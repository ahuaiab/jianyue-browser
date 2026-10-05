import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import {
  PageIconDiagnostics,
  PageIconDiagnosticStage,
  PageIconFailureCategory
} from '../model/PageIconDiagnostics';
import {
  resolveDeclaredPageIconUrls,
  resolveDefaultPageIconUrl,
  resolvePageIconHref
} from '../model/PageIconUrlResolver';
import { PageIconRecord } from '../model/PageIconModels';

const MAX_REDIRECTS: number = 5;
const PAGE_CONNECT_TIMEOUT_MS: number = 10000;
const PAGE_READ_TIMEOUT_MS: number = 10000;

export interface PageIconHttpResponse {
  responseCode: number;
  textBody?: string;
  binaryBody?: ArrayBuffer;
  location?: string;
}

export interface PageIconHttpPort {
  requestText(url: string): Promise<PageIconHttpResponse>;
  requestBytes(url: string): Promise<PageIconHttpResponse>;
}

export interface PageIconImageDecoderPort {
  decode(bytes: ArrayBuffer): Promise<image.PixelMap>;
}

export interface PageIconFileStorePort {
  save(url: string, pixelMap: image.PixelMap): Promise<string | undefined>;
  exists(path: string): boolean;
}

interface PageIconCompletedResponse {
  url: string;
  response: PageIconHttpResponse;
}

/** Fetches, decodes, and persists one favicon without exposing page content to diagnostics. */
export class PageIconFallbackFetcher {
  private readonly httpPort: PageIconHttpPort;
  private readonly decoder: PageIconImageDecoderPort;
  private readonly fileStore: PageIconFileStorePort;
  private readonly diagnostics: PageIconDiagnostics;

  constructor(
    httpPort: PageIconHttpPort,
    decoder: PageIconImageDecoderPort,
    fileStore: PageIconFileStorePort,
    diagnostics: PageIconDiagnostics
  ) {
    this.httpPort = httpPort;
    this.decoder = decoder;
    this.fileStore = fileStore;
    this.diagnostics = diagnostics;
  }

  async fetch(pageUrl: string): Promise<PageIconRecord | undefined> {
    const originalUrl: string = pageUrl.trim();
    this.diagnostics.record(PageIconDiagnosticStage.FALLBACK_START, originalUrl);

    const normalizedPageUrl: string | undefined = resolvePageIconHref(originalUrl, originalUrl);
    if (normalizedPageUrl === undefined) {
      this.diagnostics.record(
        PageIconDiagnosticStage.PAGE_RESPONSE,
        originalUrl,
        PageIconFailureCategory.INVALID_URL
      );
      return undefined;
    }

    const safePageUrl: string = stripQueryAndFragment(normalizedPageUrl);
    const pageResult: PageIconCompletedResponse | undefined = await this.requestFollowingRedirects(
      safePageUrl,
      true,
      PageIconDiagnosticStage.PAGE_RESPONSE,
      true
    );
    if (pageResult === undefined) {
      return undefined;
    }
    this.diagnostics.record(PageIconDiagnosticStage.PAGE_RESPONSE, pageResult.url);

    const html: string = pageResult.response.textBody ?? '';
    const iconUrls: string[] = resolveDeclaredPageIconUrls(pageResult.url, html);
    const defaultIconUrl: string | undefined = resolveDefaultPageIconUrl(pageResult.url);
    if (defaultIconUrl !== undefined && iconUrls.indexOf(defaultIconUrl) < 0) {
      iconUrls.push(defaultIconUrl);
    }
    if (iconUrls.length === 0) {
      this.diagnostics.record(
        PageIconDiagnosticStage.ICON_HOST_SELECTED,
        pageResult.url,
        PageIconFailureCategory.NO_ICON
      );
      return undefined;
    }
    let iconResult: PageIconCompletedResponse | undefined;
    let pixelMap: image.PixelMap | undefined;
    for (let index: number = 0; index < iconUrls.length; index += 1) {
      const iconUrl: string = iconUrls[index];
      this.diagnostics.record(PageIconDiagnosticStage.ICON_HOST_SELECTED, iconUrl);
      const candidateResult: PageIconCompletedResponse | undefined = await this.requestFollowingRedirects(
        iconUrl,
        false,
        PageIconDiagnosticStage.ICON_RESPONSE,
        false
      );
      if (candidateResult === undefined) {
        continue;
      }
      this.diagnostics.record(PageIconDiagnosticStage.ICON_RESPONSE, candidateResult.url);

      const bytes: ArrayBuffer | undefined = candidateResult.response.binaryBody;
      if (bytes === undefined || bytes.byteLength === 0) {
        this.diagnostics.record(
          PageIconDiagnosticStage.DECODE,
          candidateResult.url,
          PageIconFailureCategory.INVALID_IMAGE
        );
        continue;
      }

      try {
        pixelMap = await this.decoder.decode(bytes);
      } catch (_error) {
        this.diagnostics.record(
          PageIconDiagnosticStage.DECODE,
          candidateResult.url,
          PageIconFailureCategory.INVALID_IMAGE
        );
        continue;
      }
      iconResult = candidateResult;
      this.diagnostics.record(PageIconDiagnosticStage.DECODE, candidateResult.url);
      break;
    }
    if (iconResult === undefined || pixelMap === undefined) {
      return undefined;
    }

    let localPath: string | undefined;
    try {
      localPath = await this.fileStore.save(originalUrl, pixelMap);
    } catch (_error) {
      localPath = undefined;
    }
    let fileExists: boolean = false;
    if (localPath !== undefined && localPath.trim().length > 0) {
      try {
        fileExists = this.fileStore.exists(localPath);
      } catch (_error) {
        fileExists = false;
      }
    }
    if (localPath === undefined || localPath.trim().length === 0 || !fileExists) {
      this.diagnostics.record(
        PageIconDiagnosticStage.FILE_WRITE,
        originalUrl,
        PageIconFailureCategory.FILE_WRITE_FAILED
      );
      return undefined;
    }

    this.diagnostics.record(PageIconDiagnosticStage.FILE_WRITE, originalUrl);
    return {
      url: originalUrl,
      localPath: localPath.trim(),
      updatedAt: Date.now()
    };
  }

  private async requestFollowingRedirects(
    initialUrl: string,
    textResponse: boolean,
    stage: PageIconDiagnosticStage,
    stripRedirectQuery: boolean
  ): Promise<PageIconCompletedResponse | undefined> {
    let currentUrl: string = initialUrl;
    let redirects: number = 0;
    const visited: Set<string> = new Set();

    while (true) {
      if (visited.has(currentUrl)) {
        this.diagnostics.record(stage, currentUrl, PageIconFailureCategory.REDIRECT_LIMIT);
        return undefined;
      }
      visited.add(currentUrl);

      let response: PageIconHttpResponse;
      try {
        response = textResponse
          ? await this.httpPort.requestText(currentUrl)
          : await this.httpPort.requestBytes(currentUrl);
      } catch (_error) {
        this.diagnostics.record(stage, currentUrl, PageIconFailureCategory.NETWORK_ERROR);
        return undefined;
      }

      if (!isRedirectStatus(response.responseCode)) {
        if (response.responseCode < 200 || response.responseCode >= 300) {
          this.diagnostics.record(stage, currentUrl, PageIconFailureCategory.HTTP_STATUS);
          return undefined;
        }
        return { url: currentUrl, response: response };
      }

      if (redirects >= MAX_REDIRECTS) {
        this.diagnostics.record(stage, currentUrl, PageIconFailureCategory.REDIRECT_LIMIT);
        return undefined;
      }
      const location: string = response.location ?? '';
      const nextUrl: string | undefined = resolvePageIconHref(currentUrl, location);
      if (nextUrl === undefined) {
        const category: PageIconFailureCategory = isHttpsDowngrade(currentUrl, location)
          ? PageIconFailureCategory.HTTPS_DOWNGRADE
          : PageIconFailureCategory.INVALID_URL;
        this.diagnostics.record(stage, currentUrl, category);
        return undefined;
      }

      currentUrl = stripRedirectQuery ? stripQueryAndFragment(nextUrl) : nextUrl;
      redirects += 1;
    }
  }
}

/** NetworkKit adapter. A fresh HttpRequest is created and destroyed for each hop. */
export class NetworkKitPageIconHttpPort implements PageIconHttpPort {
  async requestText(url: string): Promise<PageIconHttpResponse> {
    return this.request(url, http.HttpDataType.STRING);
  }

  async requestBytes(url: string): Promise<PageIconHttpResponse> {
    return this.request(url, http.HttpDataType.ARRAY_BUFFER);
  }

  private async request(url: string, dataType: http.HttpDataType): Promise<PageIconHttpResponse> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: dataType,
        maxRedirects: 0,
        connectTimeout: PAGE_CONNECT_TIMEOUT_MS,
        readTimeout: PAGE_READ_TIMEOUT_MS,
        usingCache: false,
        header: { 'Accept': dataType === http.HttpDataType.STRING ? 'text/html,*/*' : 'image/*,*/*' }
      });

      const result: Object = response.result;
      const output: PageIconHttpResponse = { responseCode: response.responseCode };
      if (typeof result === 'string') {
        output.textBody = result;
      } else if (result instanceof ArrayBuffer) {
        output.binaryBody = result;
      }
      const location: string | undefined = responseHeaderValue(response.header, 'location');
      if (location !== undefined) {
        output.location = location;
      }
      return output;
    } finally {
      try {
        request.destroy();
      } catch (_error) {
        // The request has completed; release errors do not alter its result.
      }
    }
  }
}

/** ImageKit adapter that releases the source only after decoding has completed. */
export class ImageKitPageIconDecoder implements PageIconImageDecoderPort {
  async decode(bytes: ArrayBuffer): Promise<image.PixelMap> {
    const source: image.ImageSource = image.createImageSource(bytes);
    try {
      const pixelMap: image.PixelMap | undefined = await source.createPixelMap();
      if (pixelMap === undefined) {
        throw new Error('Invalid image data');
      }
      return pixelMap;
    } finally {
      await source.release();
    }
  }
}

function responseHeaderValue(headers: Object, targetName: string): string | undefined {
  const headerRecord: Record<string, Object> = headers as Record<string, Object>;
  const names: string[] = Object.keys(headerRecord);
  for (let index: number = 0; index < names.length; index += 1) {
    const name: string = names[index];
    if (name.toLowerCase() === targetName) {
      const value: Object = headerRecord[name];
      return typeof value === 'string' ? value : undefined;
    }
  }
  return undefined;
}

function stripQueryAndFragment(value: string): string {
  const queryIndex: number = value.indexOf('?');
  const fragmentIndex: number = value.indexOf('#');
  let end: number = value.length;
  if (queryIndex >= 0 && queryIndex < end) {
    end = queryIndex;
  }
  if (fragmentIndex >= 0 && fragmentIndex < end) {
    end = fragmentIndex;
  }
  return value.slice(0, end);
}

function isRedirectStatus(status: number): boolean {
  return status === 301 || status === 302 || status === 303 || status === 307 || status === 308;
}

function isHttpsDowngrade(sourceUrl: string, location: string): boolean {
  return sourceUrl.trim().toLowerCase().startsWith('https://') &&
    location.trim().toLowerCase().startsWith('http:');
}
