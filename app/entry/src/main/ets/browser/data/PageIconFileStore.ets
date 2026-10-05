import { image } from '@kit.ImageKit';
import { PageIconFileStorePort } from './PageIconFallbackFetcher';
import {
  PageIconDiagnostics,
  PageIconDiagnosticStage,
  PageIconFailureCategory
} from '../model/PageIconDiagnostics';
import { ensurePageIconDirectory } from './PageIconDirectory';
import fs from '@ohos.file.fs';

const PAGE_ICON_DIRECTORY: string = 'page-icons';

/** Stores ArkWeb PixelMaps as small local PNGs so library pages never fetch favicons on startup. */
export class PageIconFileStore implements PageIconFileStorePort {
  private readonly directory: string;
  private readonly diagnostics: PageIconDiagnostics | undefined;

  constructor(filesDir: string, diagnostics?: PageIconDiagnostics) {
    this.directory = `${filesDir}/${PAGE_ICON_DIRECTORY}`;
    this.diagnostics = diagnostics;
  }

  async save(url: string, pixelMap: image.PixelMap): Promise<string | undefined> {
    const normalizedUrl: string = url.trim();
    if (normalizedUrl.length === 0) {
      return undefined;
    }
    const path: string = this.pathFor(normalizedUrl);
    let file: fs.File | undefined;
    let packer: image.ImagePacker | undefined;
    let failureCategory: PageIconFailureCategory = PageIconFailureCategory.FILE_DIRECTORY_FAILED;
    try {
      ensurePageIconDirectory(
        (): boolean => fs.statSync(this.directory).isDirectory(),
        (): void => fs.mkdirSync(this.directory, true)
      );
      failureCategory = PageIconFailureCategory.FILE_OPEN_FAILED;
      file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      failureCategory = PageIconFailureCategory.IMAGE_PACKER_CREATE_FAILED;
      packer = image.createImagePacker();
      failureCategory = PageIconFailureCategory.IMAGE_PACK_FAILED;
      await packer.packToFile(pixelMap, file.fd, {
        format: 'image/png',
        quality: 100
      });
      return path;
    } catch (_error) {
      const errorDetails: Record<string, Object> = _error as Record<string, Object>;
      const rawCode: Object = errorDetails['code'];
      const errorCode: number | undefined = typeof rawCode === 'number' ? rawCode : undefined;
      this.diagnostics?.record(
        PageIconDiagnosticStage.FILE_WRITE,
        normalizedUrl,
        failureCategory,
        errorCode
      );
      return undefined;
    } finally {
      if (packer !== undefined) {
        try {
          await packer.release();
        } catch (_error) {
          // Ignore a release failure after the icon has already been written.
        }
      }
      if (file !== undefined) {
        try {
          fs.closeSync(file.fd);
        } catch (_error) {
          // Ignore a close failure from a partially opened file.
        }
      }
    }
  }

  exists(path: string): boolean {
    if (path.trim().length === 0) {
      return false;
    }
    try {
      fs.statSync(path);
      return true;
    } catch (_error) {
      return false;
    }
  }

  pathFor(url: string): string {
    return `${this.directory}/${stableFileName(url)}.png`;
  }
}

function stableFileName(value: string): string {
  let hash: number = 2166136261;
  for (let index: number = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return `${(hash >>> 0).toString(16)}`;
}
