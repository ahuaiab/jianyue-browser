import { Component, Driver, ON, Point } from '@kit.TestKit';
import { beforeAll, describe, expect, it } from '@ohos/hypium';

export default function browserVisualSizingTest() {
  describe('BrowserVisualSizing', () => {
    let driver: Driver;

    beforeAll(() => {
      driver = Driver.create();
    });

    it('uses a 26vp visual container for the tab overview icon', 0, async () => {
      const iconContainer: Component = await driver.findComponent(ON.id('tab-overview-icon-container'));
      const bounds = await iconContainer.getBounds();
      const density: Point = await driver.getDisplayDensity();
      const widthVp: number = (bounds.right - bounds.left) / density.x;
      const heightVp: number = (bounds.bottom - bounds.top) / density.y;

      expect(Math.round(widthVp)).assertEqual(26);
      expect(Math.round(heightVp)).assertEqual(26);
    });

    it('shows labeled bookmark and history tabs and switches their lists', 0, async () => {
      const sheets: Array<Component> = await driver.findComponents(ON.id('library-sheet'));
      if (sheets.length === 0) {
        const libraryButton: Component = await driver.findComponent(ON.id('browser-library-button'));
        await libraryButton.click();
        await driver.delayMs(500);
      }

      await driver.assertComponentExist(ON.id('library-section-label-bookmarks'));
      await driver.assertComponentExist(ON.id('library-section-label-history'));

      const historyTab: Component = await driver.findComponent(ON.id('library-section-history'));
      await historyTab.click();
      await driver.delayMs(500);
      const historyLists: Array<Component> = await driver.findComponents(ON.id('library-entry-scroll-history'));
      const emptyHistorySurfaces: Array<Component> = await driver.findComponents(ON.id('library-empty-state'));
      expect(historyLists.length + emptyHistorySurfaces.length).assertEqual(1);

      const bookmarksTab: Component = await driver.findComponent(ON.id('library-section-bookmarks'));
      await bookmarksTab.click();
      await driver.delayMs(500);
      await driver.assertComponentExist(ON.id('library-entry-scroll-bookmarks'));
    });
  });
}
