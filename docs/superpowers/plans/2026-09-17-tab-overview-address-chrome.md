# 多页面地址栏与底部工具栏联动实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让上滑进入多页面时地址栏在卡片底边重合后随活动卡片上移，并让底部工具栏在地址栏完全离开后只回弹一次并保持隐藏。

**Architecture:** 保留现有 `overviewProgress` 作为唯一时间轴和 `TabOverviewChromeFrame` 作为唯一浏览器 Chrome 几何输出。新增基于 `TabOverviewPageFrame` 的动态重合点：地址栏先保持正常工具栏位置，卡片底边进入地址栏高度后完成短暂交接，之后地址栏底边严格跟随当前卡片底边；工具栏隐藏开始点由地址栏/卡片几何计算，而不是固定百分比。

**Tech Stack:** HarmonyOS ArkTS/ArkUI `@ComponentV2`、ArkWeb live page transform、Hypium Local Test、DevEco CLI。

---

## 文件边界

- Modify: `app/entry/src/main/ets/browser/model/TabOverviewActions.ets`
  - 重写地址栏的两阶段屏幕坐标计算。
  - 增加动态地址栏交接和工具栏离开点计算。
  - 删除不再使用的固定 `tabOverviewChromeOpacity`/`tabOverviewChromeTranslateY` 时间轴。
- Modify: `app/entry/src/test/ets/test/TabOverviewTransition.test.ets`
  - 先增加能够复现现有漂移的失败测试，再更新旧的固定时间轴断言。
  - 覆盖中间帧重合、动态工具栏回弹、反向恢复和深行 Grid 偏移。
- Do not modify by default: `BrowserShell.ets`, `AddressTabStrip.ets`, `BrowserTransitionScene.ets`
  - 它们已经消费同一个 `TabOverviewChromeFrame`；只有构建或运行证据证明消费层有独立偏移时才扩大范围。
- Create during verification: `hap/YYYYMMDD-HHMMSS-tab-overview-address-chrome-debug-unsigned.hap`
  - 只作为本次验证产物，不将运行截图、日志或旧 HAP 加入提交。

## Task 1: 建立失败的几何回归测试

**Files:**
- Modify: `app/entry/src/test/ets/test/TabOverviewTransition.test.ets`

- [ ] **Step 1: 替换固定工具栏时间轴测试为动态行为测试**

将 `moves the browser bar down on entry and back up on dismissal` 改为针对 `tabOverviewChromeFrame()` 的断言，并保留旧函数导入直到生产代码移除完成。新增以下测试结构：

```ts
it('attaches the address bottom to the current card bottom after overlap', 0, () => {
  const page: TabOverviewPageFrame = tabOverviewPageFrame(0.5, 400, 800, 0, 0);
  const frame: TabOverviewChromeFrame = tabOverviewChromeFrame(
    0.5, false, 400, 800, 104, page
  );
  const addressBottom: number = frame.addressVisualTop + frame.addressVisualHeight;
  const cardBottom: number = page.clipTop + page.clipHeight;
  expect(Math.abs(addressBottom - cardBottom) <= 0.000001).assertTrue();
});

it('starts toolbar rebound only after the address leaves the bottom chrome', 0, () => {
  const before: TabOverviewPageFrame = tabOverviewPageFrame(0.18, 400, 800, 0, 0);
  const after: TabOverviewPageFrame = tabOverviewPageFrame(0.3, 400, 800, 0, 0);
  const beforeChrome: TabOverviewChromeFrame = tabOverviewChromeFrame(
    0.18, false, 400, 800, 104, before
  );
  const afterChrome: TabOverviewChromeFrame = tabOverviewChromeFrame(
    0.3, false, 400, 800, 104, after
  );
  expect(beforeChrome.toolbarOpacity).assertEqual(1);
  expect(afterChrome.toolbarOpacity < 1).assertTrue();
  expect(afterChrome.toolbarTranslateY > 0).assertTrue();
});

it('uses the same toolbar geometry while reversing the overview', 0, () => {
  const page: TabOverviewPageFrame = tabOverviewPageFrame(0.3, 400, 800, 0, 0);
  const entering: TabOverviewChromeFrame = tabOverviewChromeFrame(
    0.3, false, 400, 800, 104, page
  );
  const leaving: TabOverviewChromeFrame = tabOverviewChromeFrame(
    0.3, true, 400, 800, 104, page
  );
  expect(leaving.toolbarOpacity.toFixed(6)).assertEqual(entering.toolbarOpacity.toFixed(6));
  expect(leaving.toolbarTranslateY.toFixed(6)).assertEqual(entering.toolbarTranslateY.toFixed(6));
});
```

The `0.5` assertion is intentionally incompatible with the current target interpolation: the current implementation leaves a positive gap between the current page clip bottom and the address capsule bottom.

- [ ] **Step 2: Run the focused Local Test and verify it fails for the intended reason**

Run from `E:\HarmonyOS\jianyue-browser`:

```text
python D:\.codex\skills\hmos-local-test\scripts\run_local_test.py --project-path E:\HarmonyOS\jianyue-browser --module entry --no-coverage --scope TabOverviewTransition
```

Expected result: the suite is collected, and the new address/card assertion fails because the current frame uses the fixed target interpolation; no test collection or ArkTS syntax error is acceptable.

## Task 2: Implement the single-geometry Chrome frame

**Files:**
- Modify: `app/entry/src/main/ets/browser/model/TabOverviewActions.ets`

- [ ] **Step 1: Replace fixed hide constants with geometry handoff constants**

Keep the existing caption handoff constants. Replace the old toolbar stretch/hide constants with:

```ts
/** Short screen-space handoff after the card bottom reaches the address row. */
export const TAB_OVERVIEW_ADDRESS_ATTACH_DURATION_PROGRESS: number = 0.08;
/** Address-only jelly remains independent from the toolbar exit handoff. */
export const TAB_OVERVIEW_ADDRESS_JELLY_START_PROGRESS: number = 0.22;
export const TAB_OVERVIEW_ADDRESS_JELLY_END_PROGRESS: number = 0.44;
/** The bottom toolbar leaves in one short rebound after its dynamic exit point. */
export const TAB_OVERVIEW_TOOLBAR_HIDE_DURATION_PROGRESS: number = 0.20;
```

Keep `overviewSegmentProgress()` and `overviewJellyProgress()` as the bounded interpolation helpers.

- [ ] **Step 2: Add the dynamic progress helpers immediately above `tabOverviewChromeFrame()`**

Add these pure helpers:

```ts
function tabOverviewAddressAttachStartProgress(
  viewportHeight: number,
  addressTop: number,
  addressHeight: number,
  targetCardBottom: number,
  targetScaleY: number
): number {
  const initialGap: number = viewportHeight - (addressTop + addressHeight);
  const targetGap: number = targetCardBottom -
    (addressTop + addressHeight * targetScaleY);
  const denominator: number = initialGap - targetGap;
  if (!Number.isFinite(denominator) || denominator <= 0) {
    return 1;
  }
  return Math.max(0, Math.min(1, initialGap / denominator));
}

function tabOverviewToolbarExitProgress(
  viewportHeight: number,
  chromeHeight: number,
  targetCardBottom: number
): number {
  const distance: number = viewportHeight - targetCardBottom;
  if (!Number.isFinite(distance) || distance <= 0) {
    return 1;
  }
  return Math.max(0, Math.min(1, chromeHeight / distance));
}
```

`addressTop` is the normal visible capsule top (`height - chromeHeight + ADDRESS_SEARCH_BAR_TOP_PADDING`) and `addressHeight` is `ADDRESS_SEARCH_BAR_STYLE.height`. These helpers use the target card geometry only to find the dynamic handoff point; the current frame itself must always use `pageFrame.clipTop`, `pageFrame.clipHeight`, and `pageFrame.scaleY`.

- [ ] **Step 3: Change `tabOverviewChromeFrame()` to use current card geometry**

Inside the function, retain the existing target geometry recovery for `targetScaleY`, `targetTop`, and `targetHeight`, then replace the four interpolated address visual values with:

```ts
const currentCardBottom: number = pageFrame.clipTop + pageFrame.clipHeight;
const addressHeight: number = fullHeight * scaleY;
const attachStart: number = tabOverviewAddressAttachStartProgress(
  height,
  fullTop,
  fullHeight,
  targetTop + targetHeight,
  targetScaleY
);
const attachEnd: number = Math.min(
  1,
  attachStart + TAB_OVERVIEW_ADDRESS_ATTACH_DURATION_PROGRESS
);
const attachProgress: number = overviewSegmentProgress(
  clampedProgress,
  attachStart,
  attachEnd
);
const attachedTop: number = currentCardBottom - addressHeight;
const visualTop: number = interpolateOverviewValue(fullTop, attachedTop, attachProgress);
// Horizontal geometry keeps the existing page-to-card inset track. The
// address capsule is inset from the card's outer clip by the same 8vp on
// both ends, so using clipLeft directly would break the normal first frame.
const visualLeft: number = interpolateOverviewValue(fullLeft, targetLeft, clampedProgress);
const visualWidth: number = interpolateOverviewValue(fullWidth, targetWidth, clampedProgress);
const visualHeight: number = addressHeight;
```

Before `attachStart`, the address capsule remains in its normal bottom-chrome position. During the short handoff it moves to `currentCardBottom - addressHeight`; after `attachEnd`, its bottom edge is exactly the current card bottom. This uses the current Grid scroll offset already embedded in `pageFrame.clipTop`.

- [ ] **Step 4: Replace fixed toolbar hide progress with the dynamic exit point**

Replace the `closing`/opening branch that uses `TAB_OVERVIEW_TOOLBAR_HIDE_START_PROGRESS` with one shared reversible track:

```ts
const jellyProgress: number = closing
  ? overviewJellyProgress(clampedProgress, 0, TAB_OVERVIEW_ADDRESS_RETURN_JELLY_END_PROGRESS)
  : overviewJellyProgress(
    clampedProgress,
    TAB_OVERVIEW_ADDRESS_JELLY_START_PROGRESS,
    TAB_OVERVIEW_ADDRESS_JELLY_END_PROGRESS
  );
const toolbarExitStart: number = tabOverviewToolbarExitProgress(
  height,
  safeChromeHeight,
  targetTop + targetHeight
);
const toolbarExitEnd: number = Math.min(
  1,
  toolbarExitStart + TAB_OVERVIEW_TOOLBAR_HIDE_DURATION_PROGRESS
);
const toolbarHideProgress: number = overviewSegmentProgress(
  clampedProgress,
  toolbarExitStart,
  toolbarExitEnd
);
const toolbarJellyProgress: number = overviewJellyProgress(
  clampedProgress,
  toolbarExitStart,
  toolbarExitEnd
);
const toolbarJellyAnchorOffset: number = toolbarJellyProgress * safeChromeHeight * 0.05;
const toolbarOpacity: number = 1 - toolbarHideProgress;
const toolbarTranslateY: number = safeChromeHeight * toolbarHideProgress -
  toolbarJellyAnchorOffset;
```

Use the resulting `toolbarOpacity`, `toolbarTranslateY`, `toolbarScaleX`, and `toolbarScaleY` for both entry and reverse frames. `closing` remains an input for the address return jelly and z-order only; it must not introduce a second toolbar position timeline.

- [ ] **Step 5: Remove the obsolete fixed Chrome helpers**

Delete the unused `tabOverviewChromeOpacity()`, `tabOverviewChromeTranslateY()`, `TAB_OVERVIEW_TOOLBAR_STRETCH_*`, `TAB_OVERVIEW_TOOLBAR_HIDE_*`, and `tabOverviewChromeMotionProgress()` exports/helpers after updating the tests. Verify with:

```text
rg -n "tabOverviewChromeOpacity|tabOverviewChromeTranslateY|TAB_OVERVIEW_TOOLBAR_HIDE_START_PROGRESS|tabOverviewChromeMotionProgress" app
```

Expected result: no matches.

## Task 3: Run the green model tests and refactor only after green

**Files:**
- Modify: `app/entry/src/test/ets/test/TabOverviewTransition.test.ets`

- [ ] **Step 1: Update existing address-track expectations**

Change the old middle-frame expected top from a target-end interpolation to a current-card-bottom assertion:

```ts
const addressBottom: number = frame.addressVisualTop + frame.addressVisualHeight;
const cardBottom: number = middlePage.clipTop + middlePage.clipHeight;
expect(addressBottom.toFixed(6)).assertEqual(cardBottom.toFixed(6));
```

Keep the existing width and scale assertions because they still verify the shared page track.

- [ ] **Step 2: Update reverse-jelly coverage to sample the dynamic exit window**

Use `0.3` for the reverse toolbar jelly test instead of `0.09`, because the toolbar is now expected to be fully visible before the dynamic exit point and to return along the same geometry after it.

- [ ] **Step 3: Run the focused suite and then the complete entry Local Test**

Run:

```text
python D:\.codex\skills\hmos-local-test\scripts\run_local_test.py --project-path E:\HarmonyOS\jianyue-browser --module entry --no-coverage --scope TabOverviewTransition
python D:\.codex\skills\hmos-local-test\scripts\run_local_test.py --project-path E:\HarmonyOS\jianyue-browser --module entry --no-coverage
```

Expected result: `TabOverviewTransition` passes, then the complete `entry` module reports success. If the first command fails for collection or ArkTS compilation, fix that issue before running the full module.

- [ ] **Step 4: Commit the model and test change**

Stage only the two implementation files:

```text
git add app/entry/src/main/ets/browser/model/TabOverviewActions.ets app/entry/src/test/ets/test/TabOverviewTransition.test.ets
git commit -m fix-tab-overview-address-toolbar-geometry
```

## Task 4: Build, install, and verify the real transition

**Files:**
- Create: `hap/YYYYMMDD-HHMMSS-tab-overview-address-chrome-debug-unsigned.hap`
- Create: fresh runtime screenshots and layout/log evidence as untracked files only.

- [ ] **Step 1: Confirm DevEco CLI before build/device operations**

Run:

```text
devecocli --version
```

Expected result: a version string. Do not call build/run/device commands if the command is unavailable; report the environment blocker instead.

- [ ] **Step 2: Build the entry HAP with DevEco CLI**

Run:

```text
devecocli build --modules entry@default
```

Expected result: a successful debug HAP under `app/entry/build/default/outputs/default/`. Copy only that fresh HAP into the root `hap` directory with a timestamped name; do not delete or stage any existing HAP.

- [ ] **Step 3: Install and launch on the existing Mate 80 emulator**

Run:

```text
devecocli device list
devecocli run --module entry --device 127.0.0.1:5555 --skip-build
```

If the device serial differs, use the serial returned by `devecocli device list`. Capture a launch screenshot before the gesture.

- [ ] **Step 4: Capture the five runtime states**

Use `devecocli ui screenshot` and `devecocli ui layout --format json --mode full` for:

1. Normal page with the address bar and bottom chrome.
2. Slow upward drag before card/address overlap.
3. The overlap/rebound frame where the address bar leaves the bottom chrome.
4. Settled multi-page view with the bottom chrome hidden.
5. Select a card to exit and capture the reverse rebound.

Run `devecocli log --device 127.0.0.1:5555 --bundle-name com.ahuaiab.jianyuebrowser --from 30s --tail 300` after the interaction and retain only relevant evidence files as untracked artifacts.

- [ ] **Step 5: Check acceptance criteria against evidence**

Confirm the screenshots and layout values show:

- address bottom equals active card bottom after the overlap handoff;
- toolbar does not begin moving before address exit;
- toolbar is transparent and below the viewport at settled overview;
- toolbar returns during card selection and no duplicate address/caption text is visible;
- a lower active Grid row follows its measured scroll offset.

If runtime evidence disproves the model, return to Task 2 rather than adjusting screenshots or claiming completion from a successful build alone.

## Self-review checklist

- [ ] Every requirement in `docs/superpowers/specs/2026-09-17-tab-overview-address-chrome-design.md` is covered by Tasks 1–4.
- [ ] No production code is changed before the new tests fail.
- [ ] No fixed toolbar hide timeline remains in `app` after Task 2.
- [ ] The page and address tracks use `pageFrame` current geometry, including Grid scroll offset.
- [ ] Existing unrelated HAP deletions, runtime screenshots, and `deveco-scroll-doc.txt` remain unstaged.
