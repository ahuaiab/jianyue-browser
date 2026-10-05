**宽屏居中与圆角对齐修正 · 2026-10-05**

已修正宽屏的默认位置，并对齐截图中的白色卡片与编辑按钮下角圆心。两名 Luna 子代理分别完成模型和按钮布局修改，再交叉复核；主代理检查任务开始快照差异、构建、安装及设备截图。

默认位置现在以实际窗口中线计算，只有与侧面避让区冲突时才夹回安全边界。366vp 基准宽度及原有左右手锚点继续使用；首页、底栏、标签网格和弹层共用这一定位模型。此前 Pura X Max 默认栏中心为 1235.5px，窗口中线为 1292px，偏左 56.5px，约 20.5vp；修改后中心为 1292.5px，差 0.5px，属于像素取整。

截图中的编辑按钮宿主已按安全框定位，原来局部 padding 又加了一次右侧避让值，造成约 45vp 的横向空白。现在移除重复避让，并用白卡圆角 24vp 与按钮圆角 20vp 的差值 4vp，同时计算水平和底部留白。按钮仍为 52×52vp，圆角值及交互保持原有设置。

| 设备 | 白卡右下角圆心 px | 编辑按钮右下角圆心 px | 白卡到按钮的右侧/底部距离 |
| --- | --- | --- | --- |
| Mate 80 | 1126, 2678 | 1126, 2678 | 14px / 14px，即 4vp / 4vp |
| Pura X Max | 1675, 1707 | 1675, 1707 | 11px / 11px，即 4vp / 4vp |

构建成功，同一最终包已安装并启动于两台模拟器。49 项设备几何核对全部通过，覆盖默认居中、书签/历史两种状态的圆角、标签概览两列与活动页面对齐，以及宽屏编辑/下载弹层的位置。尚未进行真机验收。

本地测试由 374/377 增至 376/379，新增的 2 项居中/避让边界回归通过。剩余 3 项失败与修改前一致：标题字号 16 对 10、下载锁环 24 对 20，以及未被生产组件调用的 LibraryTabInnerJoinFrame 163 对 24。原始结果见 [修改前测试](E:/HarmonyOS/jianyue-browser/verification/center-corners-20261005/previous-test-result.txt) 和 [最终测试](E:/HarmonyOS/jianyue-browser/verification/center-corners-20261005/after-test-result.txt)。

源码只修改 [BrowserVisualMetrics.ets](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/model/BrowserVisualMetrics.ets:270)、[LibrarySheet.ets](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/LibrarySheet.ets:1541) 和 [AdaptiveBrowserLayout.test.ets](E:/HarmonyOS/jianyue-browser/app/entry/src/test/ets/test/AdaptiveBrowserLayout.test.ets:43)。已与本轮 113 个源文件/测试文件快照比较，其他 110 个文件保持一致；保留此前未提交的改动，没有暂存、提交或发布。

最终包：[20261005-035054-entry-debug-centered-corners-unsigned.hap](E:/HarmonyOS/jianyue-browser/hap/20261005-035054-entry-debug-centered-corners-unsigned.hap)，3,427,287 字节，为 unsigned 调试 HAP。SHA-256：`CF0B5EDA3C3ACEAD25FBE0CAE83DC62FCAF15CE2F8890CD8903E730CCC301F59`。

截图：[宽屏修正前](E:/HarmonyOS/jianyue-browser/verification/center-corners-20261005/wide-before-library.png)、[宽屏修正后](E:/HarmonyOS/jianyue-browser/verification/center-corners-20261005/wide-after-library-bookmarks.png)、[手机修正后](E:/HarmonyOS/jianyue-browser/verification/center-corners-20261005/phone-after-library-bookmarks.png)、[宽屏首页居中](E:/HarmonyOS/jianyue-browser/verification/center-corners-20261005/wide-after-home.png)、[宽屏第二列标签](E:/HarmonyOS/jianyue-browser/verification/center-corners-20261005/wide-after-overview-second.png)。

证据：[修改前失败几何](E:/HarmonyOS/jianyue-browser/verification/center-corners-20261005/runtime-red.json)、[最终设备核对](E:/HarmonyOS/jianyue-browser/verification/center-corners-20261005/runtime-final.json)、[构建安装日志](E:/HarmonyOS/jianyue-browser/verification/center-corners-20261005/build-install-final.log)、[源码哈希](E:/HarmonyOS/jianyue-browser/verification/center-corners-20261005/source-manifest.json)、[本次改动补丁](E:/HarmonyOS/jianyue-browser/verification/center-corners-20261005/task-only-changes.patch)。
