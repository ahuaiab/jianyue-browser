**简阅浏览器全应用布局检查 · 2026-10-04**

本文件记录改动前的布局。后续固定宽度修改、构建及设备核对见 [固定宽度改造与验证](E:/HarmonyOS/jianyue-browser/docs/fixed-width-layout-20261004.md)。

结论：存在明确的 vp 边距设置，也存在用边距反算宽高的设置。当前应用没有做到所有布局都使用固定宽度、固定高度。主要控件的图标、部分按钮和行高已经固定，但弹层高度、工具栏按钮宽度、标签卡片宽度、内容区及图片预览仍包含百分比、权重、窗口尺寸或实际测量值。

检查范围为 `E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets` 下全部 74 个 ArkTS 源文件。识别到 20 个组件文件、1 个 Web 构建器文件、1 个入口页面文件，以及 1 个开发预览文件；共检索到 759 处尺寸、边距、位置、缩放、安全区和网格相关属性调用（包含开发预览中的 20 处）。入口页面配置只登记 `pages/Index`。两个 Luna 子代理分别检查弹层/首页和地址栏/工具栏/标签页；主代理复核公共尺寸模型、外层调用、页面和图片容器。

以下结论来自当前工作树源码。未修改应用源码，未执行构建、安装或设备验收；表中高度百分比和边距表示源码声明，实际显示还受父容器和安全区影响。

**尺寸和边距的含义**

- `.width(44).height(44)` 中的数值长度采用 vp，是固定尺寸声明。
- `.width('100%')`、`.height('56%')`、`calc(...)` 按父布局计算；如果父尺寸固定，子组件的计算结果也可以稳定，不能仅看见百分号就判定图标会随屏幕缩放。
- `layoutWeight(1)`、网格 `1fr` 按剩余空间分配尺寸。某个维度没有显式设置时，可能由内容或父布局约束决定。
- `padding` 表示容器内部留白，`margin` 表示外部距离，`position/translate/offset` 表示定位或移动。它们与宽高是不同的属性；同时设置固定尺寸和固定边距本身并不冲突。
- 本地官方参考通过 `devecocli docs read API参考/ArkUI_方舟UI框架/ArkTS组件/通用属性/布局与边框/尺寸设置/ts-universal-attributes-size` 核对。

**参与尺寸计算的关键设置**

| 部位 | 当前计算或声明 | 与“全固定宽高”的差异 | 源码证据 |
| --- | --- | --- | --- |
| 底部栏定位框 | `min(400, viewportWidth - leftAvoidInset - rightAvoidInset)` | 400vp 是设计上限，窄窗口仍缩小 | [宽度模型](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/model/BrowserVisualMetrics.ets:241) |
| 底部可见表面 | 定位框宽度减左右各 8vp，即最多 384vp | 由外框宽度和边距推导 | [表面宽度](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/model/BrowserVisualMetrics.ets:271) |
| 地址胶囊 | `max(1, layoutWidth - 32)` | 固定高 44vp，宽度按地址轨道左右各 16vp 留白计算 | [地址宽度](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/model/BrowserVisualMetrics.ets:386)、[实际调用](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/AddressTabStrip.ets:175) |
| 底部栏总占位高度 | `100 + max(0, bottomInset - 16) + 8` | 可见材质高 100vp；透明安全区尾部和外层底部间距参与总高度 | [尾部高度](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/model/BrowserVisualMetrics.ets:198)、[外层高度](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/BrowserShell.ets:5844) |
| 底部操作按钮 | 每项宽 `100%` 加权重 1；按钮高 44vp，操作行高 48vp | 图标容器固定 26×26vp，按钮点击区域宽度仍由父 Row 分配 | [按钮](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/BrowserActionToolbar.ets:115)、[操作行](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/BrowserActionToolbar.ets:285) |
| 书签/历史弹层 | 表面宽度模型；高 `56%` | 外框不是独立固定 vp 宽高 | [弹层外框](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/LibrarySheet.ets:1688)、[56 常量](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/model/LibraryModels.ets:26) |
| 书签/历史内容 | 标签和内容卡片宽 `calc(100% - 24vp)`；列表宽 `80%` | 内容区左右留白 12vp，内部列表继续按比例缩窄 | [标签](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/LibrarySheet.ets:1590)、[内容卡片](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/LibrarySheet.ets:1631)、[书签列表](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/LibrarySheet.ets:1440)、[历史列表](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/LibrarySheet.ets:1464) |
| 起始页设置弹层 | 表面宽度模型；直接声明高 `56%` | 高度没有固定为 vp | [外框](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/StartPageCustomizeSheet.ets:578) |
| 下载管理弹层 | 宽 `100%`；高 `56%`；内部标题/列表宽 `80%` | 外框宽高和内容宽度均含比例 | [外框](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/DownloadManagerSheet.ets:336)、[内容](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/DownloadManagerSheet.ets:324) |
| 背景调整弹层 | 宽 `100%`；高 `72%` | 弹层宽高按父窗口计算 | [外框](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/StartPageBackgroundAdjustSheet.ets:204) |
| 标签概览卡片 | 宽 `(viewportWidth - 16×2 - 12) / 2`；高 242vp | 高度固定，宽度由两列网格与边距计算 | [宽度模型](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/model/TabOverviewActions.ets:185)、[网格](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/TabOverview.ets:433) |
| 概览底部操作区 | 宽 `100%`；高 `60 + bottomInset` | 安全区改变外层高度，内部按钮仍有固定尺寸 | [操作区](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/TabOverview.ets:523) |
| 页面场景/网页容器 | 场景宽跟随 viewport；内容高 `viewportHeight - topInset`；多个父子容器 `100%` | 整页布局跟随窗口与安全区 | [场景](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/BrowserTransitionScene.ets:133)、[高度模型](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/model/TabOverviewActions.ets:616) |

400vp 上限下，居中且左右安全区为 0 时：窗口宽 400vp，底部表面宽 384vp、距窗口左边 8vp；窗口宽 700vp，表面仍宽 384vp、距窗口左边 158vp；窗口宽 360vp，表面缩为 344vp、距窗口左边 8vp。这些值由宽度模型直接推导，说明“内部各留 8vp”不代表任何窗口下都距物理屏幕边缘 8vp。START/END 锚点还会改变位置。

**明确的边缘距离和内部留白**

| 位置 | 源码中的距离 | 参照对象/作用 | 证据 |
| --- | --- | --- | --- |
| 底部栏左右、底部 | 左右各 8vp，底部 8vp | 定位框 padding；底部还有动态透明尾部 | [外层 padding](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/BrowserShell.ets:6384) |
| 底部操作行左右 | 各 20vp | 可见材质表面内部留白 | [操作行 padding](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/BrowserActionToolbar.ets:287)、[20vp 常量](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/model/BrowserVisualMetrics.ets:78) |
| 地址框 | 上方 8vp；编辑文本安全留白 16vp；安全控件预留 40vp | 地址框内部布局，不是屏幕边缘距离 | [顶部常量](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/model/TabOverviewActions.ets:35)、[文本留白常量](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/model/BrowserVisualMetrics.ets:87) |
| 通用独立悬浮控件 | 侧边 16vp，并按可用空间限制 | START/END 模式下相对安全区域边缘定位 | [定位 helper](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/model/BrowserVisualMetrics.ets:312) |
| 书签/历史内容卡片 | 居中宽度扣 24vp，等效左右各 12vp | 弹层内部内容区域 | [卡片宽度](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/LibrarySheet.ets:1631) |
| 书签/历史顶部、底部 | 顶部 8～12vp；底部 `max(0,bottomInset-16)+8` | 顶部留白及安全区占位，不是固定行高 | [顶部](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/LibrarySheet.ets:1564)、[底部](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/LibrarySheet.ets:1529) |
| 书签浮动编辑按钮 | 一侧 `max(16, correspondingInset+16)`；底部 `safeBottomInset()+12` | 相对与弹层同宽的悬浮宿主内部定位；按钮自身 52×52vp | [宿主 padding](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/LibrarySheet.ets:1716)、[按钮](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/LibrarySheet.ets:1509) |
| 标签概览搜索框 | 左右各 12vp；顶部 `10+topInset`；底部 4vp | 概览内部外边距；宽度同时扣左右 24vp | [搜索框](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/TabOverview.ets:364) |
| 标签网格 | 左右各 16vp；行列间距 12vp；底部 10vp | 参与两列卡片宽度计算 | [网格](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/TabOverview.ets:433) |
| 起始页 | 左右各 18vp、上 16vp、下 28vp | 首页内容容器内部留白；背景分区还可增加 12vp | [内容 padding](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/StartPage.ets:329)、[分区 padding](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/StartPage.ets:287) |
| 背景调整预览区 | 左右 margin 各 12vp | 预览区域的外边距；内部图片框另按测量值计算 | [预览区](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/StartPageBackgroundAdjustSheet.ets:188) |
| 错误页 | 四边 padding 28vp | 错误内容区域的内部留白 | [错误页](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/BrowserErrorView.ets:54) |

**全部界面文件核查清单**

| 文件 | 固定尺寸部分 | 非固定/跟随父布局部分 | 主要证据 |
| --- | --- | --- | --- |
| AddressSearchBar.ets | 地址/输入区域高 44vp；清除和锁按钮 32×32vp | 外层宽 100%；输入权重 1；容器按状态高 44/52vp | [输入](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/AddressSearchBar.ets:447) |
| AddressTabStrip.ets | 正常行高 52vp，过渡行高 44vp | 宽取父布局、测量值或过渡帧；地址项目再扣左右留白；过渡含缩放 | [helper](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/AddressTabStrip.ets:114) |
| BottomBrowserBar.ets | 材质高 100vp，地址行 52vp、工具行 48vp | 宽跟随外框；总高加动态安全区尾部 | [材质和尾部](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/BottomBrowserBar.ets:149) |
| BrowserActionToolbar.ets | 图标容器 26×26vp；按钮高 44vp、操作行高 48vp | 按钮宽按 Row 权重分配；操作行宽 100% | [按钮尺寸](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/BrowserActionToolbar.ets:115) |
| BrowserErrorView.ets | 内部留白 28vp | 根宽高 100%；文本和两个系统按钮没有独立固定宽高 | [build](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/BrowserErrorView.ets:31) |
| BrowserShell.ets | 引用统一图标/底部栏尺寸模型 | 根宽高 100%；实时窗口与四边安全区驱动控件参数和位置 | [安全区赋值](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/BrowserShell.ets:1722)、[底部栏外框](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/BrowserShell.ets:6382) |
| BrowserTransitionScene.ets | 刷新指示图形 28×28vp 等 | 场景跟随 viewport；内容高度扣顶部安全区；过渡裁剪与刷新占位随状态变化 | [场景尺寸](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/BrowserTransitionScene.ets:152)、[渲染占位](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/BrowserTransitionScene.ets:401) |
| DownloadManagerSheet.ets | 部分操作按钮 32×32vp；标题行高 52vp | 外框 100%×56%；内容宽 80%；列表高按权重分配 | [外框](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/DownloadManagerSheet.ets:336) |
| GestureLab.ets | 实验卡片内部宽 160vp；底栏高 72vp、按钮高 40vp | 实验页面容器有 100%、权重和网格比例；未在 main_pages 中独立登记 | [底栏](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/GestureLab.ets:328) |
| LibrarySheet.ets | 书签行高 52vp、历史行高 64vp；编辑按钮 52×52vp | 动态外框宽、56% 高、calc 内容宽、80% 列表宽；标题实测高度和搜索/删除动画占位 | [行高](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/LibrarySheet.ets:1283)、[外框](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/LibrarySheet.ets:1688) |
| PageDisplayMenu.ets | 触发按钮和宿主 48×34vp | 绑定的原生菜单没有在本文件中指定固定宽高 | [触发按钮](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/PageDisplayMenu.ets:75) |
| StartPage.ets | 编辑按钮 72×36vp；快捷按钮 56×56vp、54×54vp；部分卡片高 82vp | 整页/Scroll 宽高 100%；分区/卡片宽跟随父容器；文本按内容排版 | [首页外层](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/StartPage.ets:328) |
| StartPageBackgroundAdjustSheet.ets | 标题行高 56vp、操作按钮部分 44vp/40vp | 外框 100%×72%；预览框宽高按实测区域和图片比例推导 | [预览框](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/StartPageBackgroundAdjustSheet.ets:181)、[外框](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/StartPageBackgroundAdjustSheet.ets:204) |
| StartPageBackgroundImage.ets | 没有独立固定 vp 宽高 | 根和图片 100%×100%；裁切缩放跟随实测区域、图片尺寸和手势 | [图片](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/StartPageBackgroundImage.ets:201) |
| StartPageCustomizeSheet.ets | 部分标题行高 56vp；图标容器 26×26vp | 外框按表面模型取宽、高 56%；内部列表/卡片使用 100% 和权重 | [外框](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/StartPageCustomizeSheet.ets:578) |
| TabCard.ets | 卡片默认高 242vp、缩略区高 210vp、标题区高 32vp；关闭按钮 28×28vp | 卡片宽 100%，跟随所在 GridItem 列宽；cardHeight 也由参数传入 | [卡片尺寸](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/TabCard.ets:367) |
| TabNewPagePullPreview.ets | 没有独立固定 vp 宽高 | 占满父容器；水平位移按 viewportWidth 和进度计算 | [预览](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/TabNewPagePullPreview.ets:25) |
| TabOverview.ets | 卡片高 242vp；部分按钮 44×44vp；中间按钮组 108×52vp | 两列 1fr；搜索宽 calc；底栏含安全区；根宽高 100% | [网格](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/TabOverview.ets:433) |
| TopAlignedPixelMapImage.ets | 没有独立固定 vp 宽高 | 根和图片占满父容器；缩略图矩阵按实测像素尺寸计算 | [图片](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/TopAlignedPixelMapImage.ets:84) |
| WebTabHost.ets | 没有独立固定 vp 宽高 | Web 宿主和预览 100%×100%；onAreaChange 更新 viewport | [宿主](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/components/WebTabHost.ets:73) |
| WebTabNode.ets | 没有独立固定 vp 宽高 | Web 组件占满父容器；网页自身 DOM 布局不在本次 ArkUI 源码设置范围内 | [Web 尺寸](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/browser/web/WebTabNode.ets:360) |
| pages/Index.ets | 没有独立固定 vp 宽高 | 入口 Stack、背景和 BrowserShell 均 100%×100%，扩展安全区 | [入口](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/pages/Index.ets:24) |
| preview/SafariVideoParityPreview.ets | 预览中存在高 128vp、76vp 与 bottomInset=28 等示例参数 | 开发预览同时含 100% 和权重；不属于 main_pages 登记的入口 | [预览](E:/HarmonyOS/jianyue-browser/app/entry/src/main/ets/preview/SafariVideoParityPreview.ets:104) |

`LibrarySheet` 的两处 80% 列表均位于当前调用链：`build → sheetInteractionLayer → sheetContent → bookmarkContent / historyContent → listContent`，不是仅保留在文件中的旧 builder。起始页设置的 56% 是该组件第 582 行的直接字面量；书签/历史和下载管理的 56% 则来自 `LIBRARY_SHEET_HEIGHT_PERCENT`。

**可复查记录**

完整检索记录、文件清单和生成报告前的 SHA-256 快照保存于 [layout-audit-snapshot.json](C:/Users/ywkde/.codex/visualizations/2026/10/04/01a1070d-a74c-7cd1-b3d8-3052964fe471/layout-audit-snapshot.json)。检索记录用于定位全部相关属性调用；表中的固定/动态判断额外核对了常量、helper 和实际渲染调用关系。将全部布局改为固定尺寸时，需要为这些动态外框、列表和网格分别明确目标 vp 宽高；当前检查没有自行设定这些设计数值。
