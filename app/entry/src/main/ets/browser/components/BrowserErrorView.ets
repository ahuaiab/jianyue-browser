import { BrowserErrorKind, BrowserErrorState } from '../model/BrowserTypes';
import {
  BROWSER_UI_TEXT_SIZE_VP,
  BROWSER_UI_REFERENCE_WIDTH_VP,
  BrowserChromeAnchor,
  BrowserChromeLayoutFrame,
  browserChromeLayoutFrame
} from '../model/BrowserVisualMetrics';

@ComponentV2
export struct BrowserErrorView {
  @Require @Param error: BrowserErrorState;
  @Param onRetry: () => void = () => undefined;
  @Param onBack: () => void = () => undefined;
  @Param leftInset: number = 0;
  @Param rightInset: number = 0;

  @Local contentAvailableWidth: number = BROWSER_UI_REFERENCE_WIDTH_VP;

  private contentFrame(): BrowserChromeLayoutFrame {
    return browserChromeLayoutFrame(
      this.contentAvailableWidth,
      this.leftInset,
      this.rightInset,
      BrowserChromeAnchor.CENTER
    );
  }

  private contentHorizontalOffset(): number {
    return this.contentFrame().left -
      (this.contentAvailableWidth - this.contentFrame().width) / 2;
  }

  private headline(): string {
    if (this.error.kind === BrowserErrorKind.SSL) {
      return '连接不安全';
    }
    if (this.error.kind === BrowserErrorKind.RENDERER_EXITED) {
      return '页面进程已退出';
    }
    return '网页无法打开';
  }

  private detail(): string {
    if (this.error.kind === BrowserErrorKind.SSL) {
      return '证书校验失败。为保护你的数据，不能跳过证书检查。';
    }
    if (this.error.kind === BrowserErrorKind.RENDERER_EXITED) {
      return '网页渲染进程意外退出，可以重新加载此页面。';
    }
    return '请检查网络连接后重试。';
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 14 }) {
        Text(this.headline())
          .fontSize(BROWSER_UI_TEXT_SIZE_VP)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
        Text(this.error.host)
          .fontSize(BROWSER_UI_TEXT_SIZE_VP)
          .fontColor('#475569')
          .maxLines(1)
        Text(`${this.detail()}\n错误码：${this.error.code}`)
          .fontSize(BROWSER_UI_TEXT_SIZE_VP)
          .fontColor('#334155')
          .textAlign(TextAlign.Center)
        Row({ space: 12 }) {
          Button('返回', { type: ButtonType.Capsule, stateEffect: false })
            .id('browser-error-back-button')
            .onClick(() => this.onBack())
          Button('重试', { type: ButtonType.Capsule, stateEffect: false })
            .id('browser-error-retry-button')
            .onClick(() => this.onRetry())
        }
      }
      .id('browser-error-content')
      .width(this.contentFrame().width)
      .height('100%')
      .padding(28)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .translate({ x: this.contentHorizontalOffset(), y: 0, z: 0 })
    }
    .id('browser-error-view')
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const width: number = Number(newArea.width);
      if (Number.isFinite(width) && width > 0) {
        this.contentAvailableWidth = width;
      }
    })
  }
}
