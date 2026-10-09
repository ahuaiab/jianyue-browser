import { curves } from '@kit.ArkUI';
import { DownloadBackend, DownloadStatus, DownloadTaskRecord } from '../model/DownloadModels';
import {
  BrowserChromeAnchor,
  browserChromeLayoutFrame,
  browserFixedWidth,
  DOWNLOAD_CONTENT_DESIGN_WIDTH_VP,
  DOWNLOAD_SHEET_DESIGN_WIDTH_VP,
  HARMONY_RADIUS_CARD,
  HARMONY_RADIUS_COMPACT,
  HARMONY_RADIUS_SHEET,
} from '../model/BrowserVisualMetrics';
import { LIBRARY_SHEET_HEIGHT_PERCENT } from '../model/LibraryModels';
import {
  BROWSER_UI_ICON_CONTAINER_SIZE_VP,
  BROWSER_UI_ICON_SIZE_VP,
  BROWSER_UI_TEXT_SIZE_VP
} from '../model/BrowserVisualMetrics';

export enum DownloadManagerActionKind {
  NONE = 'none',
  PAUSE = 'pause',
  RESUME = 'resume',
  RETRY = 'retry'
}

export function downloadManagerTaskId(id: string): string {
  return `download-task-${id}`;
}

export function downloadManagerSubtitleLabel(_status: DownloadStatus): string {
  // The trailing status is the single status owner in each row. A second
  // status line under the filename made terminal states appear twice.
  return '';
}

export function downloadManagerProgressLabel(task: DownloadTaskRecord): string {
  if (task.status === DownloadStatus.COMPLETED) {
    return '已完成';
  }
  if (task.status === DownloadStatus.FAILED) {
    return '下载失败';
  }
  if (task.status === DownloadStatus.CANCELLED) {
    return '已取消';
  }
  if (task.percent < 0) {
    return '正在下载';
  }
  return `${Math.max(0, Math.min(100, Math.trunc(task.percent)))}%`;
}

export function downloadManagerActionKindFor(status: DownloadStatus): DownloadManagerActionKind {
  if (status === DownloadStatus.RUNNING) {
    return DownloadManagerActionKind.PAUSE;
  }
  if (status === DownloadStatus.PAUSED) {
    return DownloadManagerActionKind.RESUME;
  }
  if (status === DownloadStatus.FAILED) {
    return DownloadManagerActionKind.RETRY;
  }
  return DownloadManagerActionKind.NONE;
}

export function downloadManagerCancelVisibleFor(status: DownloadStatus): boolean {
  return status === DownloadStatus.QUEUED || status === DownloadStatus.HANDOFF_PENDING ||
    status === DownloadStatus.RUNNING || status === DownloadStatus.PAUSED;
}

function downloadManagerProgressValueFor(task: DownloadTaskRecord): number {
  if (task.percent < 0) {
    return 0;
  }
  return Math.max(0, Math.min(100, Math.trunc(task.percent)));
}

export function downloadManagerDetailLabel(_task: DownloadTaskRecord): string {
  // Backend and lifecycle details belong to the implementation, not the
  // compact row. Keep the row aligned with the existing LibrarySheet style.
  return '';
}

@ComponentV2
export struct DownloadManagerSheet {
  @Param tasks: DownloadTaskRecord[] = [];
  @Param topInset: number = 0;
  @Param bottomInset: number = 0;
  @Param viewportWidth: number = 400;
  @Param leftInset: number = 0;
  @Param rightInset: number = 0;
  @Param chromeAnchor: BrowserChromeAnchor = BrowserChromeAnchor.CENTER;
  @Param onClose: () => void = () => undefined;
  @Param onPause: (id: string) => void = (_id: string) => undefined;
  @Param onResume: (id: string) => void = (_id: string) => undefined;
  @Param onCancel: (id: string) => void = (_id: string) => undefined;
  @Param onRetry: (id: string) => void = (_id: string) => undefined;

  @Local sheetSwipeOffset: number = 0;
  @Local sheetGestureActive: boolean = false;
  private sheetAnimationToken: number = 0;

  private safeBottomInset(): number {
    return Math.max(16, this.bottomInset);
  }

  private topContentInset(): number {
    return Math.max(8, Math.min(this.topInset, 12));
  }

  private sheetWidth(): number {
    return browserFixedWidth(
      browserChromeLayoutFrame(
        this.viewportWidth,
        this.leftInset,
        this.rightInset,
        this.chromeAnchor
      ).width,
      DOWNLOAD_SHEET_DESIGN_WIDTH_VP
    );
  }

  private sheetHorizontalOffset(): number {
    const safeViewportWidth: number = Number.isFinite(this.viewportWidth) && this.viewportWidth > 0
      ? this.viewportWidth
      : 1;
    const frame = browserChromeLayoutFrame(
      safeViewportWidth,
      this.leftInset,
      this.rightInset,
      this.chromeAnchor
    );
    return frame.left - (safeViewportWidth - frame.width) / 2;
  }

  private beginSheetSwipe(): void {
    this.sheetGestureActive = true;
    this.sheetAnimationToken += 1;
  }

  private updateSheetSwipe(event?: GestureEvent): void {
    if (!this.sheetGestureActive) {
      return;
    }
    this.sheetSwipeOffset = Math.max(0, Math.min(240, event?.offsetY ?? 0));
  }

  private finishSheetSwipe(event?: GestureEvent): void {
    if (!this.sheetGestureActive) {
      return;
    }
    const offset: number = Math.max(0, this.sheetSwipeOffset > 0
      ? this.sheetSwipeOffset
      : (event?.offsetY ?? 0));
    this.sheetGestureActive = false;
    const token: number = this.sheetAnimationToken + 1;
    this.sheetAnimationToken = token;
    if (offset >= 120) {
      this.getUIContext().animateTo({
        curve: curves.springMotion(),
        onFinish: () => {
          if (token === this.sheetAnimationToken) {
            this.sheetSwipeOffset = 0;
            this.onClose();
          }
        }
      }, () => {
        this.sheetSwipeOffset = 240;
      });
      return;
    }
    this.getUIContext().animateTo({ curve: curves.springMotion() }, () => {
      this.sheetSwipeOffset = 0;
    });
  }

  private cancelSheetSwipe(): void {
    if (!this.sheetGestureActive && this.sheetSwipeOffset === 0) {
      return;
    }
    this.sheetGestureActive = false;
    this.sheetAnimationToken += 1;
    this.getUIContext().animateTo({ curve: curves.springMotion() }, () => {
      this.sheetSwipeOffset = 0;
    });
  }

  @Builder
  private actionButton(id: string, label: string, onClick: () => void) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Text(label)
        .fontSize(BROWSER_UI_TEXT_SIZE_VP)
        .fontColor('#007AFF');
    }
      .id(id)
      .height(32)
      .padding({ left: 12, right: 12 })
      .backgroundColor('#EAF2FF')
      .borderRadius(HARMONY_RADIUS_CARD)
      .stateEffect(false)
      .onClick(onClick);
  }

  @Builder
  private taskActions(task: DownloadTaskRecord) {
    Row({ space: 8 }) {
      if (downloadManagerActionKindFor(task.status) === DownloadManagerActionKind.PAUSE &&
        task.backend === DownloadBackend.REQUEST_AGENT) {
        this.actionButton(`download-task-pause-${task.id}`, '暂停', () => this.onPause(task.id));
      } else if (downloadManagerActionKindFor(task.status) === DownloadManagerActionKind.RESUME &&
        task.backend === DownloadBackend.REQUEST_AGENT) {
        this.actionButton(`download-task-resume-${task.id}`, '继续', () => this.onResume(task.id));
      } else if (downloadManagerActionKindFor(task.status) === DownloadManagerActionKind.RETRY) {
        this.actionButton(`download-task-retry-${task.id}`, '重试', () => this.onRetry(task.id));
      }
      if (downloadManagerCancelVisibleFor(task.status)) {
        this.actionButton(`download-task-cancel-${task.id}`, '取消', () => this.onCancel(task.id));
      }
    }
      .width('100%')
      .justifyContent(FlexAlign.End);
  }

  @Builder
  private taskRow(task: DownloadTaskRecord) {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Stack({ alignContent: Alignment.Center }) {
          Text(task.status === DownloadStatus.COMPLETED ? '✓' : '↓')
            .width(BROWSER_UI_ICON_CONTAINER_SIZE_VP)
            .height(BROWSER_UI_ICON_CONTAINER_SIZE_VP)
            .fontSize(BROWSER_UI_ICON_SIZE_VP)
            .textAlign(TextAlign.Center)
            .fontColor(task.status === DownloadStatus.FAILED ? '#FF3B30' : '#007AFF');
        }
          .width(32)
          .height(32)
          .backgroundColor('#EEF5FF')
          .borderRadius(HARMONY_RADIUS_COMPACT);
        Column({ space: 3 }) {
          Text(task.filename.length > 0 ? task.filename : '下载文件')
            .fontSize(BROWSER_UI_TEXT_SIZE_VP)
            .fontColor('#1D1D1F')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%');
          if (downloadManagerSubtitleLabel(task.status).length > 0) {
            Text(downloadManagerSubtitleLabel(task.status))
              .fontSize(BROWSER_UI_TEXT_SIZE_VP)
              .fontColor(task.status === DownloadStatus.FAILED ? '#FF3B30' : '#6B7280');
          }
        }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
        Text(downloadManagerProgressLabel(task))
          .fontSize(BROWSER_UI_TEXT_SIZE_VP)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1D1D1F');
      }
        .width('100%');

      if (task.status === DownloadStatus.QUEUED || task.status === DownloadStatus.HANDOFF_PENDING ||
        task.status === DownloadStatus.RUNNING || task.status === DownloadStatus.PAUSED) {
        Progress({
          value: downloadManagerProgressValueFor(task),
          total: 100,
          type: ProgressType.Linear
        })
          .id(`download-task-progress-${task.id}`)
          .width('100%')
          .height(4)
          .color('#1677FF')
      }

      if (downloadManagerDetailLabel(task).length > 0) {
        Text(downloadManagerDetailLabel(task))
          .fontSize(BROWSER_UI_TEXT_SIZE_VP)
          .fontColor('#8A8A90')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
      }
      this.taskActions(task);
      Row()
        .width('100%')
        .height(1)
        .backgroundColor('#E5E5EA');
    }
      .id(downloadManagerTaskId(task.id))
      .width('100%')
      .padding({ top: 12, bottom: 12 });
  }

  @Builder
  private emptyState() {
    Column({ space: 8 }) {
      Text('暂无下载')
        .fontSize(BROWSER_UI_TEXT_SIZE_VP)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1D1D1F');
      Text('网页下载完成后会显示在这里')
        .fontSize(BROWSER_UI_TEXT_SIZE_VP)
        .fontColor('#8A8A90');
    }
      .id('download-manager-empty-state')
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center);
  }

  build() {
    Column() {
      Column() {
        Blank()
          .width('100%')
          .height('100%');
      }
        .id('download-manager-backdrop')
        .width('100%')
        .layoutWeight(1)
        .onClick(() => this.onClose());

      Column() {
        Blank()
          .width('100%')
          .height(this.topContentInset());
        Row() {
          Text('下载管理')
            .fontSize(BROWSER_UI_TEXT_SIZE_VP)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1D1D1F')
            .width('100%')
            .textAlign(TextAlign.Center);
        }
          .id('download-manager-header')
          .width(browserFixedWidth(this.sheetWidth(), DOWNLOAD_CONTENT_DESIGN_WIDTH_VP))
          .alignSelf(ItemAlign.Center)
          .height(52)
          .padding({ left: 0, right: 0 });

        if (this.tasks.length === 0) {
          this.emptyState();
        } else {
          Scroll() {
            Column() {
              ForEach(this.tasks, (task: DownloadTaskRecord) => {
                this.taskRow(task);
              }, (task: DownloadTaskRecord) => task.id);
            }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Start)
              .alignItems(HorizontalAlign.Start);
          }
            .id('download-manager-task-scroll')
            .width(browserFixedWidth(this.sheetWidth(), DOWNLOAD_CONTENT_DESIGN_WIDTH_VP))
            .alignSelf(ItemAlign.Center)
            .layoutWeight(1)
            .scrollBar(BarState.Off);
        }

        Blank()
          .id('download-manager-footer-spacer')
          .width('100%')
          .height(this.safeBottomInset());
      }
        .id('download-manager-sheet')
        .width(this.sheetWidth())
        .alignSelf(ItemAlign.Center)
        .height(`${LIBRARY_SHEET_HEIGHT_PERCENT}%`)
        .backgroundColor(Color.White)
        .borderRadius({ topLeft: HARMONY_RADIUS_SHEET, topRight: HARMONY_RADIUS_SHEET })
        .shadow({ radius: 12, color: '#55000000', offsetX: 0, offsetY: -3 })
        .clip(true)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        .translate({ x: this.sheetHorizontalOffset(), y: this.sheetSwipeOffset })
        .parallelGesture(
          PanGesture({ direction: PanDirection.Vertical, distance: 8 })
            .onActionStart(() => this.beginSheetSwipe())
            .onActionUpdate((event: GestureEvent | undefined) => this.updateSheetSwipe(event))
            .onActionEnd((event: GestureEvent | undefined) => this.finishSheetSwipe(event))
            .onActionCancel(() => this.cancelSheetSwipe())
        );
    }
      .id('download-manager-overlay')
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent);
  }
}
