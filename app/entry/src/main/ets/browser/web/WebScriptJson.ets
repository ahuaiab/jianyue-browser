/**
 * ArkWeb serializes JavaScript string results once. Accept both that form and
 * direct JSON so callers only receive structured data, never a boxed string.
 */
export function readWebScriptJson(value: string): Object | undefined {
  try {
    let parsed: Object = JSON.parse(value) as Object;
    if (typeof parsed === 'string') {
      parsed = JSON.parse(parsed as string) as Object;
    }
    return parsed !== null && typeof parsed === 'object' ? parsed : undefined;
  } catch (_error) {
    return undefined;
  }
}
