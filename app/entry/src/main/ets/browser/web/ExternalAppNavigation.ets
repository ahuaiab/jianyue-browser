export type ExternalAppLinkLauncher = (uri: string) => Promise<void>;

export type ExternalAppLinkFailureHandler = (scheme: string) => void;

function schemeForNavigationUrl(uri: string): string {
  const trimmedUri: string = uri.trim();
  const colonIndex: number = trimmedUri.indexOf(':');
  if (colonIndex <= 0) {
    return '';
  }

  const scheme: string = trimmedUri.substring(0, colonIndex);
  const firstCode: number = scheme.charCodeAt(0);
  const isFirstLetter: boolean = (firstCode >= 65 && firstCode <= 90) ||
    (firstCode >= 97 && firstCode <= 122);
  if (!isFirstLetter) {
    return '';
  }

  for (let index: number = 1; index < scheme.length; index += 1) {
    const code: number = scheme.charCodeAt(index);
    const isLetter: boolean = (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
    const isDigit: boolean = code >= 48 && code <= 57;
    if (!isLetter && !isDigit && code !== 43 && code !== 45 && code !== 46) {
      return '';
    }
  }

  return scheme.toLowerCase();
}

export function isExternalAppNavigationUrl(uri: string): boolean {
  const scheme: string = schemeForNavigationUrl(uri);
  if (scheme.length === 0) {
    return false;
  }

  // Keep web navigation and WebView-owned document/resource schemes in ArkWeb.
  return scheme !== 'http' && scheme !== 'https' && scheme !== 'about' && scheme !== 'blob' &&
    scheme !== 'data' && scheme !== 'file' && scheme !== 'javascript' && scheme !== 'res' &&
    scheme !== 'resource';
}

/**
 * Intercepts non-web navigations and gives the original URI to HarmonyOS link
 * resolution. A failed or unavailable target remains blocked in ArkWeb so it
 * cannot replace the current page with a scheme error page.
 */
export function interceptExternalAppNavigation(
  uri: string,
  launch: ExternalAppLinkLauncher | undefined,
  onFailure: ExternalAppLinkFailureHandler = (_scheme: string) => undefined
): boolean {
  if (!isExternalAppNavigationUrl(uri)) {
    return false;
  }

  const scheme: string = schemeForNavigationUrl(uri);
  if (launch === undefined) {
    onFailure(scheme);
    return true;
  }

  try {
    launch(uri).catch(() => onFailure(scheme));
  } catch (_error) {
    onFailure(scheme);
  }
  return true;
}
