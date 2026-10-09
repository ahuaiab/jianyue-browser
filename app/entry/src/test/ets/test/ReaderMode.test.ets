import { describe, expect, it } from '@ohos/hypium';
import {
  autoReaderEnabledFor,
  isReadableArticleCandidate,
  normalizeAutoReaderHosts,
  normalizeReaderModePreferences,
  normalizeReaderModeSettings,
  readerModePageEligibility,
  readerHostForUrl,
  setAutoReaderHost
} from '../../../main/ets/browser/model/ReaderMode';

interface ReaderPreferencesInputFixture {
  textSize: string;
  theme: string;
}

interface ReaderSettingsInputFixture {
  preferences: ReaderPreferencesInputFixture;
  autoReaderHosts: Array<string | null>;
}
export default function readerModeTest() {
  describe('ReaderMode', () => {
    it('normalizes preference and setting values', 0, () => {
      const goodPreferences: ReaderPreferencesInputFixture = { textSize: 'large', theme: 'sepia' };
      const badPreferences: ReaderPreferencesInputFixture = { textSize: 'huge', theme: 'neon' };
      const settingsFixture: ReaderSettingsInputFixture = {
        preferences: { textSize: 'small', theme: 'dark' },
        autoReaderHosts: ['example.com', 'EXAMPLE.com', 'example.com/path', null, 'bad..host']
      };
      expect(normalizeReaderModePreferences(goodPreferences as Object).textSize).assertEqual('large');
      expect(normalizeReaderModePreferences(badPreferences as Object).theme).assertEqual('white');
      const settings = normalizeReaderModeSettings(settingsFixture as Object);
      expect(settings.preferences.textSize).assertEqual('small');
      expect(settings.autoReaderHosts.length).assertEqual(1);
      expect(settings.autoReaderHosts[0]).assertEqual('example.com');
    });

    it('rejects malformed persisted host rules rather than broadening them', 0, () => {
      const hosts = normalizeAutoReaderHosts([
        'example.com/path', 'example.com?x=1', 'example.com#part', 'example.com\\other',
        'user@example.com', 'bad..example.com', '-bad.example', 'bad-.example',
        'white space.example', 'exa\u0000mple.com', 'example.com:65536', 'example.com:abc'
      ]);
      expect(hosts.length).assertEqual(0);
      const tooMany: Array<string> = [];
      for (let i = 0; i < 40; i++) tooMany.push('site' + i + '.example');
      expect(normalizeAutoReaderHosts(tooMany).length).assertEqual(32);
    });

    it('allows only ordinary HTTP(S) pages without credentials or malformed authorities', 0, () => {
      expect(readerModePageEligibility('https://example.com/a?b=c').eligible).assertTrue();
      expect(readerModePageEligibility('http://192.168.1.2:8080/article').eligible).assertTrue();
      expect(readerModePageEligibility('about:blank').eligible).assertFalse();
      expect(readerModePageEligibility('file:///tmp/a').eligible).assertFalse();
      expect(readerModePageEligibility('javascript:alert(1)').eligible).assertFalse();
      expect(readerModePageEligibility('https://u:p@example.com').eligible).assertFalse();
      expect(readerModePageEligibility('https://bad..example').eligible).assertFalse();
      expect(readerModePageEligibility('https://-bad.example').eligible).assertFalse();
      expect(readerModePageEligibility('https://example.com:70000').eligible).assertFalse();
      expect(readerModePageEligibility('https://example.com\u0001x').eligible).assertFalse();
      expect(readerModePageEligibility('https://' + 'a'.repeat(4090) + '.com').eligible).assertFalse();
    });

    it('normalizes host case and default ports but preserves non-default ports', 0, () => {
      expect(readerHostForUrl('HTTPS://Example.COM:443/path')).assertEqual('example.com');
      expect(readerHostForUrl('http://Example.COM:80/path')).assertEqual('example.com');
      expect(readerHostForUrl('https://Example.COM:8443/path')).assertEqual('example.com:8443');
      expect(autoReaderEnabledFor('https://EXAMPLE.com/article', ['example.com'])).assertTrue();
      expect(autoReaderEnabledFor('https://sub.example.com/article', ['example.com'])).assertFalse();
    });

    it('does not persist private-site rules but allows the page to remain eligible', 0, () => {
      const starting: Array<string> = ['example.com'];
      const next: Array<string> = setAutoReaderHost(starting, 'https://private.test/story', true, true);
      expect(next.length).assertEqual(1);
      expect(next[0]).assertEqual('example.com');
      expect(readerModePageEligibility('https://private.test/story').eligible).assertTrue();
      expect(setAutoReaderHost(starting, 'https://site.test', true, false).length).assertEqual(2);
      expect(setAutoReaderHost(['example.com'], 'https://example.com', false, false).length).assertEqual(0);
    });

    it('requires a plausible article candidate', 0, () => {
      expect(isReadableArticleCandidate('Article', 180, 2)).assertTrue();
      expect(isReadableArticleCandidate('Article', 179, 2)).assertFalse();
      expect(isReadableArticleCandidate('', 300, 5)).assertFalse();
      expect(isReadableArticleCandidate('Article', 300, 1)).assertFalse();
    });
  });
}
