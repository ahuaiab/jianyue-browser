// Chromium reports ERR_INTERNET_DISCONNECTED as -106 through ArkWeb.
const OFFLINE_NETWORK_ERROR_CODE: number = -106;

export function shouldShowPageLevelNetworkError(
  isMainFrame: boolean,
  isPageLoadPending: boolean,
  errorCode: number
): boolean {
  return isMainFrame || (isPageLoadPending && errorCode === OFFLINE_NETWORK_ERROR_CODE);
}
