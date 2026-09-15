import { PageFontSize } from './PageDisplayState';

export enum PageAction {
  BOOKMARK = 'bookmark',
  DOWNLOAD_MANAGER = 'download_manager',
  DESKTOP_SITE = 'desktop_site'
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
