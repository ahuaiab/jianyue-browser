(function readerModeRuntime(action, expectedUrl, preferences, libraries) {
  const hostAttribute = 'data-jianyue-reader-mode-host';
  const rootAttribute = 'data-jianyue-reader-active';
  let createdHost = null;

  function result(status, available, active, reason) {
    return JSON.stringify({ status: status, available: available, active: active, reason: reason || '' });
  }

  function safePageUrl(value) {
    try {
      const parsed = new URL(value);
      return (parsed.protocol === 'http:' || parsed.protocol === 'https:') &&
        parsed.username.length === 0 && parsed.password.length === 0;
    } catch (_) {
      return false;
    }
  }

  function cleanup(host, restoreScroll) {
    if (!host) return;
    const state = host.__jianyueReaderState;
    if (state && state.documentSheet) {
      try {
        document.adoptedStyleSheets = document.adoptedStyleSheets.filter(function(sheet) {
          return sheet !== state.documentSheet;
        });
      } catch (_) {}
    }
    if (state) {
      if (state.previousRootMarker === null) {
        document.documentElement.removeAttribute(rootAttribute);
      } else {
        document.documentElement.setAttribute(rootAttribute, state.previousRootMarker);
      }
      if (state.viewportMeta) {
        if (state.viewportExisted) {
          if (state.viewportContent === null) state.viewportMeta.removeAttribute('content');
          else state.viewportMeta.setAttribute('content', state.viewportContent);
        } else if (state.viewportMeta.parentNode) {
          state.viewportMeta.parentNode.removeChild(state.viewportMeta);
        }
      }
    }
    if (host.parentNode) host.parentNode.removeChild(host);
    if (restoreScroll && state && state.pageUrl === location.href) {
      const savedUrl = state.pageUrl;
      const savedX = state.scrollX;
      const savedY = state.scrollY;
      window.requestAnimationFrame(function() {
        if (location.href === savedUrl) window.scrollTo(savedX, savedY);
      });
    }
  }

  function setPreferences(host, value) {
    const size = value && (value.textSize === 'small' || value.textSize === 'large')
      ? value.textSize : 'standard';
    const theme = value && (value.theme === 'sepia' || value.theme === 'gray' || value.theme === 'dark')
      ? value.theme : 'white';
    host.setAttribute('data-reader-size', size);
    host.setAttribute('data-reader-theme', theme);
  }

  function findHost() {
    return document.querySelector('[' + hostAttribute + '="1"]');
  }

  function safeArticleUrls(root) {
    const links = root.querySelectorAll('a[href]');
    for (let i = 0; i < links.length; i++) {
      try {
        const url = new URL(links[i].getAttribute('href'), expectedUrl);
        if ((url.protocol === 'http:' || url.protocol === 'https:' || url.protocol === 'mailto:') &&
            !url.username && !url.password) links[i].setAttribute('href', url.href);
        else links[i].removeAttribute('href');
      } catch (_) { links[i].removeAttribute('href'); }
    }
    const images = root.querySelectorAll('img[src]');
    for (let i = 0; i < images.length; i++) {
      try {
        const url = new URL(images[i].getAttribute('src'), expectedUrl);
        if ((url.protocol === 'http:' || url.protocol === 'https:') &&
            !url.username && !url.password) images[i].setAttribute('src', url.href);
        else images[i].removeAttribute('src');
      } catch (_) { images[i].removeAttribute('src'); }
    }
  }

  try {
    if (!safePageUrl(expectedUrl) || location.href !== expectedUrl) {
      return result('unavailable', false, false, 'url-mismatch-or-unsupported');
    }

    let host = findHost();
    if (host && host.__jianyueReaderState && host.__jianyueReaderState.pageUrl !== expectedUrl) {
      cleanup(host, false);
      host = null;
    }
    if (action === 'exit') {
      cleanup(host, true);
      return result('available', true, false, 'exited');
    }
    if (host && host.__jianyueReaderState && host.__jianyueReaderState.pageUrl === expectedUrl) {
      if (action === 'preferences') setPreferences(host, preferences);
      return result('active', true, true, 'reader-active');
    }
    if (action === 'preferences') return result('unavailable', false, false, 'reader-not-active');

    if (document.getElementsByTagName('*').length > 5000) {
      return result('unavailable', false, false, 'page-too-large');
    }
    const sourceClone = document.cloneNode(true);
    if (typeof libraries.isProbablyReaderable === 'function' &&
        !libraries.isProbablyReaderable(sourceClone, { minContentLength: 120, minScore: 10 })) {
      return result('unavailable', false, false, 'not-readerable');
    }
    const parsed = new libraries.Readability(sourceClone, { charThreshold: 180 }).parse();
    if (!parsed || typeof parsed.content !== 'string') {
      return result('unavailable', false, false, 'no-article');
    }

    const cleanContent = libraries.DOMPurify.sanitize(parsed.content, {
      ALLOWED_TAGS: [
        'a', 'article', 'b', 'blockquote', 'br', 'caption', 'code', 'dd', 'del', 'div', 'dl', 'dt',
        'em', 'figcaption', 'figure', 'h1', 'h2', 'h3', 'h4', 'hr', 'i', 'img', 'li', 'ol', 'p',
        'pre', 's', 'small', 'span', 'strong', 'sub', 'sup', 'table', 'tbody', 'td', 'th', 'thead',
        'tr', 'u', 'ul'
      ],
      ALLOWED_ATTR: ['alt', 'colspan', 'dir', 'height', 'href', 'lang', 'rowspan', 'src', 'title', 'width'],
      ALLOW_DATA_ATTR: false,
      FORBID_TAGS: ['audio', 'button', 'embed', 'form', 'iframe', 'input', 'object', 'script', 'select',
        'style', 'svg', 'textarea', 'video'],
      FORBID_ATTR: ['style', 'srcdoc', 'target', 'onerror', 'onclick']
    });

    const validationContainer = document.createElement('div');
    validationContainer.innerHTML = cleanContent;
    const textContent = (validationContainer.textContent || '').replace(/\s+/g, ' ').trim();
    const paragraphCount = validationContainer.querySelectorAll('p').length;
    if (!parsed.title || parsed.title.trim().length === 0 || textContent.length < 180 || paragraphCount < 2) {
      return result('unavailable', false, false, 'article-too-short');
    }
    if (action === 'probe') return result('available', true, false, 'reader-available');

    const body = document.body;
    if (!body) return result('unavailable', false, false, 'body-unavailable');

    const savedScrollX = window.scrollX;
    const savedScrollY = window.scrollY;
    const previousRootMarker = document.documentElement.getAttribute(rootAttribute);
    const viewportMeta = document.querySelector('meta[name="viewport"]');
    const viewportExisted = viewportMeta !== null;
    const viewportContent = viewportExisted ? viewportMeta.getAttribute('content') : null;
    let activeViewportMeta = viewportMeta;
    if (!activeViewportMeta) {
      activeViewportMeta = document.createElement('meta');
      activeViewportMeta.setAttribute('name', 'viewport');
    }

    createdHost = document.createElement('div');
    createdHost.setAttribute(hostAttribute, '1');
    createdHost.setAttribute('role', 'region');
    createdHost.setAttribute('aria-label', '阅读模式');
    const documentSheet = new CSSStyleSheet();
    const state = {
      pageUrl: expectedUrl,
      scrollX: savedScrollX,
      scrollY: savedScrollY,
      documentSheet: documentSheet,
      previousRootMarker: previousRootMarker,
      viewportMeta: activeViewportMeta,
      viewportExisted: viewportExisted,
      viewportContent: viewportContent
    };
    createdHost.__jianyueReaderState = state;

    const readerSheet = new CSSStyleSheet();
    readerSheet.replaceSync(
      ':host{display:block;color-scheme:light dark;font-family:system-ui,-apple-system,sans-serif}' +
      '#surface{box-sizing:border-box;min-height:100vh;width:100%;padding:24px 20px 48px;' +
        'background:var(--reader-bg);color:var(--reader-fg)}' +
      '#article{box-sizing:border-box;width:100%;max-width:720px;margin:0 auto;font-size:var(--reader-size);' +
        'line-height:1.75;overflow-wrap:anywhere}' +
      '#article h1{font-size:1.65em;line-height:1.3;margin:0 0 18px;font-weight:650}' +
      '#article img{display:block;max-width:100%;height:auto;margin:18px auto;border-radius:6px}' +
      '#article a{color:#0878d1;text-decoration:underline}' +
      '#article blockquote{margin:16px 0;padding:8px 14px;border-left:3px solid var(--reader-muted);' +
        'color:var(--reader-muted)}' +
      '#article table{display:block;max-width:100%;overflow-x:auto;border-collapse:collapse}' +
      '#article td,#article th{border:1px solid var(--reader-muted);padding:6px 8px}' +
      ':host([data-reader-size="small"]){--reader-size:16px}' +
      ':host([data-reader-size="standard"]){--reader-size:18px}' +
      ':host([data-reader-size="large"]){--reader-size:21px}' +
      ':host([data-reader-theme="white"]){--reader-bg:#ffffff;--reader-fg:#202124;--reader-muted:#72777d}' +
      ':host([data-reader-theme="sepia"]){--reader-bg:#f4ecd8;--reader-fg:#493b2b;--reader-muted:#88745b}' +
      ':host([data-reader-theme="gray"]){--reader-bg:#ededed;--reader-fg:#252525;--reader-muted:#737373}' +
      ':host([data-reader-theme="dark"]){--reader-bg:#171819;--reader-fg:#e7e7e7;--reader-muted:#a1a1a1}'
    );
    const shadow = createdHost.attachShadow({ mode: 'open' });
    shadow.adoptedStyleSheets = [readerSheet];

    const surface = document.createElement('main');
    surface.setAttribute('id', 'surface');
    const article = document.createElement('article');
    article.setAttribute('id', 'article');
    const heading = document.createElement('h1');
    heading.textContent = parsed.title;
    article.appendChild(heading);
    const content = document.createElement('div');
    content.innerHTML = cleanContent;
    safeArticleUrls(content);
    article.appendChild(content);
    surface.appendChild(article);
    shadow.appendChild(surface);
    setPreferences(createdHost, preferences || {});

    documentSheet.replaceSync(
      'html[' + rootAttribute + '="1"]{height:auto!important;overflow-x:hidden!important;overflow-y:auto!important}' +
      'html[' + rootAttribute + '="1"] body{display:block!important;position:static!important;width:100%!important;' +
        'height:auto!important;min-height:100vh!important;overflow:visible!important;margin:0!important;padding:0!important}' +
      'html[' + rootAttribute + '="1"] body>*:not([' + hostAttribute + '="1"]){display:none!important}' +
      'html[' + rootAttribute + '="1"] body>[' + hostAttribute + '="1"]{all:initial!important;display:block!important;' +
        'position:relative!important;width:100%!important;min-height:100vh!important;z-index:auto!important;contain:none!important}'
    );

    if (!viewportExisted && activeViewportMeta && document.head) document.head.appendChild(activeViewportMeta);
    if (activeViewportMeta) activeViewportMeta.setAttribute('content', 'width=device-width, initial-scale=1');
    document.documentElement.setAttribute(rootAttribute, '1');
    document.adoptedStyleSheets = document.adoptedStyleSheets.concat([documentSheet]);
    body.insertBefore(createdHost, body.firstChild);
    window.scrollTo(0, 0);
    return result('active', true, true, 'reader-entered');
  } catch (_) {
    if (createdHost) cleanup(createdHost, true);
    return result('error', false, false, 'reader-runtime-failed');
  }
})
