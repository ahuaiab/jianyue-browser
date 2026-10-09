import { describe, expect, it } from '@ohos/hypium';
import { PageLoadProgressStore } from '../../../main/ets/browser/model/PageLoadProgress';

export default function pageLoadProgressTest() {
  describe('PageLoadProgress', () => {
    it('uses only real progress after a web page begins loading', 0, () => {
      const store: PageLoadProgressStore = new PageLoadProgressStore();
      expect(store.update('a', 25, 1000)).assertFalse();
      expect(store.progressFor('a')).assertEqual(0);
      store.begin('a', 'https://example.com');
      expect(store.progressFor('a')).assertEqual(0);
      expect(store.update('a', 37, 1100)).assertTrue();
      expect(store.progressFor('a')).assertEqual(37);
      expect(store.update('a', 37, 1200)).assertFalse();
      expect(store.nextVisibilityDelay('a', 1200)).assertUndefined();
    });

    it('keeps a fast load visible for one second before fading', 0, () => {
      const store: PageLoadProgressStore = new PageLoadProgressStore();
      store.begin('a', 'https://example.com');
      store.update('a', 15, 1100);
      expect(store.update('a', 100, 1130)).assertTrue();
      expect(store.progressFor('a')).assertEqual(100);
      expect(store.opacityFor('a')).assertEqual(1);
      expect(store.nextVisibilityDelay('a', 1130)).assertEqual(970);
      expect(store.advanceVisibility('a', 2099)).assertFalse();
      expect(store.advanceVisibility('a', 2100)).assertTrue();
      expect(store.progressFor('a')).assertEqual(100);
      expect(store.opacityFor('a')).assertEqual(0);
      expect(store.nextVisibilityDelay('a', 2100)).assertEqual(250);
      expect(store.advanceVisibility('a', 2349)).assertFalse();
      expect(store.advanceVisibility('a', 2350)).assertTrue();
      expect(store.progressFor('a')).assertEqual(0);
      expect(store.update('a', 99, 2400)).assertFalse();
    });

    it('holds completion for half a second without extending it on duplicate events', 0, () => {
      const store: PageLoadProgressStore = new PageLoadProgressStore();
      store.begin('a', 'https://example.com');
      store.update('a', 30, 1000);
      store.update('a', 100, 5000);
      expect(store.complete('a', 5100)).assertFalse();
      expect(store.update('a', 99, 5100)).assertFalse();
      expect(store.update('a', 100, 5100)).assertFalse();
      expect(store.nextVisibilityDelay('a', 5100)).assertEqual(400);
      expect(store.progressFor('a')).assertEqual(100);
      expect(store.advanceVisibility('a', 5499)).assertFalse();
      expect(store.advanceVisibility('a', 5500)).assertTrue();
      expect(store.opacityFor('a')).assertEqual(0);
      expect(store.advanceVisibility('a', 5750)).assertTrue();
      expect(store.progressFor('a')).assertEqual(0);
    });

    it('presents page-end completion even without a positive progress callback', 0, () => {
      const store: PageLoadProgressStore = new PageLoadProgressStore();
      store.begin('a', 'https://example.com');
      expect(store.complete('a', 2000)).assertTrue();
      expect(store.progressFor('a')).assertEqual(100);
      expect(store.nextVisibilityDelay('a', 2000)).assertEqual(1000);
      expect(store.complete('a', 2200)).assertFalse();
      store.advanceVisibility('a', 3000);
      expect(store.opacityFor('a')).assertEqual(0);
      store.advanceVisibility('a', 3250);
      expect(store.progressFor('a')).assertEqual(0);
    });

    it('clears errors immediately and ignores late completion callbacks', 0, () => {
      const store: PageLoadProgressStore = new PageLoadProgressStore();
      store.begin('a', 'https://example.com');
      store.update('a', 65, 1000);
      store.complete('a', 2000);
      expect(store.finish('a')).assertTrue();
      expect(store.progressFor('a')).assertEqual(0);
      expect(store.nextVisibilityDelay('a', 2100)).assertUndefined();
      expect(store.complete('a', 2100)).assertFalse();
      expect(store.update('a', 75, 2100)).assertFalse();
      expect(store.advanceVisibility('a', 5000)).assertFalse();
    });

    it('does not let an old visibility deadline hide a new navigation', 0, () => {
      const store: PageLoadProgressStore = new PageLoadProgressStore();
      store.begin('a', 'https://example.com/old');
      store.update('a', 20, 0);
      store.complete('a', 100);
      store.begin('a', 'https://example.com/new');
      store.update('a', 30, 140);
      expect(store.advanceVisibility('a', 1000)).assertFalse();
      expect(store.progressFor('a')).assertEqual(30);
      store.complete('a', 1010);
      expect(store.advanceVisibility('a', 1250)).assertFalse();
      expect(store.progressFor('a')).assertEqual(100);
      expect(store.opacityFor('a')).assertEqual(1);
      expect(store.advanceVisibility('a', 1510)).assertTrue();
      expect(store.opacityFor('a')).assertEqual(0);
    });

    it('keeps timing isolated by tab and clears blank pages and removed tabs', 0, () => {
      const store: PageLoadProgressStore = new PageLoadProgressStore();
      store.begin('a', 'https://example.com/a');
      store.begin('b', 'https://example.com/b');
      store.update('a', 30, 1000);
      store.update('b', 70, 1000);
      store.complete('a', 1100);
      store.advanceVisibility('a', 2000);
      expect(store.opacityFor('a')).assertEqual(0);
      expect(store.progressFor('b')).assertEqual(70);
      expect(store.opacityFor('b')).assertEqual(1);
      expect(store.progressFor('blank')).assertEqual(0);
      store.begin('a', 'about:blank');
      expect(store.progressFor('a')).assertEqual(0);
      expect(store.advanceVisibility('a', 2250)).assertFalse();
      store.clear();
      expect(store.progressFor('b')).assertEqual(0);
      expect(store.update('b', 90, 3000)).assertFalse();
    });

    it('rejects non-finite progress and bounds native percentages', 0, () => {
      const store: PageLoadProgressStore = new PageLoadProgressStore();
      store.begin('a', 'https://example.com');
      store.update('a', 40, 1000);
      expect(store.update('a', Number.NaN, 1001)).assertFalse();
      expect(store.update('a', Number.POSITIVE_INFINITY, 1001)).assertFalse();
      expect(store.progressFor('a')).assertEqual(40);
      store.update('a', -5, 1002);
      expect(store.progressFor('a')).assertEqual(0);
      store.update('a', 50.5, 1003);
      expect(store.progressFor('a')).assertEqual(50.5);
      store.update('a', 101, 1004);
      expect(store.progressFor('a')).assertEqual(100);
    });
  });
}
