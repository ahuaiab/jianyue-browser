import {
  DEFAULT_READER_MODE_PREFERENCES,
  ReaderModePreferences,
  ReaderModeTextSize,
  ReaderModeTheme
} from '../model/ReaderMode';

@ComponentV2
export struct ReaderMenuControls {
  @Param preferences: ReaderModePreferences = DEFAULT_READER_MODE_PREFERENCES;
  @Param autoReaderEnabled: boolean = false;
  @Param allowAutoReaderChange: boolean = false;
  @Param onTextSizeChange: (size: ReaderModeTextSize) => void = (_size: ReaderModeTextSize) => undefined;
  @Param onThemeChange: (theme: ReaderModeTheme) => void = (_theme: ReaderModeTheme) => undefined;
  @Param onAutoReaderChange: (enabled: boolean) => void = (_enabled: boolean) => undefined;

  @Builder
  private sizeChoice(label: string, size: ReaderModeTextSize) {
    Button(label, { type: ButtonType.Normal, stateEffect: false })
      .id('reader-size-' + size)
      .accessibilityText(size === 'small' ? '小字号' : size === 'large' ? '大字号' : '标准字号')
      .height(34)
      .padding({ left: 14, right: 14 })
      .borderRadius(17)
      .backgroundColor(this.preferences.textSize === size ? '#DCEEFF' : '#F1F2F4')
      .fontColor(this.preferences.textSize === size ? '#006EDB' : '#30343A')
      .onClick(() => this.onTextSizeChange(size));
  }

  @Builder
  private themeChoice(theme: ReaderModeTheme, color: string, description: string) {
    Button('', { type: ButtonType.Normal, stateEffect: false })
      .id('reader-theme-' + theme)
      .accessibilityText(description)
      .width(32)
      .height(32)
      .padding(0)
      .borderRadius(16)
      .backgroundColor(color)
      .border({
        width: this.preferences.theme === theme ? 2 : 1,
        color: this.preferences.theme === theme ? '#1684E8' : '#C8CCD1'
      })
      .onClick(() => this.onThemeChange(theme));
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 12 }) {
        Text('字号')
          .fontSize(14)
          .fontColor('#5D6268')
          .width(42);
        this.sizeChoice('A−', 'small');
        this.sizeChoice('A', 'standard');
        this.sizeChoice('A+', 'large');
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center);

      Row({ space: 12 }) {
        Text('背景')
          .fontSize(14)
          .fontColor('#5D6268')
          .width(42);
        this.themeChoice('white', '#FFFFFF', '白色背景');
        this.themeChoice('sepia', '#F4ECD8', '米色背景');
        this.themeChoice('gray', '#EDEDED', '灰色背景');
        this.themeChoice('dark', '#242628', '深色背景');
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center);

      if (this.allowAutoReaderChange) {
        Row() {
          Text('自动使用阅读器')
            .fontSize(14)
            .fontColor('#30343A')
            .layoutWeight(1);
          Toggle({ type: ToggleType.Switch, isOn: this.autoReaderEnabled })
            .id('reader-auto-toggle')
            .accessibilityText('自动使用阅读器')
            .onChange((enabled: boolean) => this.onAutoReaderChange(enabled));
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }
}
