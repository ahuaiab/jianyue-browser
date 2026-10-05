interface ParsedWebUrl {
  protocol: string;
  hostname: string;
  authority: string;
  origin: string;
  pathname: string;
  search: string;
  hash: string;
}

const MAX_DECLARED_PAGE_ICON_URLS: number = 8;

/** Resolve the first safe icon link declared by a page. */
export function resolveDeclaredPageIconUrl(pageUrl: string, html: string): string | undefined {
  const iconUrls: string[] = resolveDeclaredPageIconUrls(pageUrl, html);
  return iconUrls.length > 0 ? iconUrls[0] : undefined;
}

/** Resolve distinct safe icon links in document order, with a bound for oversized pages. */
export function resolveDeclaredPageIconUrls(pageUrl: string, html: string): string[] {
  const loweredHtml: string = html.toLowerCase();
  const iconUrls: string[] = [];
  let cursor: number = 0;

  while (cursor < html.length) {
    const linkStart: number = loweredHtml.indexOf('<link', cursor);
    if (linkStart < 0) {
      return iconUrls;
    }

    const commentStart: number = loweredHtml.indexOf('<!--', cursor);
    if (commentStart >= 0 && commentStart < linkStart) {
      const commentEnd: number = loweredHtml.indexOf('-->', commentStart + 4);
      if (commentEnd < 0) {
        return iconUrls;
      }
      cursor = commentEnd + 3;
      continue;
    }

    const nameEnd: number = linkStart + 5;
    if (nameEnd < html.length && !isTagBoundary(html.charAt(nameEnd))) {
      cursor = nameEnd;
      continue;
    }

    const tagEnd: number = findTagEnd(html, nameEnd);
    if (tagEnd < 0) {
      return iconUrls;
    }

    const attributes: Map<string, string> = parseAttributes(html, nameEnd, tagEnd);
    const rel: string | undefined = attributes.get('rel');
    const href: string | undefined = attributes.get('href');
    if (rel !== undefined && href !== undefined && containsWord(rel, 'icon')) {
      const decodedHref: string = decodeCommonHtmlEntities(href.trim());
      const resolved: string | undefined = resolvePageIconHref(pageUrl, decodedHref);
      if (resolved !== undefined && iconUrls.indexOf(resolved) < 0) {
        iconUrls.push(resolved);
        if (iconUrls.length >= MAX_DECLARED_PAGE_ICON_URLS) {
          return iconUrls;
        }
      }
    }

    cursor = tagEnd + 1;
  }

  return iconUrls;
}

/** Resolve a declared href against its page while rejecting unsafe schemes and HTTPS downgrade. */
export function resolvePageIconHref(pageUrl: string, href: string): string | undefined {
  const normalizedHref: string = href.trim();
  if (normalizedHref.length === 0) {
    return undefined;
  }

  const page: ParsedWebUrl | undefined = parseWebUrl(pageUrl);
  if (page === undefined) {
    return undefined;
  }

  const candidate: ParsedWebUrl | undefined = parseWebUrl(normalizedHref, serializeWebUrl(page));
  if (candidate === undefined) {
    return undefined;
  }

  if (page.protocol.toLowerCase() === 'https:' && candidate.protocol.toLowerCase() !== 'https:') {
    return undefined;
  }

  return serializeWebUrl(candidate);
}

/** Construct the final site-root /favicon.ico candidate. */
export function resolveDefaultPageIconUrl(pageUrl: string): string | undefined {
  const page: ParsedWebUrl | undefined = parseWebUrl(pageUrl);
  if (page === undefined) {
    return undefined;
  }
  return resolvePageIconHref(serializeWebUrl(page), `${page.origin}/favicon.ico`);
}

function parseWebUrl(value: string, base?: string): ParsedWebUrl | undefined {
  const normalized: string = value.trim();
  if (normalized.length === 0) {
    return undefined;
  }

  const colonIndex: number = normalized.indexOf(':');
  const firstPathBoundary: number = firstPositiveIndex(
    normalized.indexOf('/'), normalized.indexOf('?'), normalized.indexOf('#')
  );
  if (colonIndex >= 0 && (firstPathBoundary < 0 || colonIndex < firstPathBoundary)) {
    return normalized.slice(colonIndex + 1).startsWith('//')
      ? parseAbsoluteWebUrl(normalized)
      : undefined;
  }
  if (normalized.startsWith('//')) {
    if (base === undefined) {
      return undefined;
    }
    const protocolRelativeBase: ParsedWebUrl | undefined = parseAbsoluteWebUrl(base);
    return protocolRelativeBase === undefined
      ? undefined
      : parseAbsoluteWebUrl(`${protocolRelativeBase.protocol}${normalized}`);
  }
  if (base === undefined) {
    return undefined;
  }

  const parsedBase: ParsedWebUrl | undefined = parseAbsoluteWebUrl(base);
  if (parsedBase === undefined) {
    return undefined;
  }

  let pathname: string = parsedBase.pathname;
  let search: string = parsedBase.search;
  let hash: string = '';
  if (normalized.startsWith('#')) {
    hash = normalized;
  } else if (normalized.startsWith('?')) {
    const parts: string[] = splitSearchAndHash(normalized);
    search = parts[1];
    hash = parts[2];
  } else {
    const parts: string[] = splitSearchAndHash(normalized);
    const relativePath: string = parts[0];
    search = parts[1];
    hash = parts[2];
    if (relativePath.startsWith('/')) {
      pathname = normalizePath(relativePath);
    } else {
      const lastSlash: number = parsedBase.pathname.lastIndexOf('/');
      const baseDirectory: string = lastSlash < 0 ? '/' : parsedBase.pathname.slice(0, lastSlash + 1);
      pathname = normalizePath(`${baseDirectory}${relativePath}`);
    }
  }

  return {
    protocol: parsedBase.protocol,
    hostname: parsedBase.hostname,
    authority: parsedBase.authority,
    origin: parsedBase.origin,
    pathname: pathname,
    search: search,
    hash: hash
  };
}

function parseAbsoluteWebUrl(value: string): ParsedWebUrl | undefined {
  const schemeEnd: number = value.indexOf('://');
  if (schemeEnd <= 0) {
    return undefined;
  }
  const protocolName: string = value.slice(0, schemeEnd).toLowerCase();
  if (protocolName !== 'http' && protocolName !== 'https') {
    return undefined;
  }

  const protocol: string = `${protocolName}:`;
  const authorityStart: number = schemeEnd + 3;
  const authorityEnd: number = firstPositiveIndexAfter(
    value.indexOf('/', authorityStart), value.indexOf('?', authorityStart),
    value.indexOf('#', authorityStart), value.length
  );
  const rawAuthority: string = value.slice(authorityStart, authorityEnd);
  if (rawAuthority.length === 0 || containsWhitespace(rawAuthority) || rawAuthority.indexOf('@') >= 0) {
    return undefined;
  }

  const hostAndPort: string[] | undefined = splitHostAndPort(rawAuthority);
  if (hostAndPort === undefined || !validHostname(hostAndPort[0])) {
    return undefined;
  }
  const hostname: string = hostAndPort[0].toLowerCase();
  let port: string = hostAndPort[1];
  if (port.length > 0 && !validPort(port)) {
    return undefined;
  }
  if ((protocolName === 'http' && port === '80') || (protocolName === 'https' && port === '443')) {
    port = '';
  }
  const authority: string = port.length > 0 ? `${hostname}:${port}` : hostname;
  const origin: string = `${protocol}//${authority}`;
  const remainder: string = value.slice(authorityEnd);
  const parts: string[] = splitSearchAndHash(remainder);
  let pathname: string = parts[0];
  if (pathname.length === 0) {
    pathname = '/';
  } else if (!pathname.startsWith('/')) {
    return undefined;
  }
  pathname = normalizePath(pathname);

  return {
    protocol: protocol,
    hostname: hostname,
    authority: authority,
    origin: origin,
    pathname: pathname,
    search: parts[1],
    hash: parts[2]
  };
}

function splitHostAndPort(authority: string): string[] | undefined {
  if (authority.startsWith('[')) {
    const closeBracket: number = authority.indexOf(']');
    if (closeBracket <= 1) {
      return undefined;
    }
    const hostname: string = authority.slice(0, closeBracket + 1);
    const suffix: string = authority.slice(closeBracket + 1);
    if (suffix.length === 0) {
      return [hostname, ''];
    }
    if (!suffix.startsWith(':')) {
      return undefined;
    }
    return [hostname, suffix.slice(1)];
  }

  const colonIndex: number = authority.lastIndexOf(':');
  if (colonIndex < 0) {
    return [authority, ''];
  }
  if (authority.indexOf(':') !== colonIndex) {
    return undefined;
  }
  return [authority.slice(0, colonIndex), authority.slice(colonIndex + 1)];
}

function validHostname(hostname: string): boolean {
  if (hostname.length === 0) {
    return false;
  }
  if (hostname.startsWith('[') && hostname.endsWith(']')) {
    return hostname.length > 2;
  }
  for (let index: number = 0; index < hostname.length; index += 1) {
    const character: string = hostname.charAt(index);
    const isAsciiLetter: boolean = (character >= 'a' && character <= 'z') ||
      (character >= 'A' && character <= 'Z');
    const isDigit: boolean = character >= '0' && character <= '9';
    if (!isAsciiLetter && !isDigit && character !== '.' && character !== '-' && character !== '_') {
      return false;
    }
  }
  return true;
}

function validPort(port: string): boolean {
  if (port.length === 0) {
    return false;
  }
  let value: number = 0;
  for (let index: number = 0; index < port.length; index += 1) {
    const digit: number = port.charCodeAt(index) - 48;
    if (digit < 0 || digit > 9) {
      return false;
    }
    value = value * 10 + digit;
  }
  return value > 0 && value <= 65535;
}

function splitSearchAndHash(value: string): string[] {
  let beforeHash: string = value;
  let hash: string = '';
  const hashIndex: number = beforeHash.indexOf('#');
  if (hashIndex >= 0) {
    hash = beforeHash.slice(hashIndex);
    beforeHash = beforeHash.slice(0, hashIndex);
  }

  let pathname: string = beforeHash;
  let search: string = '';
  const queryIndex: number = beforeHash.indexOf('?');
  if (queryIndex >= 0) {
    search = beforeHash.slice(queryIndex);
    pathname = beforeHash.slice(0, queryIndex);
  }
  return [pathname, search, hash];
}

function normalizePath(pathname: string): string {
  const segments: string[] = pathname.split('/');
  const normalized: string[] = [];
  for (let index: number = 0; index < segments.length; index += 1) {
    const segment: string = segments[index];
    if (segment === '.') {
      if (index === segments.length - 1) {
        normalized.push('');
      }
      continue;
    }
    if (segment === '..') {
      if (normalized.length > 1) {
        normalized.pop();
      }
      if (index === segments.length - 1) {
        normalized.push('');
      }
      continue;
    }
    normalized.push(segment);
  }
  const result: string = normalized.join('/');
  return result.length === 0 ? '/' : result;
}

function serializeWebUrl(value: ParsedWebUrl): string {
  return `${value.origin}${value.pathname}${value.search}${value.hash}`;
}

function containsWhitespace(value: string): boolean {
  for (let index: number = 0; index < value.length; index += 1) {
    if (isWhitespace(value.charAt(index))) {
      return true;
    }
  }
  return false;
}

function firstPositiveIndex(first: number, second: number, third: number): number {
  let result: number = -1;
  if (first >= 0) {
    result = first;
  }
  if (second >= 0 && (result < 0 || second < result)) {
    result = second;
  }
  if (third >= 0 && (result < 0 || third < result)) {
    result = third;
  }
  return result;
}

function firstPositiveIndexAfter(first: number, second: number, third: number, fallback: number): number {
  let result: number = fallback;
  if (first >= 0 && first < result) {
    result = first;
  }
  if (second >= 0 && second < result) {
    result = second;
  }
  if (third >= 0 && third < result) {
    result = third;
  }
  return result;
}

function findTagEnd(html: string, start: number): number {
  let quote: string = '';
  for (let index: number = start; index < html.length; index += 1) {
    const character: string = html.charAt(index);
    if (quote.length > 0) {
      if (character === quote) {
        quote = '';
      }
    } else if (character === '"' || character === "'") {
      quote = character;
    } else if (character === '>') {
      return index;
    }
  }
  return -1;
}

function parseAttributes(html: string, start: number, end: number): Map<string, string> {
  const attributes: Map<string, string> = new Map();
  let cursor: number = start;
  while (cursor < end) {
    while (cursor < end && (isWhitespace(html.charAt(cursor)) || html.charAt(cursor) === '/')) {
      cursor += 1;
    }
    if (cursor >= end) {
      break;
    }

    const nameStart: number = cursor;
    while (cursor < end && !isWhitespace(html.charAt(cursor)) && html.charAt(cursor) !== '=' &&
      html.charAt(cursor) !== '/' && html.charAt(cursor) !== '>') {
      cursor += 1;
    }
    if (cursor === nameStart) {
      cursor += 1;
      continue;
    }

    const name: string = html.slice(nameStart, cursor).toLowerCase();
    while (cursor < end && isWhitespace(html.charAt(cursor))) {
      cursor += 1;
    }

    let value: string = '';
    if (cursor < end && html.charAt(cursor) === '=') {
      cursor += 1;
      while (cursor < end && isWhitespace(html.charAt(cursor))) {
        cursor += 1;
      }
      if (cursor < end && (html.charAt(cursor) === '"' || html.charAt(cursor) === "'")) {
        const quote: string = html.charAt(cursor);
        cursor += 1;
        const valueStart: number = cursor;
        while (cursor < end && html.charAt(cursor) !== quote) {
          cursor += 1;
        }
        value = html.slice(valueStart, cursor);
        if (cursor < end) {
          cursor += 1;
        }
      } else {
        const valueStart: number = cursor;
        while (cursor < end && !isWhitespace(html.charAt(cursor)) && html.charAt(cursor) !== '>') {
          cursor += 1;
        }
        value = html.slice(valueStart, cursor);
      }
    }

    if (!attributes.has(name)) {
      attributes.set(name, value);
    }
  }
  return attributes;
}

function containsWord(value: string, expected: string): boolean {
  const normalized: string = value.toLowerCase();
  let cursor: number = 0;
  while (cursor < normalized.length) {
    while (cursor < normalized.length && isWhitespace(normalized.charAt(cursor))) {
      cursor += 1;
    }
    const start: number = cursor;
    while (cursor < normalized.length && !isWhitespace(normalized.charAt(cursor))) {
      cursor += 1;
    }
    if (normalized.slice(start, cursor) === expected) {
      return true;
    }
  }
  return false;
}

function decodeCommonHtmlEntities(value: string): string {
  return value.split('&amp;').join('&')
    .split('&quot;').join('"')
    .split('&#39;').join("'")
    .split('&lt;').join('<')
    .split('&gt;').join('>');
}

function isTagBoundary(character: string): boolean {
  return isWhitespace(character) || character === '/' || character === '>';
}

function isWhitespace(character: string): boolean {
  return character === ' ' || character === '\t' || character === '\n' || character === '\r' ||
    character === '\f';
}
