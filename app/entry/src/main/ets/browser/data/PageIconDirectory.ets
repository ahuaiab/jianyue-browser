const FILE_NOT_FOUND_ERROR_CODE: number = 13900002;
const FILE_EXISTS_ERROR_CODE: number = 13900015;

class PageIconDirectoryError extends Error {
  readonly code: number | undefined;

  constructor(code: number | undefined) {
    super('Unable to ensure the page icon cache directory');
    this.code = code;
  }
}

/**
 * Ensures the icon cache directory exists without treating EEXIST as a fatal
 * error when another save created the same directory concurrently.
 */
export function ensurePageIconDirectory(
  isDirectory: () => boolean,
  createDirectory: () => void
): void {
  try {
    if (isDirectory()) {
      return;
    }
  } catch (_error) {
    if (pageIconFileErrorCode(_error) !== FILE_NOT_FOUND_ERROR_CODE) {
      throw new PageIconDirectoryError(pageIconFileErrorCode(_error));
    }
  }

  try {
    createDirectory();
  } catch (_error) {
    if (pageIconFileErrorCode(_error) !== FILE_EXISTS_ERROR_CODE || !isDirectory()) {
      throw new PageIconDirectoryError(pageIconFileErrorCode(_error));
    }
  }
}

function pageIconFileErrorCode(error: Object): number | undefined {
  const errorDetails: Record<string, Object> = error as Record<string, Object>;
  const rawCode: Object = errorDetails['code'];
  return typeof rawCode === 'number' ? rawCode : undefined;
}
