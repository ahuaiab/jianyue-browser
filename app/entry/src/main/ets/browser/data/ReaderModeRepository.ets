import { KeyValueStore } from './KeyValueStore';
import {
  normalizeReaderModeSettings,
  ReaderModeSettings
} from '../model/ReaderMode';

const READER_SETTINGS_KEY: string = 'reader.settings.v1';

export class ReaderModeRepository {
  private readonly store: KeyValueStore;
  private saveQueue: Promise<void> = Promise.resolve();

  constructor(store: KeyValueStore) {
    this.store = store;
  }

  async loadSettings(): Promise<ReaderModeSettings> {
    try {
      const raw: string = await this.store.getString(READER_SETTINGS_KEY, '');
      if (raw.length === 0) {
        return normalizeReaderModeSettings(undefined);
      }
      const parsed: Object = JSON.parse(raw) as Object;
      return normalizeReaderModeSettings(parsed);
    } catch (_error) {
      return normalizeReaderModeSettings(undefined);
    }
  }

  saveSettings(settings: ReaderModeSettings): Promise<void> {
    const snapshot: ReaderModeSettings = normalizeReaderModeSettings(settings as Object);
    const serialized: string = JSON.stringify(snapshot);
    const queuedWrite: Promise<void> = this.saveQueue.catch((_error: Object) => undefined).then(async () => {
      await this.store.putString(READER_SETTINGS_KEY, serialized);
      await this.store.flush();
    });
    this.saveQueue = queuedWrite;
    return queuedWrite;
  }
}
