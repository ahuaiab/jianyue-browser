import { describe, expect, it } from '@ohos/hypium';
import { shouldShowPageLevelNetworkError } from '../../../main/ets/browser/model/BrowserLoadErrorPolicy';

export default function browserLoadErrorPolicyTest() {
  describe('BrowserLoadErrorPolicy', () => {
    it('shows main-frame errors regardless of pending state', 0, () => {
      expect(shouldShowPageLevelNetworkError(true, false, -2)).assertTrue();
    });

    it('promotes an offline subresource error while the page is loading', 0, () => {
      expect(shouldShowPageLevelNetworkError(false, true, -106)).assertTrue();
    });

    it('keeps a loaded page when a subresource goes offline', 0, () => {
      expect(shouldShowPageLevelNetworkError(false, false, -106)).assertFalse();
    });

    it('does not promote unrelated subresource failures', 0, () => {
      expect(shouldShowPageLevelNetworkError(false, true, -2)).assertFalse();
    });
  });
}
