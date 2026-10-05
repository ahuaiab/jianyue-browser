import { describe, expect, it } from '@ohos/hypium';
import {
  googleSearchCompatibleUserAgentFor,
  isGoogleSearchUrl
} from '../../../main/ets/browser/model/PageActions';

export default function googleSearchUserAgentTest() {
  describe('GoogleSearchUserAgent', () => {
    it('normalizes the observed OpenHarmony 7 and Chrome 144 phone UA without changing versions', 0, () => {
      const nativeUserAgent: string = 'Mozilla/5.0 (Phone; OpenHarmony 7.0) AppleWebKit/537.36 ' +
        '(KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36  ArkWeb/7.0.0.107 Mobile';
      const expectedMobile: string = 'Mozilla/5.0 (Linux; OpenHarmony 7.0) AppleWebKit/537.36 ' +
        '(KHTML, like Gecko) Chrome/144.0.0.0 Mobile Safari/537.36';
      const expectedDesktop: string = 'Mozilla/5.0 (Linux; OpenHarmony 7.0) AppleWebKit/537.36 ' +
        '(KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36';

      expect(googleSearchCompatibleUserAgentFor(nativeUserAgent)).assertEqual(expectedMobile);
      expect(googleSearchCompatibleUserAgentFor(nativeUserAgent, false)).assertEqual(expectedDesktop);

      const emulatorUserAgent: string = 'Mozilla/5.0 (Phone; OpenHarmony 7.0) AppleWebKit/537.36 ' +
        '(KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36 ArkWeb/7.0.0.105 Mobile';
      expect(googleSearchCompatibleUserAgentFor(emulatorUserAgent)).assertEqual(expectedMobile);
    });

    it('leaves empty and unknown engine identities unchanged', 0, () => {
      const unknownUserAgent: string = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/99 Safari/537.36 Mobile';

      expect(googleSearchCompatibleUserAgentFor('')).assertEqual('');
      expect(googleSearchCompatibleUserAgentFor(unknownUserAgent)).assertEqual(unknownUserAgent);
      expect(googleSearchCompatibleUserAgentFor(unknownUserAgent, false))
        .assertEqual('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/99 Safari/537.36');
    });

    it('matches only the Google hosts covered by the host-scoped rule', 0, () => {
      expect(isGoogleSearchUrl('https://google.com/search?q=browser')).assertTrue();
      expect(isGoogleSearchUrl('https://www.google.com:443/search')).assertTrue();
      expect(isGoogleSearchUrl('https://google.com.evil.test/search')).assertFalse();
      expect(isGoogleSearchUrl('https://user@google.com.evil.test/')).assertFalse();
      expect(isGoogleSearchUrl('https://evil.test\\@www.google.com/')).assertFalse();
      expect(isGoogleSearchUrl('https://evil.test/?next=https://google.com')).assertFalse();
      expect(isGoogleSearchUrl('https://google.co.uk/search')).assertFalse();
    });
  });
}
