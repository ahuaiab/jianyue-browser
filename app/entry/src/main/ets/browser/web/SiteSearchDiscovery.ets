export const SITE_SEARCH_FORM_SCAN_SCRIPT: string = `(() => {
  try {
    const sensitive = /(pass(word|wd)?|credential|auth|token|csrf|xsrf|session|cookie|secret|login|email|phone|mobile|account|user(name)?|nonce|verification|captcha)/i;
    const searchWords = /(search|query|keyword|find|搜索|查找)/i;
    const forms = Array.from(document.forms).slice(0, 100);
    const result = [];
    for (const form of forms) {
      const method = String(form.method || 'get').trim().toLowerCase();
      if (method !== 'get') continue;
      const action = new URL(form.action || location.href, location.href);
      if (!/^https?:$/.test(action.protocol) || action.origin !== location.origin) continue;
      const controls = Array.from(form.querySelectorAll('input, textarea, select'));
      const hasPasswordField = controls.some((item) => item.type === 'password');
      const hasSensitiveField = controls.some((item) => sensitive.test([item.name, item.id, item.autocomplete, item.getAttribute('aria-label') || ''].join(' ')));
      if (hasPasswordField || hasSensitiveField) continue;
      const roleSearch = String(form.getAttribute('role') || '').toLowerCase() === 'search';
      const searchFields = controls.filter((item) => {
        if (!item.name || item.disabled || item.type === 'hidden' || item.type === 'password') return false;
        const label = [item.name, item.id, item.type, item.placeholder, item.title, item.getAttribute('aria-label') || '',
          Array.from(item.labels || []).map((labelItem) => labelItem.innerText || '').join(' ')].join(' ');
        const isTextInput = item.tagName.toLowerCase() === 'textarea' || ['text', 'search', 'url'].includes(String(item.type || 'text').toLowerCase());
        return isTextInput && (String(item.type || '').toLowerCase() === 'search' || searchWords.test(label) || roleSearch);
      });
      if (searchFields.length !== 1) continue;
      const field = searchFields[0];
      const fieldLabel = [field.name, field.placeholder, field.title, field.getAttribute('aria-label') || '',
        Array.from(field.labels || []).map((labelItem) => labelItem.innerText || '').join(' ')].join(' ').trim();
      const searchSemantic = roleSearch || String(field.type || '').toLowerCase() === 'search' || searchWords.test(fieldLabel);
      if (!searchSemantic) continue;
      const hiddenFields = controls.filter((item) => item.type === 'hidden' && item.name && item.value && !sensitive.test(item.name))
        .slice(0, 8).map((item) => ({ name: String(item.name).slice(0, 40), value: String(item.value).slice(0, 128) }));
      result.push({ pageUrl: location.href, pageTitle: String(document.title || '').slice(0, 64),
        actionUrl: action.href, method, searchFieldName: String(field.name).slice(0, 40),
        searchFieldType: String(field.type || 'text').toLowerCase(), searchSemantic, roleSearch,
        hasPasswordField, hasSensitiveField, hiddenFields });
    }
    return JSON.stringify(result.slice(0, 20));
  } catch (_error) {
    return '[]';
  }
})()`;