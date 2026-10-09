import { describe, expect, it } from '@ohos/hypium';
import {
  DEFAULT_READER_MODE_SETTINGS,
  ReaderModeSettings
} from '../../../main/ets/browser/model/ReaderMode';
import { KeyValueStore, MemoryKeyValueStore } from '../../../main/ets/browser/data/KeyValueStore';
import { ReaderModeRepository } from '../../../main/ets/browser/data/ReaderModeRepository';

class DelayedMemoryStore implements KeyValueStore {
  private readonly memory: MemoryKeyValueStore = new MemoryKeyValueStore();
  private writeCount: number = 0;
  private readonly failFirstWrite: boolean;

  constructor(failFirstWrite: boolean = false) {
    this.failFirstWrite = failFirstWrite;
  }

  async getString(key: string, fallback: string): Promise<string> {
    return this.memory.getString(key, fallback);
  }

  async putString(key: string, value: string): Promise<void> {
    this.writeCount++;
    if (this.writeCount === 1) {
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, 20));
      if (this.failFirstWrite) {
        throw new Error('intentional first write failure');
      }
    }
    await this.memory.putString(key, value);
  }

  async flush(): Promise<void> {
    await this.memory.flush();
  }
}

function settings(textSize: 'small' | 'standard' | 'large', theme: 'white' | 'sepia' | 'gray' | 'dark',
  autoReaderHosts: Array<string>): ReaderModeSettings {
  return { preferences: { textSize, theme }, autoReaderHosts };
}

export default function readerModeRepositoryTest() {
  describe('ReaderModeRepository', () => {
    it('returns independent defaults for missing and malformed JSON', 0, async () => {
      const store: MemoryKeyValueStore = new MemoryKeyValueStore();
      const repository: ReaderModeRepository = new ReaderModeRepository(store);
      const first: ReaderModeSettings = await repository.loadSettings();
      expect(first.preferences.textSize).assertEqual('standard');
      expect(first.preferences.theme).assertEqual('white');
      expect(first.autoReaderHosts.length).assertEqual(0);
      first.autoReaderHosts.push('mutated.example');
      first.preferences.theme = 'dark';
      const second: ReaderModeSettings = await repository.loadSettings();
      expect(second.autoReaderHosts.length).assertEqual(0);
      expect(second.preferences.theme).assertEqual('white');

      await store.putString('reader.settings.v1', '{broken json');
      const malformed: ReaderModeSettings = await repository.loadSettings();
      expect(malformed.preferences.textSize).assertEqual('standard');
      expect(malformed.preferences.theme).assertEqual('white');
      expect(malformed.autoReaderHosts.length).assertEqual(0);
      expect(malformed === DEFAULT_READER_MODE_SETTINGS).assertFalse();
    });

    it('roundtrips normalized preferences and site hosts using an isolated snapshot', 0, async () => {
      const store: MemoryKeyValueStore = new MemoryKeyValueStore();
      const repository: ReaderModeRepository = new ReaderModeRepository(store);
      const input: ReaderModeSettings = settings('large', 'sepia', ['Example.com', 'example.com/path']);
      await repository.saveSettings(input);
      input.preferences.theme = 'dark';
      input.autoReaderHosts.push('changed.example');

      const loaded: ReaderModeSettings = await repository.loadSettings();
      expect(loaded.preferences.textSize).assertEqual('large');
      expect(loaded.preferences.theme).assertEqual('sepia');
      expect(loaded.autoReaderHosts.length).assertEqual(1);
      expect(loaded.autoReaderHosts[0]).assertEqual('example.com');
      loaded.autoReaderHosts.push('read-mutated.example');
      expect((await repository.loadSettings()).autoReaderHosts.length).assertEqual(1);
    });

    it('serializes overlapping saves so the last requested settings win', 0, async () => {
      const store: DelayedMemoryStore = new DelayedMemoryStore();
      const repository: ReaderModeRepository = new ReaderModeRepository(store);
      await Promise.all([
        repository.saveSettings(settings('small', 'gray', ['first.example'])),
        repository.saveSettings(settings('large', 'dark', ['last.example']))
      ]);
      const loaded: ReaderModeSettings = await repository.loadSettings();
      expect(loaded.preferences.textSize).assertEqual('large');
      expect(loaded.preferences.theme).assertEqual('dark');
      expect(loaded.autoReaderHosts[0]).assertEqual('last.example');
    });

    it('continues the save queue after a storage failure', 0, async () => {
      const store: DelayedMemoryStore = new DelayedMemoryStore(true);
      const repository: ReaderModeRepository = new ReaderModeRepository(store);
      let failed: boolean = false;
      try {
        await repository.saveSettings(settings('small', 'white', ['failed.example']));
      } catch (_error) {
        failed = true;
      }
      expect(failed).assertTrue();
      await repository.saveSettings(settings('standard', 'sepia', ['recovered.example']));
      const loaded: ReaderModeSettings = await repository.loadSettings();
      expect(loaded.preferences.theme).assertEqual('sepia');
      expect(loaded.autoReaderHosts[0]).assertEqual('recovered.example');
    });
  });
}
