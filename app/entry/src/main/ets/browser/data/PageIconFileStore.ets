import { image } from '@kit.ImageKit';
import fs from '@ohos.file.fs';

const PAGE_ICON_DIRECTORY: string = 'page-icons';

/** Stores ArkWeb PixelMaps as small local PNGs so library pages never fetch favicons on startup. */
export class PageIconFileStore {
  private readonly directory: string;

  constructor(filesDir: string) {
    this.directory = `${filesDir}/${PAGE_ICON_DIRECTORY}`;
  }

  async save(url: string, pixelMap: image.PixelMap): Promise<string | undefined> {
    const normalizedUrl: string = url.trim();
    if (normalizedUrl.length === 0) {
      return undefined;
    }
    const path: string = this.pathFor(normalizedUrl);
    let file: fs.File | undefined;
    let packer: image.ImagePacker | undefined;
    try {
      fs.mkdirSync(this.directory, true);
      file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      packer = image.createImagePacker();
      await packer.packToFile(pixelMap, file.fd, {
        format: 'image/png',
        quality: 100
      });
      return path;
    } catch (_error) {
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
