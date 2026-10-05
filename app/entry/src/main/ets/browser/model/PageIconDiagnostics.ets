export enum PageIconDiagnosticStage {
  CALLBACK_RECEIVED = 'CALLBACK_RECEIVED',
  CACHE_HIT = 'CACHE_HIT',
  CACHE_MISS = 'CACHE_MISS',
  FALLBACK_START = 'FALLBACK_START',
  PAGE_RESPONSE = 'PAGE_RESPONSE',
  ICON_HOST_SELECTED = 'ICON_HOST_SELECTED',
  ICON_RESPONSE = 'ICON_RESPONSE',
  DECODE = 'DECODE',
  FILE_WRITE = 'FILE_WRITE',
  REPOSITORY_PERSIST = 'REPOSITORY_PERSIST'
}

export enum PageIconFailureCategory {
  INVALID_URL = 'INVALID_URL',
  NETWORK_ERROR = 'NETWORK_ERROR',
  HTTP_STATUS = 'HTTP_STATUS',
  REDIRECT_LIMIT = 'REDIRECT_LIMIT',
  HTTPS_DOWNGRADE = 'HTTPS_DOWNGRADE',
  NO_ICON = 'NO_ICON',
  INVALID_IMAGE = 'INVALID_IMAGE',
  FILE_DIRECTORY_FAILED = 'FILE_DIRECTORY_FAILED',
  FILE_OPEN_FAILED = 'FILE_OPEN_FAILED',
  IMAGE_PACKER_CREATE_FAILED = 'IMAGE_PACKER_CREATE_FAILED',
  IMAGE_PACK_FAILED = 'IMAGE_PACK_FAILED',
  FILE_WRITE_FAILED = 'FILE_WRITE_FAILED',
  REPOSITORY_PERSIST_FAILED = 'REPOSITORY_PERSIST_FAILED'
}

export interface PageIconDiagnosticEvent {
  stage: PageIconDiagnosticStage;
  host: string;
  category?: PageIconFailureCategory;
  errorCode?: number;
}

export type PageIconDiagnosticSink = (event: PageIconDiagnosticEvent) => void;

export class PageIconDiagnostics {
  private readonly sink: PageIconDiagnosticSink;

  constructor(sink?: PageIconDiagnosticSink) {
    this.sink = sink ?? writePageIconDiagnostic;
  }

  record(
    stage: PageIconDiagnosticStage,
    host: string,
    category?: PageIconFailureCategory,
    errorCode?: number
  ): void {
    const safeHost: string = pageIconDiagnosticHostForUrl(host);
    const event: PageIconDiagnosticEvent = { stage: stage, host: safeHost };
    if (category !== undefined) {
      event.category = category;
    }
    if (errorCode !== undefined) {
      event.errorCode = errorCode;
    }
    this.sink(event);
  }
}

/** Strip credentials, ports, paths, query strings, and fragments before logging. */
export function pageIconDiagnosticHostForUrl(value: string): string {
  const normalized: string = value.trim();
  if (normalized.length === 0) {
    return '';
  }

  let candidate: string = normalized;
  let schemeEnd: number = candidate.indexOf('://');
  if (schemeEnd < 0) {
    if (candidate.indexOf(':') >= 0) {
      return '';
    }
    candidate = `https://${candidate}`;
    schemeEnd = candidate.indexOf('://');
  }

  const protocol: string = candidate.slice(0, schemeEnd).toLowerCase();
  if (protocol !== 'http' && protocol !== 'https') {
    return '';
  }
  const authorityStart: number = schemeEnd + 3;
  let authorityEnd: number = candidate.length;
  const slashIndex: number = candidate.indexOf('/', authorityStart);
  const queryIndex: number = candidate.indexOf('?', authorityStart);
  const fragmentIndex: number = candidate.indexOf('#', authorityStart);
  if (slashIndex >= 0 && slashIndex < authorityEnd) {
    authorityEnd = slashIndex;
  }
  if (queryIndex >= 0 && queryIndex < authorityEnd) {
    authorityEnd = queryIndex;
  }
  if (fragmentIndex >= 0 && fragmentIndex < authorityEnd) {
    authorityEnd = fragmentIndex;
  }

  let authority: string = candidate.slice(authorityStart, authorityEnd);
  const atIndex: number = authority.lastIndexOf('@');
  if (atIndex >= 0) {
    authority = authority.slice(atIndex + 1);
  }
  if (authority.startsWith('[')) {
    const closeBracket: number = authority.indexOf(']');
    return closeBracket > 1 ? authority.slice(0, closeBracket + 1).toLowerCase() : '';
  }

  const colonIndex: number = authority.lastIndexOf(':');
  if (colonIndex >= 0) {
    authority = authority.slice(0, colonIndex);
  }
  if (authority.length === 0 || containsWhitespace(authority) || authority.indexOf('/') >= 0) {
    return '';
  }
  return authority.toLowerCase();
}

function writePageIconDiagnostic(event: PageIconDiagnosticEvent): void {
  const category: string = event.category ?? 'NONE';
  const errorCode: string = event.errorCode === undefined ? '' : ` errorCode=${event.errorCode}`;
  console.info(`PageIconFallback stage=${event.stage} host=${event.host} category=${category}${errorCode}`);
}

function containsWhitespace(value: string): boolean {
  for (let index: number = 0; index < value.length; index += 1) {
    const character: string = value.charAt(index);
    if (character === ' ' || character === '\t' || character === '\n' || character === '\r') {
      return true;
    }
  }
  return false;
}
