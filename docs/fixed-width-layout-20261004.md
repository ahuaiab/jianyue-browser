**简阅浏览器固定宽度改造与验证 · 2026-10-04**

本文件记录 10 月 4 日的限宽改造。默认位置与编辑按钮圆角衔接的后续修正见 [10 月 5 日居中与圆角验证](E:/HarmonyOS/jianyue-browser/docs/center-corners-layout-20261005.md)。

已按照现有手机布局固定应用自有内容、控件和弹层的宽度。宽屏保持同一 vp 尺寸，窄窗口在安全可用宽度不足时收缩；左右避让区参与定位。首页、错误页和标签网格居中于安全区域，工具栏及关联弹层继续使用现有的惯用手锚点。

基准来自当前 Mate 80 模拟器：窗口宽 1280px，44vp 控件高 154px，对应密度 3.5，窗口约 365.71vp；设计宽度取 366vp。当前手机按实际可用宽度限幅，因此原有尺寸保留。统一值位于 [BrowserVisualMetrics.ets](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/model/BrowserVisualMetrics.ets:21)。

本次按最新要求固定宽度。现有按钮/行高、纵向排布、弹层 56%/72% 高度以及图片裁切比例继续沿用。应用背景、遮罩和网页视口按实际窗口铺满；系统图库和原生菜单由系统管理。

| 部位 | 安全区域足够宽时的设计尺寸 | Mate 80 实测 px | Pura X Max 实测 px |
| --- | --- | --- | --- |
| 首页内容 / 标签网格 | 宽 366vp | 1280 | 1007 |
| 底部栏可见表面 | 宽 350vp、高 100vp | 1224×350 | 963×275 |
| 地址栏项目 | 宽 334vp | 1168 | 919 |
| 底部操作按钮 | 62×44vp | 217×154 | 171×121 |
| 标签卡片 | 161×242vp | 563×847 | 443×666 |
| 书签/历史、起始页编辑弹层 | 宽 350vp | 1224 | 963 |
| 书签/历史内容卡片 | 宽 326vp | 1140 | 897 |
| 书签/历史列表 | 宽 260.8vp | 913 | 717 |
| 下载弹层 | 宽 366vp | 1280 | 1007 |
| 下载标题及列表 | 宽 292.8vp | 标题 1024 | 标题 805 |
| 背景调整弹层 | 宽 366vp | 源码/构建核对 | 源码/构建核对 |

vp 表示逻辑尺寸，设备像素密度不同会产生不同 px 值。Mate 80 的实际可用宽度略小于 366vp；所有设备边界核对允许 1px 的取整误差。原有 8/12/16vp 内部留白继续用于间距，宽屏增加外部空白以保持控件大小。

共修改 12 个生产文件和 3 个测试文件。首页和错误页只对内部内容限宽；下载、书签、编辑和背景调整弹层使用对应的统一宽度。静态标签网格与活动网页的缩放/裁剪坐标使用同一个安全框，活动卡片标题与关闭图标补偿页面缩放，保持原有视觉尺寸。

安全区回归用例为窗口 300vp、左避让 32vp、右避让 12vp：网格宽 256vp、左坐标 32vp、卡片宽 106vp，两列活动页面与卡片落点一致。设备上，宽屏首列卡片与活动边框均为 `[776,129,1219,795]`，第二列均为 `[1252,129,1695,795]`。

通过 `devecocli run` 构建，并在 Mate 80（`127.0.0.1:5555`）和 Pura X Max（`127.0.0.1:5557`）成功安装、启动同一份最终 HAP。完成 58 项设备尺寸及位置核对，全部通过；覆盖首页、工具栏、标签概览两列、书签/历史、编辑弹层与下载空状态。

本地测试修改前为 370/373，修改后为 374/377，新增 4 项布局测试全部通过，错误数均为 0。以下 3 项失败在修改前后完全一致：

- `TabOverviewTransition`：compact title size，实际 16、预期 10。
- `DownloadProgressUi`：lock ring button contract，实际 24、预期 20。
- `AdaptiveBrowserLayout`：selected tab content contour，实际 163、预期 24。

原始结果见 [修改前测试](E:/HarmonyOS/jianyue-browser/verification/fixed-width-20261004/baseline-test-result.txt) 和 [最终测试](E:/HarmonyOS/jianyue-browser/verification/fixed-width-20261004/after-test-result.txt)。`git diff --check` 通过。两名 Luna 子代理承担修改及独立复核；最终代码核对未发现重复扣安全区或将网页视口限宽的回归。

图库为空，未实际进入照片背景调整状态；保留了 [图库截图](E:/HarmonyOS/jianyue-browser/verification/fixed-width-20261004/wide-gallery.png)。无效测试网址显示在原生网页表面，未触发应用的自定义错误页。背景调整和自定义错误页完成源码/编译核对，尚无运行截图验收；下载列表尚未用活动下载任务验收。当前验收对象为模拟器，尚未进行真机验收。

最终包为 [20261004-231257-entry-debug-fixed-width-unsigned.hap](E:/HarmonyOS/jianyue-browser/hap/20261004-231257-entry-debug-fixed-width-unsigned.hap)，3,426,280 字节。当前工程没有 signingConfig，因此产物为 unsigned 调试包。SHA-256：`1DC7D06BE9C084C5C201C64C7754B9D0490D3A763F20FAE6D209F3016B29340C`。

截图：[手机首页](E:/HarmonyOS/jianyue-browser/verification/fixed-width-20261004/phone-home-delivery.png)、[宽屏首页](E:/HarmonyOS/jianyue-browser/verification/fixed-width-20261004/wide-home-delivery.png)、[手机概览](E:/HarmonyOS/jianyue-browser/verification/fixed-width-20261004/phone-overview-accepted.png)、[宽屏首列](E:/HarmonyOS/jianyue-browser/verification/fixed-width-20261004/wide-overview-accepted.png)、[宽屏第二列](E:/HarmonyOS/jianyue-browser/verification/fixed-width-20261004/wide-overview-second-accepted.png)、[手机书签](E:/HarmonyOS/jianyue-browser/verification/fixed-width-20261004/phone-library-accepted.png)、[宽屏历史](E:/HarmonyOS/jianyue-browser/verification/fixed-width-20261004/wide-history-accepted.png)、[宽屏编辑](E:/HarmonyOS/jianyue-browser/verification/fixed-width-20261004/wide-customize-accepted.png)、[宽屏下载](E:/HarmonyOS/jianyue-browser/verification/fixed-width-20261004/wide-download-accepted.png)。

留存了 [设备几何核对记录](E:/HarmonyOS/jianyue-browser/verification/fixed-width-20261004/runtime-evidence.json)、[最终验收记录](E:/HarmonyOS/jianyue-browser/verification/fixed-width-20261004/acceptance-final.json)、[源码哈希清单](E:/HarmonyOS/jianyue-browser/verification/fixed-width-20261004/source-manifest.json) 和 [本次改动补丁](E:/HarmonyOS/jianyue-browser/verification/fixed-width-20261004/task-only-changes.patch)。清单与补丁以任务开始时的 113 个源文件/测试文件快照为基准，保留原有未提交改动；本次没有暂存、提交或发布源码。
