import { StartPageBackgroundImage } from './StartPageBackgroundImage';
import {
  DEFAULT_START_PAGE_BACKGROUND_POSITION,
  DEFAULT_START_PAGE_BACKGROUND_SCALE,
  normalizeStartPageBackgroundScale,
  StartPageBackgroundPosition
} from '../model/BrowserSettings';
import { HARMONY_RADIUS_CARD, HARMONY_RADIUS_SHEET } from '../model/BrowserVisualMetrics';

/** Full-screen bottom sheet shown after a photo is selected for the start page. */
@ComponentV2
export struct StartPageBackgroundAdjustSheet {
  @Param source: string = '';
  @Param backgroundPosition: StartPageBackgroundPosition = DEFAULT_START_PAGE_BACKGROUND_POSITION;
  @Param backgroundScale: number = DEFAULT_START_PAGE_BACKGROUND_SCALE;
  @Param pageViewportWidth: number = 1;
  @Param pageViewportHeight: number = 1;
  @Param topInset: number = 0;
  @Param bottomInset: number = 0;
  @Param onPositionChange: (position: StartPageBackgroundPosition) => void =
    (_position: StartPageBackgroundPosition) => undefined;
  @Param onScaleChange: (scale: number) => void = (_scale: number) => undefined;
  @Param onCancel: () => void = () => undefined;
  @Param onComplete: (position: StartPageBackgroundPosition, scale: number) => void =
    (_position: StartPageBackgroundPosition, _scale: number) => undefined;
  @Param onSelectAnother: () => void = () => undefined;
  @Local previewWidth: number = 0;
  @Local previewHeight: number = 0;

  private pageAspectRatio(): number {
    const width: number = Number.isFinite(this.pageViewportWidth) && this.pageViewportWidth > 0
      ? this.pageViewportWidth
      : 1;
    const height: number = Number.isFinite(this.pageViewportHeight) && this.pageViewportHeight > 0
      ? this.pageViewportHeight
      : 1;
    return width / height;
  }

  private updatePreviewArea(area: Area): void {
    const width: number = Number(area.width);
    const height: number = Number(area.height);
    if (Number.isFinite(width) && width > 0 && this.previewWidth !== width) {
      this.previewWidth = width;
    }
    if (Number.isFinite(height) && height > 0 && this.previewHeight !== height) {
      this.previewHeight = height;
    }
  }

  private previewFrameWidth(): number {
    const maxWidth: number = this.previewWidth > 0 ? this.previewWidth : this.pageViewportWidth;
    const maxHeight: number = this.previewHeight > 0 ? this.previewHeight : this.pageViewportHeight;
    return Math.max(1, Math.min(maxWidth, maxHeight * this.pageAspectRatio()));
  }

  private previewFrameHeight(): number {
    return this.previewFrameWidth() / this.pageAspectRatio();
  }

  private resetPosition(): void {
    this.onPositionChange({
      x: DEFAULT_START_PAGE_BACKGROUND_POSITION.x,
      y: DEFAULT_START_PAGE_BACKGROUND_POSITION.y
    });
    this.onScaleChange(DEFAULT_START_PAGE_BACKGROUND_SCALE);
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
        .onClick(() => this.onComplete(
          this.backgroundPosition,
          normalizeStartPageBackgroundScale(this.backgroundScale)
        ));
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

        Stack({ alignContent: Alignment.Center }) {
          Stack() {
            StartPageBackgroundImage({
              source: this.source,
              backgroundPosition: this.backgroundPosition,
              backgroundScale: this.backgroundScale,
              interactive: true,
              onPositionChange: (position: StartPageBackgroundPosition) => this.onPositionChange(position),
              onScaleChange: (scale: number) => this.onScaleChange(scale)
            })
              .id('start-page-background-adjust-preview-image')
              .width('100%')
              .height('100%');
            Text('拖动或双指缩放')
              .id('start-page-background-adjust-hint')
              .fontSize(13)
              .fontColor(Color.White)
              .backgroundColor('#88000000')
              .borderRadius(16)
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .align(Alignment.Bottom)
              .margin({ bottom: 16 });
          }
            .id('start-page-background-adjust-preview-frame')
            .width(this.previewFrameWidth())
            .height(this.previewFrameHeight())
            .borderRadius(HARMONY_RADIUS_CARD)
            .clip(true)
            .backgroundColor('#F2F2F7');
        }
          .id('start-page-background-adjust-preview')
          .layoutWeight(1)
          .width('100%')
          .margin({ left: 12, right: 12 })
          .clip(true)
          .backgroundColor('#F2F2F7')
          .onAreaChange((_oldValue: Area, newValue: Area) => this.updatePreviewArea(newValue));

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
