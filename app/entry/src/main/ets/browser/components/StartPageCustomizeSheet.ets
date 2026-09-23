import { curves } from '@kit.ArkUI';
import {
  safariImmersiveMaterialIfSupported,
  safariImmersiveSurfaceBackgroundColor
} from '../model/BrowserMaterial';
import {
  availableBrowserSearchEngines,
  BrowserSearchEngine,
  BrowserSettings,
  copyBrowserSettings,
  CustomSearchEngine,
  DEFAULT_BROWSER_SETTINGS,
  normalizeCustomSearchEngine
} from '../model/BrowserSettings';
import { searchEngineLabel } from '../model/BrowserTypes';
import {
  BrowserChromeAnchor,
  browserChromeSurfaceFrame,
  browserChromeSurfaceHorizontalOffset,
  HARMONY_RADIUS_CARD,
  HARMONY_RADIUS_SHEET,
  START_PAGE_CUSTOMIZE_DISMISS_SPRING_DAMPING,
  START_PAGE_CUSTOMIZE_DISMISS_SPRING_OVERLAP,
  START_PAGE_CUSTOMIZE_DISMISS_SPRING_RESPONSE
} from '../model/BrowserVisualMetrics';

/**
 * Native start-page editor.  This sheet owns section-level settings only;
 * bookmark entries and their ordering remain in the bookmark page.
 */
@ComponentV2
export struct StartPageCustomizeSheet {
  @Param settings: BrowserSettings = DEFAULT_BROWSER_SETTINGS;
  @Param topInset: number = 0;
  @Param bottomInset: number = 0;
  @Param viewportWidth: number = 400;
  @Param leftInset: number = 0;
  @Param rightInset: number = 0;
  @Param chromeAnchor: BrowserChromeAnchor = BrowserChromeAnchor.CENTER;
  @Param onSettingsChange: (settings: BrowserSettings) => void =
    (_settings: BrowserSettings) => undefined;
  @Param onSelectBackground: () => void = () => undefined;
  @Param onAdjustBackground: () => void = () => undefined;
  @Param onClose: () => void = () => undefined;
  @Param onDismissStart: () => void = () => undefined;

  @Local engineExpanded: boolean = false;
  @Local customEngineEditorVisible: boolean = false;
  @Local customEngineNameDraft: string = '';
  @Local customEngineUrlDraft: string = '';
  @Local customEngineError: string = '';
  @Local sheetOffsetY: number = 0;
  private sheetSwipeFinished: boolean = false;

  private safeTopInset(): number {
    // The sheet itself is aligned to the bottom of an immersive window. Keep
    // a bounded breathing gap so the title never touches the status capsule,
    // even during the first frame before avoidAreaChange is delivered.
    // This sheet already starts well below the status region. Keep the title
    // close to its rounded top edge instead of reserving a second full safe
    // area inside the sheet.
    return Math.max(0, Math.min(this.topInset, 4));
  }

  private sheetWidth(): number {
    return browserChromeSurfaceFrame(
      this.viewportWidth,
      this.leftInset,
      this.rightInset,
      this.chromeAnchor
    ).width;
  }

  private sheetHorizontalOffset(): number {
    return browserChromeSurfaceHorizontalOffset(
      this.viewportWidth,
      this.leftInset,
      this.rightInset,
      this.chromeAnchor
    );
  }

  private settingWith(
    showFavorites: boolean,
    showFrequentSites: boolean,
    searchEngine: BrowserSearchEngine = this.settings.searchEngine
  ): BrowserSettings {
    const next: BrowserSettings = copyBrowserSettings(this.settings);
    next.showFavorites = showFavorites;
    next.showFrequentSites = showFrequentSites;
    next.searchEngine = searchEngine;
    // A change made from the editor is an explicit opt-in. This marker also
    // prevents legacy persisted defaults from silently reappearing.
    next.startPageSectionsConfigured = true;
    return next;
  }

  private updateSettings(next: BrowserSettings): void {
    this.onSettingsChange(copyBrowserSettings(next));
  }

  private startPageBackgroundLabel(): string {
    return this.settings.startPageBackgroundId.trim() === 'system-gradient'
      ? '系统默认'
      : '调整位置';
  }

  private selectBackgroundAction(): void {
    if (this.settings.startPageBackgroundId.trim() === 'system-gradient') {
      this.onSelectBackground();
      return;
    }
    this.onAdjustBackground();
  }

  private engineOptions(): BrowserSearchEngine[] {
    return availableBrowserSearchEngines(this.settings.customSearchEngine);
  }

  private selectedSearchEngineLabel(): string {
    return searchEngineLabel(this.settings.searchEngine, this.settings.customSearchEngine);
  }

  private openCustomEngineEditor(): void {
    const custom: CustomSearchEngine | undefined = this.settings.customSearchEngine;
    this.customEngineNameDraft = custom?.name ?? '';
    this.customEngineUrlDraft = custom?.urlTemplate ?? '';
    this.customEngineError = '';
    this.engineExpanded = false;
    this.customEngineEditorVisible = true;
  }

  private closeCustomEngineEditor(): void {
    this.customEngineError = '';
    this.customEngineEditorVisible = false;
  }

  private saveCustomEngine(): void {
    const draft: CustomSearchEngine = {
      name: this.customEngineNameDraft,
      urlTemplate: this.customEngineUrlDraft
    };
    const custom: CustomSearchEngine | undefined = normalizeCustomSearchEngine(draft as Object);
    if (custom === undefined) {
      this.customEngineError = '请输入名称，并使用包含 %s 的 HTTP(S) 搜索地址';
      return;
    }
    const next: BrowserSettings = this.settingWith(
      this.settings.showFavorites,
      this.settings.showFrequentSites,
      BrowserSearchEngine.CUSTOM
    );
    next.customSearchEngine = custom;
    this.updateSettings(next);
    this.customEngineError = '';
    this.customEngineEditorVisible = false;
  }

  private removeCustomEngine(): void {
    const nextEngine: BrowserSearchEngine = this.settings.searchEngine === BrowserSearchEngine.CUSTOM
      ? BrowserSearchEngine.BING
      : this.settings.searchEngine;
    const next: BrowserSettings = this.settingWith(
      this.settings.showFavorites,
      this.settings.showFrequentSites,
      nextEngine
    );
    next.customSearchEngine = undefined;
    this.updateSettings(next);
    this.customEngineError = '';
    this.customEngineEditorVisible = false;
  }

  private beginSheetSwipe(): void {
    this.sheetOffsetY = 0;
    this.sheetSwipeFinished = false;
  }

  private updateSheetSwipe(event?: GestureEvent): void {
    if (this.sheetSwipeFinished) {
      return;
    }
    this.sheetOffsetY = Math.max(0, event?.offsetY ?? 0);
  }

  private finishSheetSwipe(): void {
    if (this.sheetSwipeFinished) {
      return;
    }
    this.sheetSwipeFinished = true;
    if (this.sheetOffsetY < 80) {
      this.getUIContext().animateTo({
        curve: curves.springMotion(
          START_PAGE_CUSTOMIZE_DISMISS_SPRING_RESPONSE,
          START_PAGE_CUSTOMIZE_DISMISS_SPRING_DAMPING,
          START_PAGE_CUSTOMIZE_DISMISS_SPRING_OVERLAP
        )
      }, () => {
        this.sheetOffsetY = 0;
      });
      return;
    }
    this.onDismissStart();
    // The parent owns the single dismissal spring. Starting another spring to
    // a fixed 260vp offset here creates a visible pause before the removal
    // transition begins. Keep the current drag offset and hand off directly
    // so the sheet continues downward without a two-stage stop.
    this.onClose();
  }

  private cancelSheetSwipe(): void {
    this.sheetSwipeFinished = true;
    this.getUIContext().animateTo({
      curve: curves.springMotion(
        START_PAGE_CUSTOMIZE_DISMISS_SPRING_RESPONSE,
        START_PAGE_CUSTOMIZE_DISMISS_SPRING_DAMPING,
        START_PAGE_CUSTOMIZE_DISMISS_SPRING_OVERLAP
      )
    }, () => {
      this.sheetOffsetY = 0;
    });
  }

  @Builder
  private toggleRow(id: string, icon: Resource, title: string, value: boolean,
    onChange: (enabled: boolean) => void) {
    Row({ space: 12 }) {
      SymbolGlyph(icon)
        .id(`${id}-icon`)
        .fontSize(22)
        .fontColor(['#1D1D1F']);
      Text(title)
        .fontSize(16)
        .fontColor('#1D1D1F')
        .layoutWeight(1);
      Toggle({ type: ToggleType.Switch, isOn: value })
        .id(`${id}-toggle`)
        .selectedColor('#007AFF')
        .switchPointColor(Color.White)
        .onChange(onChange);
    }
      .id(id)
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 12 })
      .border({ width: { bottom: 1 }, color: '#E5E5EA' });
  }

  @Builder
  private engineRow() {
    Column() {
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(22)
          .fontColor(['#1D1D1F']);
        Text('搜索引擎')
          .fontSize(16)
          .fontColor('#1D1D1F')
          .layoutWeight(1);
        Button(this.selectedSearchEngineLabel(), { type: ButtonType.Normal, stateEffect: false })
          .id('start-page-search-engine-value')
          .fontSize(14)
          .fontColor('#007AFF')
          .backgroundColor(Color.Transparent)
          .padding({ left: 8, right: 0 })
          .stateEffect(false)
          .onClick(() => this.engineExpanded = !this.engineExpanded);
        SymbolGlyph(this.engineExpanded ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
          .fontSize(15)
          .fontColor(['#8E8E93']);
      }
        .id('start-page-search-engine-row')
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 });

      if (this.engineExpanded) {
        Column() {
          ForEach(this.engineOptions(), (engine: BrowserSearchEngine) => {
            Button({ type: ButtonType.Normal, stateEffect: false }) {
              Row() {
                Text(searchEngineLabel(engine, this.settings.customSearchEngine))
                  .fontSize(15)
                  .fontColor('#1D1D1F')
                  .layoutWeight(1);
                if (this.settings.searchEngine === engine) {
                  SymbolGlyph($r('sys.symbol.checkmark'))
                    .fontSize(18)
                    .fontColor(['#007AFF']);
                }
              }
                .width('100%')
                .height(44);
            }
              .id(`start-page-search-engine-${engine}`)
              .width('100%')
              .height(44)
              .padding({ left: 52, right: 16 })
              .backgroundColor(Color.Transparent)
              .stateEffect(false)
              .onClick(() => {
                this.updateSettings(this.settingWith(
                  this.settings.showFavorites,
                  this.settings.showFrequentSites,
                  engine
                ));
                this.engineExpanded = false;
              });
          }, (engine: BrowserSearchEngine) => engine);
        }
          .width('100%')
          .backgroundColor('#F8F8FA');
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          Row() {
            Text('编辑')
              .fontSize(15)
              .fontColor('#007AFF')
              .layoutWeight(1);
            SymbolGlyph($r('sys.symbol.pencil_line'))
              .fontSize(18)
              .fontColor(['#007AFF']);
          }
            .width('100%')
            .height(44);
        }
          .id('start-page-search-engine-edit')
          .width('100%')
          .height(44)
          .padding({ left: 52, right: 16 })
          .backgroundColor(Color.Transparent)
          .stateEffect(false)
          .onClick(() => this.openCustomEngineEditor());
      }
    }
      .id('start-page-search-engine-section')
      .width('100%')
      // Every settings group uses the same quiet gray surface; only the
      // expanded options get a slightly lighter inset to preserve hierarchy.
      .backgroundColor('#F2F2F7')
      .border({ width: { bottom: 1 }, color: '#E5E5EA' });
  }

  @Builder
  private customEngineEditor() {
    Column() {
      Blank()
        .width('100%')
        .height(this.safeTopInset());
      Row() {
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(18)
            .fontColor(['#6B6B72']);
        }
          .id('custom-search-engine-cancel')
          .width(44)
          .height(44)
          .padding(0)
          .backgroundColor(Color.Transparent)
          .stateEffect(false)
          .onClick(() => this.closeCustomEngineEditor());
        Text('编辑搜索引擎')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1D1D1F')
          .layoutWeight(1)
          .textAlign(TextAlign.Center);
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          Text('保存')
            .fontSize(15)
            .fontColor('#007AFF');
        }
          .id('custom-search-engine-save')
          .width(56)
          .height(44)
          .padding(0)
          .backgroundColor(Color.Transparent)
          .stateEffect(false)
          .onClick(() => this.saveCustomEngine());
      }
        .id('custom-search-engine-header')
        .width('100%')
        .height(48)
        .padding({ left: 8, right: 8 });

      Scroll() {
        Column({ space: 12 }) {
          Text('自定义搜索引擎')
            .fontSize(13)
            .fontColor('#6B6B72')
            .width('100%');
          TextInput({
            text: this.customEngineNameDraft,
            placeholder: '名称'
          })
            .id('custom-search-engine-name-input')
            .width('100%')
            .height(52)
            .padding({ left: 16, right: 16 })
            .fontSize(16)
            .fontColor('#1D1D1F')
            .placeholderColor('#8E8E93')
            .backgroundColor('#F2F2F7')
            .borderRadius(HARMONY_RADIUS_CARD)
            .onChange((value: string) => this.customEngineNameDraft = value);
          Text('搜索 URL 模板')
            .fontSize(13)
            .fontColor('#6B6B72')
            .width('100%');
          TextInput({
            text: this.customEngineUrlDraft,
            placeholder: 'https://example.com/search?q=%s'
          })
            .id('custom-search-engine-url-input')
            .width('100%')
            .height(52)
            .padding({ left: 16, right: 16 })
            .fontSize(14)
            .fontColor('#1D1D1F')
            .placeholderColor('#8E8E93')
            .backgroundColor('#F2F2F7')
            .borderRadius(HARMONY_RADIUS_CARD)
            .onChange((value: string) => this.customEngineUrlDraft = value);
          Text('使用 %s 代表搜索关键词，地址必须以 HTTP 或 HTTPS 开头。')
            .fontSize(12)
            .fontColor('#8E8E93')
            .width('100%');
          if (this.customEngineError.length > 0) {
            Text(this.customEngineError)
              .id('custom-search-engine-error')
              .fontSize(12)
              .fontColor('#FF3B30')
              .width('100%');
          }
          if (this.settings.customSearchEngine !== undefined) {
            Button({ type: ButtonType.Normal, stateEffect: false }) {
              Text('删除自定义搜索引擎')
                .fontSize(15)
                .fontColor('#FF3B30');
            }
              .id('custom-search-engine-delete')
              .width('100%')
              .height(48)
              .backgroundColor('#F2F2F7')
              .borderRadius(HARMONY_RADIUS_CARD)
              .stateEffect(false)
              .onClick(() => this.removeCustomEngine());
          }
        }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 24 });
      }
        .id('custom-search-engine-scroll')
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off);

      Blank()
        .width('100%')
        .height(Math.max(0, this.bottomInset));
    }
      .id('custom-search-engine-editor')
      .width('100%')
      .height('100%');
  }

  @Builder
  private backgroundRow() {
    Row({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.circle_lefthalf_inset_filled'))
        .fontSize(22)
        .fontColor(['#1D1D1F']);
      Text('初始页背景')
        .fontSize(16)
        .fontColor('#1D1D1F')
        .layoutWeight(1);
      Text(this.startPageBackgroundLabel())
        .fontSize(14)
        .fontColor('#007AFF');
      SymbolGlyph($r('sys.symbol.chevron_down'))
        .fontSize(15)
        .fontColor(['#8E8E93']);
    }
      .id('start-page-background-row')
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .onClick(() => this.selectBackgroundAction());
  }

  build() {
      Column() {
      // Measure the sheet against the full window and anchor it at the
      // bottom. A direct height on the component itself can otherwise be
      // aligned to the remaining content area above the browser chrome.
      Blank()
        .width('100%')
        .layoutWeight(1);

      Column() {
        if (this.customEngineEditorVisible) {
          this.customEngineEditor();
        } else {
          Blank()
        .width('100%')
        .height(this.safeTopInset());
        Row() {
          Text('自定义起始页')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1D1D1F')
            .layoutWeight(1)
            .textAlign(TextAlign.Center);
        }
        .id('start-page-customize-header')
        .width('100%')
        .height(40)
        .padding({ left: 8, right: 8 });

      Scroll() {
        Column({ space: 16 }) {
          Column() {
            this.toggleRow('start-page-favorites-toggle', $r('sys.symbol.star'), '书签',
              this.settings.showFavorites, (enabled: boolean) => {
                this.updateSettings(this.settingWith(enabled, this.settings.showFrequentSites));
              });
            this.engineRow();
          }
            .width('100%')
            .backgroundColor('#F2F2F7')
            .clip(true)
            .borderRadius(HARMONY_RADIUS_CARD);

          Column() {
            this.backgroundRow();
          }
            .id('start-page-background-card')
            .width('100%')
            .backgroundColor('#F2F2F7')
            .clip(true)
            .borderRadius(HARMONY_RADIUS_CARD);

        }
          .width('100%')
          .height('100%')
          .padding({ left: 12, right: 12, bottom: 24 });
      }
        .id('start-page-customize-scroll')
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off);

      Blank()
        .width('100%')
        .height(Math.max(0, this.bottomInset));
        }
      }
        .id('start-page-customize-sheet')
        .width(this.sheetWidth())
        .alignSelf(ItemAlign.Center)
        // Keep the editor just high enough to cover the start-page edit affordance;
        // the rest of the options remain reachable through the native Scroll.
      .height('56%')
        .backgroundColor(safariImmersiveSurfaceBackgroundColor())
        .borderRadius({ topLeft: HARMONY_RADIUS_SHEET, topRight: HARMONY_RADIUS_SHEET })
        .clip(true)
        .systemMaterial(safariImmersiveMaterialIfSupported())
        .translate({ x: this.sheetHorizontalOffset(), y: this.sheetOffsetY, z: 0 })
        .parallelGesture(
          PanGesture({ direction: PanDirection.Down })
            .onActionStart(() => this.beginSheetSwipe())
            .onActionUpdate((event: GestureEvent | undefined) => this.updateSheetSwipe(event))
            .onActionEnd(() => this.finishSheetSwipe())
            .onActionCancel(() => this.cancelSheetSwipe())
        )
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM]);
    }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent);
  }
}
