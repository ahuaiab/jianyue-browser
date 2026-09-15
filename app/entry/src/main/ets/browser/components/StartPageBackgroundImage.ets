import { matrix4 } from '@kit.ArkUI';
import {
  DEFAULT_START_PAGE_BACKGROUND_POSITION,
  StartPageBackgroundPosition,
  normalizeStartPageBackgroundPosition
} from '../model/BrowserSettings';

/**
 * Renders a start-page image with the same cover crop in both the page and
 * the adjustment sheet. The normalized position describes the visible crop:
 * (0, 0) is the top-left edge and (1, 1) is the bottom-right edge.
 */
@ComponentV2
export struct StartPageBackgroundImage {
  @Param source: string = '';
  @Param backgroundPosition: StartPageBackgroundPosition = DEFAULT_START_PAGE_BACKGROUND_POSITION;
  @Param interactive: boolean = false;
  @Param onPositionChange: (position: StartPageBackgroundPosition) => void =
    (_position: StartPageBackgroundPosition) => undefined;

  @Local imageWidth: number = 0;
  @Local imageHeight: number = 0;
  @Local componentWidth: number = 0;
  @Local componentHeight: number = 0;
  @Local loadedSource: string = '';
  private dragStartPosition: StartPageBackgroundPosition = {
    x: DEFAULT_START_PAGE_BACKGROUND_POSITION.x,
    y: DEFAULT_START_PAGE_BACKGROUND_POSITION.y
  };

  private hasImageMetrics(): boolean {
    return this.loadedSource === this.source && this.imageWidth > 0 && this.imageHeight > 0 &&
      this.componentWidth > 0 && this.componentHeight > 0;
  }

  private coverScale(): number {
    if (!this.hasImageMetrics()) {
      return 1;
    }
    return Math.max(this.componentWidth / this.imageWidth, this.componentHeight / this.imageHeight);
  }

  private horizontalOverflow(): number {
    if (!this.hasImageMetrics()) {
      return 0;
    }
    return Math.max(0, this.imageWidth * this.coverScale() - this.componentWidth);
  }

  private verticalOverflow(): number {
    if (!this.hasImageMetrics()) {
      return 0;
    }
    return Math.max(0, this.imageHeight * this.coverScale() - this.componentHeight);
  }

  private clamped(value: number): number {
    return Math.max(0, Math.min(1, value));
  }

  private normalizedPosition(): StartPageBackgroundPosition {
    return normalizeStartPageBackgroundPosition(this.backgroundPosition as Object);
  }

  private imageTransform() {
    const position: StartPageBackgroundPosition = this.normalizedPosition();
    const translationX: number = -this.horizontalOverflow() * position.x;
    const translationY: number = -this.verticalOverflow() * position.y;
    return matrix4.identity()
      .translate({ x: translationX, y: translationY })
      .scale({ x: this.coverScale(), y: this.coverScale() });
  }

  private onImageComplete(result?: ImageLoadResult): void {
    if (result === undefined || result.width <= 0 || result.height <= 0) {
      return;
    }
    this.imageWidth = result.width;
    this.imageHeight = result.height;
    if (result.componentWidth > 0) {
      this.componentWidth = result.componentWidth;
    }
    if (result.componentHeight > 0) {
      this.componentHeight = result.componentHeight;
    }
    this.loadedSource = this.source;
  }

  private onSurfaceAreaChange(area: Area): void {
    // Area dimensions are reported in vp, while ImageLoadResult and
    // imageMatrix translations use px. Keep all crop math in the same unit.
    const widthVp: number = Number(area.width);
    const heightVp: number = Number(area.height);
    if (Number.isFinite(widthVp) && widthVp > 0) {
      this.componentWidth = this.getUIContext().vp2px(widthVp);
    }
    if (Number.isFinite(heightVp) && heightVp > 0) {
      this.componentHeight = this.getUIContext().vp2px(heightVp);
    }
  }

  private beginPan(): void {
    this.dragStartPosition = this.normalizedPosition();
  }

  private updatePan(event?: GestureEvent): void {
    if (!this.interactive) {
      return;
    }
    const horizontalOverflow: number = this.horizontalOverflow();
    const verticalOverflow: number = this.verticalOverflow();
    const offsetX: number = event?.offsetX ?? 0;
    const offsetY: number = event?.offsetY ?? 0;
    const nextX: number = horizontalOverflow > 0
      ? this.clamped(this.dragStartPosition.x - offsetX / horizontalOverflow)
      : this.dragStartPosition.x;
    const nextY: number = verticalOverflow > 0
      ? this.clamped(this.dragStartPosition.y - offsetY / verticalOverflow)
      : this.dragStartPosition.y;
    this.onPositionChange({ x: nextX, y: nextY });
  }

  @Builder
  private imageContent() {
    if (this.hasImageMetrics()) {
      Image(this.source)
        .objectFit(ImageFit.MATRIX)
        .imageMatrix(this.imageTransform())
        .width('100%')
        .height('100%')
        .onComplete((result?: ImageLoadResult) => this.onImageComplete(result));
    } else {
      Image(this.source)
        .objectFit(ImageFit.Cover)
        .width('100%')
        .height('100%')
        .onComplete((result?: ImageLoadResult) => this.onImageComplete(result));
    }
  }

  build() {
    if (this.interactive) {
      Stack() {
        this.imageContent();
      }
        .width('100%')
        .height('100%')
        .clip(true)
        .onAreaChange((_oldValue: Area, newValue: Area) => this.onSurfaceAreaChange(newValue))
        .gesture(
          PanGesture({ direction: PanDirection.All, distance: 2 })
            .onActionStart(() => this.beginPan())
            .onActionUpdate((event: GestureEvent | undefined) => this.updatePan(event))
        );
    } else {
      Stack() {
        this.imageContent();
      }
        .width('100%')
        .height('100%')
        .clip(true)
        .onAreaChange((_oldValue: Area, newValue: Area) => this.onSurfaceAreaChange(newValue));
    }
  }
}
