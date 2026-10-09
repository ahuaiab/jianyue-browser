import { describe, expect, it } from '@ohos/hypium';
import { readWebScriptJson } from '../../../main/ets/browser/web/WebScriptJson';

export default function webScriptJsonTest() {
  describe('WebScriptJson', () => {
    it('reads direct structured JSON', 0, () => {
      const parsed: Object | undefined = readWebScriptJson('{"status":"available","active":false}');
      expect(parsed === undefined).assertFalse();
      if (parsed !== undefined) {
        const fields: Record<string, Object> = parsed as Record<string, Object>;
        expect(fields['status']).assertEqual('available');
        expect(fields['active']).assertEqual(false);
      }
    });

    it('unwraps ArkWeb string serialization once', 0, () => {
      const serializedOnce: string = JSON.stringify({ status: 'active', available: true });
      const arkWebResult: string = JSON.stringify(serializedOnce);
      const parsed: Object | undefined = readWebScriptJson(arkWebResult);
      expect(parsed === undefined).assertFalse();
      if (parsed !== undefined) {
        const fields: Record<string, Object> = parsed as Record<string, Object>;
        expect(fields['status']).assertEqual('active');
        expect(fields['available']).assertEqual(true);
      }
    });

    it('accepts structured arrays', 0, () => {
      const directArray: Object | undefined = readWebScriptJson('[1,"two",{"three":3}]');
      expect(directArray !== undefined && Array.isArray(directArray)).assertTrue();
      const wrappedArray: Object | undefined = readWebScriptJson(JSON.stringify('[1,2,3]'));
      expect(wrappedArray !== undefined && Array.isArray(wrappedArray)).assertTrue();
    });

    it('rejects malformed JSON, null, primitives, and excessive string wrapping', 0, () => {
      expect(readWebScriptJson('{broken')).assertUndefined();
      expect(readWebScriptJson('null')).assertUndefined();
      expect(readWebScriptJson('true')).assertUndefined();
      expect(readWebScriptJson('42')).assertUndefined();
      expect(readWebScriptJson(JSON.stringify(JSON.stringify('plain string')))).assertUndefined();
    });
  });
}
