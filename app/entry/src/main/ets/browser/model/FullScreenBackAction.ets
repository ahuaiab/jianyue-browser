/** Decide whether the active full-screen video consumes a system back press. */
export function consumeFullScreenBackPress(
  isFullScreen: boolean,
  exitFullScreen: (() => void) | undefined
): boolean {
  if (!isFullScreen) {
    return false;
  }
  exitFullScreen?.();
  return true;
}
