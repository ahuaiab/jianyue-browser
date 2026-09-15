import { StartPageBackgroundImage } from './StartPageBackgroundImage';
import {
  DEFAULT_START_PAGE_BACKGROUND_POSITION,
  StartPageBackgroundPosition
} from '../model/BrowserSettings';
import { HARMONY_RADIUS_CARD, HARMONY_RADIUS_SHEET } from '../model/BrowserVisualMetrics';

/** Full-screen bottom sheet shown after a photo is selected for the start page. */
@ComponentV2
export struct StartPageBackgroundAdjustSheet {
  @Param source: string = '';
  @Param backgroundPosition: StartPageBackgroundPosition = DEFAULT_START_PAGE_BACKGROUND_POSITION;
  @Param topInset: number = 0;
  @Param bottomInset: number = 0;
  @Param onPositionChange: (position: StartPageBackgroundPosition) => void =
    (_position: StartPageBackgroundPosition) => undefined;
  @Param onCancel: () => void = () => undefined;
  @Param onComplete: (position: StartPageBackgroundPosition) => void =
    (_position: StartPageBackgroundPosition) => undefined;
  @Param onSelectAnother: () => void = () => undefined;

  private resetPosition(): void {
    this.onPositionChange({
      x: DEFAULT_START_PAGE_BACKGROUND_POSITION.x,
      y: DEFAULT_START_PAGE_BACKGROUND_POSITION.y
    });
  }

  @Builder
  private header() {
    Row() {
      Button({ type: ButtonType.Normal, stateEffect: false }) {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(18)
          .fontColor(['#6B7280']);
      }
        .id('start-page-background-adjust-cancel')
        .width(44)
        .height(44)
        .padding(0)
        .backgroundColor(Color.Transparent)
        .onClick(() => this.onCancel());

      Text('调整背景')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1D1D1F')
        .layoutWeight(1)
        .textAlign(TextAlign.Center);

      Button('完成', { type: ButtonType.Normal, stateEffect: false })
        .id('start-page-background-adjust-complete')
        .width(64)
        .height(40)
        .padding(0)
        .fontSize(15)
        .fontColor('#007AFF')
        .backgroundColor(Color.Transparent)
        .onClick(() => this.onComplete(this.backgroundPosition));
    }
      .id('start-page-background-adjust-header')
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 });
  }

  @Builder
  private actions() {
    Row({ space: 12 }) {
      Button('重置', { type: ButtonType.Normal, stateEffect: false })
        .id('start-page-background-adjust-reset')
        .layoutWeight(1)
        .height(44)
        .fontSize(15)
        .fontColor('#1D1D1F')
        .backgroundColor('#F2F2F7')
        .borderRadius(HARMONY_RADIUS_CARD)
        .onClick(() => this.resetPosition());
      Button('更换图片', { type: ButtonType.Normal, stateEffect: false })
        .id('start-page-background-adjust-select')
        .layoutWeight(1)
        .height(44)
        .fontSize(15)
        .fontColor('#007AFF')
        .backgroundColor('#F2F2F7')
        .borderRadius(HARMONY_RADIUS_CARD)
        .onClick(() => this.onSelectAnother());
    }
      .width('100%')
      .padding({ left: 16, right: 16 });
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
      }
        .width('100%')
        .layoutWeight(1);

      Column() {
        Blank()
          .width('100%')
          .height(Math.max(0, Math.min(this.topInset, 8)));
        this.header();

        Stack() {
          StartPageBackgroundImage({
            source: this.source,
            backgroundPosition: this.backgroundPosition,
            interactive: true,
            onPositionChange: (position: StartPageBackgroundPosition) => this.onPositionChange(position)
          })
            .id('start-page-background-adjust-preview-image')
            .width('100%')
            .height('100%');
          Text('拖动图片调整位置')
            .id('start-page-background-adjust-hint')
            .fontSize(13)
            .fontColor(Color.White)
            .backgroundColor('#88000000')
            .borderRadius(16)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .align(Alignment.Bottom)
            .margin({ bottom: 16 });
        }
          .id('start-page-background-adjust-preview')
          .layoutWeight(1)
          .width('100%')
          .margin({ left: 12, right: 12 })
          .borderRadius(HARMONY_RADIUS_CARD)
          .clip(true)
          .backgroundColor('#F2F2F7');

        Blank()
          .width('100%')
          .height(12);
        this.actions();
        Blank()
          .width('100%')
          .height(Math.max(0, this.bottomInset));
      }
        .id('start-page-background-adjust-sheet')
        .width('100%')
        .height('72%')
        .backgroundColor(Color.White)
        .borderRadius({ topLeft: HARMONY_RADIUS_SHEET, topRight: HARMONY_RADIUS_SHEET })
        .shadow({ radius: 18, color: '#55000000', offsetX: 0, offsetY: -4 })
        .clip(true)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM]);
    }
      .id('start-page-background-adjust-overlay')
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent);
  }
}
