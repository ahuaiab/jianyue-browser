import { describe, expect, it } from '@ohos/hypium';
import {
  interceptExternalAppNavigation,
  isExternalAppNavigationUrl
} from '../../../main/ets/browser/web/ExternalAppNavigation';

export default function externalAppNavigationTest() {
  describe('ExternalAppNavigation', () => {
    it('keeps web and WebView-internal schemes in the current page', 0, () => {
      expect(isExternalAppNavigationUrl('https://example.com/path')).assertFalse();
      expect(isExternalAppNavigationUrl('HTTP://example.com')).assertFalse();
      expect(isExternalAppNavigationUrl('about:blank')).assertFalse();
      expect(isExternalAppNavigationUrl('data:text/plain,hello')).assertFalse();
      expect(isExternalAppNavigationUrl('javascript:void(0)')).assertFalse();
      expect(isExternalAppNavigationUrl('file:///data/index.html')).assertFalse();
      expect(isExternalAppNavigationUrl('//example.com/path')).assertFalse();
    });

    it('hands app links to the system without changing their URI', 0, () => {
      const launched: Array<string> = [];
      const failedSchemes: Array<string> = [];
      const openLink: (uri: string) => Promise<void> = async (uri: string) => {
        launched.push(uri);
      };

      expect(interceptExternalAppNavigation(
        'mailto:hello@example.com?subject=Hello', openLink,
        (scheme: string) => failedSchemes.push(scheme)
      )).assertTrue();
      expect(interceptExternalAppNavigation(
        'sampleapp://open/page?id=7', openLink,
        (scheme: string) => failedSchemes.push(scheme)
      )).assertTrue();

      expect(launched.length).assertEqual(2);
      expect(launched[0]).assertEqual('mailto:hello@example.com?subject=Hello');
      expect(launched[1]).assertEqual('sampleapp://open/page?id=7');
      expect(failedSchemes.length).assertEqual(0);
    });

    it('contains asynchronous launch failures and still blocks the invalid WebView load', 0, async () => {
      const failedSchemes: Array<string> = [];
      const openLink: (uri: string) => Promise<void> = async (_uri: string) => {
        throw new Error('no matching application');
      };

      expect(interceptExternalAppNavigation(
        'customapp://open', openLink,
        (scheme: string) => failedSchemes.push(scheme)
      )).assertTrue();
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, 0));

      expect(failedSchemes.length).assertEqual(1);
      expect(failedSchemes[0]).assertEqual('customapp');
    });

    it('contains synchronous launch failures without exposing the URI to the failure handler', 0, () => {
      const failedSchemes: Array<string> = [];
      const openLink: (uri: string) => Promise<void> = (_uri: string) => {
        throw new Error('invalid launch context');
      };

      expect(interceptExternalAppNavigation(
        'tel:12345678', openLink,
        (scheme: string) => failedSchemes.push(scheme)
      )).assertTrue();
      expect(failedSchemes.length).assertEqual(1);
      expect(failedSchemes[0]).assertEqual('tel');
    });

    it('blocks external navigation when the host ability context is unavailable', 0, () => {
      const failedSchemes: Array<string> = [];

      expect(interceptExternalAppNavigation(
        'sampleapp://open', undefined,
        (scheme: string) => failedSchemes.push(scheme)
      )).assertTrue();
      expect(failedSchemes.length).assertEqual(1);
      expect(failedSchemes[0]).assertEqual('sampleapp');
    });
  });
}
