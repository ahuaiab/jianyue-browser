import { matrix4 } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { tabOverviewThumbnailCrop, TabOverviewThumbnailCrop } from '../model/TabOverviewActions';

/**
 * Renders a PixelMap with the same crop contract as the live tab page:
 * preserve the source aspect ratio, center only horizontal overflow, and
 * keep the source's top edge anchored to the preview surface. The optional
 * top offset mirrors a scaled Web content inset inside a tab card.
 */
@ComponentV2
export struct TopAlignedPixelMapImage {
  @Require @Param source: image.PixelMap;
  /** Offset used by the card shell to match the scaled Web content inset. */
  @Param topOffset: number = 0;

  @Local imageWidth: number = 0;
  @Local imageHeight: number = 0;
  @Local componentWidth: number = 0;
  @Local componentHeight: number = 0;
  @Local loadedSource: image.PixelMap | undefined = undefined;

  private hasImageMetrics(): boolean {
    return this.loadedSource === this.source && this.imageWidth > 0 && this.imageHeight > 0 &&
      this.componentWidth > 0 && this.componentHeight > 0;
  }

  private crop(): TabOverviewThumbnailCrop {
    return tabOverviewThumbnailCrop(
      this.imageWidth,
      this.imageHeight,
      this.componentWidth,
      this.componentHeight
    );
  }

  private imageTransform() {
    const crop: TabOverviewThumbnailCrop = this.crop();
    // imageMatrix translates in source pixels before applying the scale.
    return matrix4.identity()
      .translate({ x: -crop.horizontalSourceOffset, y: -crop.verticalSourceOffset })
      .scale({ x: crop.scale, y: crop.scale });
  }

  private contentTopOffset(): number {
    return Number.isFinite(this.topOffset) ? Math.max(0, this.topOffset) : 0;
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
    // ImageLoadResult uses px while Area uses vp. Keep the matrix calculation
    // in source-pixel units so the same crop works on every density.
    const widthVp: number = Number(area.width);
    const heightVp: number = Number(area.height);
    if (Number.isFinite(widthVp) && widthVp > 0) {
      this.componentWidth = this.getUIContext().vp2px(widthVp);
    }
    if (Number.isFinite(heightVp) && heightVp > 0) {
      this.componentHeight = this.getUIContext().vp2px(heightVp);
    }
  }

  @Builder
  private imageContent() {
    if (this.hasImageMetrics()) {
      Image(this.source)
        .objectFit(ImageFit.MATRIX)
        .imageMatrix(this.imageTransform())
        .translate({ x: 0, y: this.contentTopOffset(), z: 0 })
        .width('100%')
        .height('100%')
        .onComplete((result?: ImageLoadResult) => this.onImageComplete(result));
    } else {
      // The first frame may arrive before the source dimensions. Cover keeps
      // the surface filled until the matrix can be applied on the same frame.
      Image(this.source)
        .objectFit(ImageFit.Cover)
        .translate({ x: 0, y: this.contentTopOffset(), z: 0 })
        .width('100%')
        .height('100%')
        .onComplete((result?: ImageLoadResult) => this.onImageComplete(result));
    }
  }

  build() {
    Stack() {
      this.imageContent();
    }
      .width('100%')
      .height('100%')
      .clip(true)
      .onAreaChange((_oldValue: Area, newValue: Area) => this.onSurfaceAreaChange(newValue));
  }
}
