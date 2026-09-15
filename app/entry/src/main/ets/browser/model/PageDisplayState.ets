export enum PageFontSize {
  SMALL = 'small',
  STANDARD = 'standard',
  LARGE = 'large'
}

export interface PageDisplayState {
  fontSize: PageFontSize;
  fullScreen: boolean;
}

export const DEFAULT_PAGE_DISPLAY_STATE: PageDisplayState = {
  fontSize: PageFontSize.STANDARD,
  fullScreen: false
};

export function copyPageDisplayState(state: PageDisplayState): PageDisplayState {
  return {
    fontSize: state.fontSize,
    fullScreen: state.fullScreen
  };
}

export function normalizePageDisplayState(value: Object | undefined): PageDisplayState {
  if (value === undefined || value === null || typeof value !== 'object') {
    return copyPageDisplayState(DEFAULT_PAGE_DISPLAY_STATE);
  }
  const candidate: Partial<PageDisplayState> = value as Partial<PageDisplayState>;
  const fontSize: PageFontSize = candidate.fontSize === PageFontSize.SMALL ||
    candidate.fontSize === PageFontSize.LARGE
    ? candidate.fontSize
    : PageFontSize.STANDARD;
  return {
    fontSize,
    fullScreen: candidate.fullScreen === true
  };
}
