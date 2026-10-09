import { PageFontSize } from './PageDisplayState';

export enum PageAction {
  BOOKMARK = 'bookmark',
  DOWNLOAD_MANAGER = 'download_manager',
  DESKTOP_SITE = 'desktop_site',
  READER_MODE = 'reader_mode'
}

export interface PageActionAvailability {
  enabled: PageAction[];
  reason: string;
}

/** The download manager stays available while a page is still loading. */
export function pageMenuActions(webReady: boolean): PageAction[] {
  return webReady
    ? [PageAction.DOWNLOAD_MANAGER, PageAction.DESKTOP_SITE]
    : [PageAction.DOWNLOAD_MANAGER];
}

export function nextFontSize(size: PageFontSize): PageFontSize {
  if (size === PageFontSize.SMALL) {
    return PageFontSize.STANDARD;
  }
  if (size === PageFontSize.STANDARD) {
    return PageFontSize.LARGE;
  }
  return PageFontSize.SMALL;
}

export function availablePageActions(webReady: boolean): PageActionAvailability {
  if (!webReady) {
    return {
      enabled: [PageAction.DOWNLOAD_MANAGER],
      reason: '网页尚未完成加载，暂时不能执行页面操作'
    };
  }
  return {
    enabled: pageMenuActions(true),
    reason: ''
  };
}

/** Remove the mobile marker while preserving the current ArkWeb identity. */
export function desktopUserAgentFor(userAgent: string): string {
  const normalized: string = userAgent.trim();
  if (normalized.length === 0) {
    return normalized;
  }
  return normalized.replace(/\bMobile\b/g, '').replace(/\s{2,}/g, ' ').trim();
}

/** True for the exact Google Search hosts covered by the ArkWeb host UA rule. */
export function isGoogleSearchUrl(url: string): boolean {
  // WHATWG URL parsing treats backslashes as slashes for special schemes.
  // Normalize them before extracting authority so `evil.test\\@google.com`
  // cannot be mistaken for a Google host.
  const normalizedUrl: string = url.trim().replace(/\\/g, '/');
  const match: RegExpExecArray | null = /^https?:\/\/([^/?#]+)/i.exec(normalizedUrl);
  if (match === null || match.length < 2) {
    return false;
  }
  let authority: string = match[1];
  const atIndex: number = authority.lastIndexOf('@');
  if (atIndex >= 0) {
    authority = authority.substring(atIndex + 1);
  }
  const host: string = authority.replace(/:\d+$/, '').replace(/\.$/, '').toLowerCase();
  return host === 'google.com' || host === 'www.google.com';
}

/**
 * Normalize only ArkWeb's phone UA shape for Google Search. The Chrome and
 * OpenHarmony versions come from the live default UA; no engine version is
 * guessed. Desktop mode keeps the same identity and omits the Mobile marker.
 */
export function googleSearchCompatibleUserAgentFor(userAgent: string, mobile: boolean = true): string {
  const normalized: string = userAgent.trim();
  if (normalized.length === 0) {
    return '';
  }
  const hasOpenHarmonyPhone: boolean = /\(Phone; OpenHarmony [^)]+\)/.test(normalized);
  const hasChromeVersion: boolean = /\bChrome\/\d+(?:\.\d+)*\b/.test(normalized);
  if (!hasOpenHarmonyPhone || !hasChromeVersion) {
    return mobile ? normalized : desktopUserAgentFor(normalized);
  }
  let compatible: string = normalized
    .replace(/\(Phone; OpenHarmony ([^)]+)\)/, '(Linux; OpenHarmony $1)')
    .replace(/\s+ArkWeb\/[^\s]+/g, '')
    .replace(/Safari\/([\d.]+)\s+Mobile$/, 'Mobile Safari/$1')
    .replace(/\s{2,}/g, ' ');
  if (!mobile) {
    compatible = compatible.replace(/\s+Mobile(?=\s|$)/g, '');
  }
  return compatible.trim();
}

/** Keep the page-mode menu label and native symbol in the same state model. */
export function pageModeMenuLabel(desktopMode: boolean): string {
  return desktopMode ? '请求手机网页' : '请求桌面网页';
}

/**
 * Resolve the symbol from the live device form factor. HarmonyOS exposes
 * foldable phones as `phone`, so model names are intentionally not embedded
 * in the browser UI; the system symbol layer remains the source of the shape.
 */
export function pageModeMenuSymbolName(desktopMode: boolean, deviceType: string = 'phone'): string {
  if (!desktopMode) {
    return 'sys.symbol.display';
  }
  return deviceType.trim().toLowerCase() === 'phone'
    ? 'sys.symbol.rectangle_portrait'
    : 'sys.symbol.display';
}
