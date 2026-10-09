export type ReaderModeTextSize = 'small' | 'standard' | 'large';
export type ReaderModeTheme = 'white' | 'sepia' | 'gray' | 'dark';

export interface ReaderModePreferences {
  textSize: ReaderModeTextSize;
  theme: ReaderModeTheme;
}

export interface ReaderModePageEligibility {
  eligible: boolean;
  normalizedUrl: string;
  host: string;
  reason: string;
}

export type ReaderModeStatus = 'available' | 'active' | 'unavailable' | 'error';

export interface ReaderModeResult {
  status: ReaderModeStatus;
  available: boolean;
  active: boolean;
  reason?: string;
}

export interface ReaderModeSettings {
  preferences: ReaderModePreferences;
  autoReaderHosts: Array<string>;
}

export const DEFAULT_READER_MODE_PREFERENCES: ReaderModePreferences = {
  textSize: 'standard',
  theme: 'white'
};

export const DEFAULT_READER_MODE_SETTINGS: ReaderModeSettings = {
  preferences: DEFAULT_READER_MODE_PREFERENCES,
  autoReaderHosts: []
};

const VALID_HOST_PATTERN: RegExp = /^(?:\[[0-9a-f:.]+\]|[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?)(?::\d{1,5})?$/i;
const URL_PATTERN: RegExp = /^(https?):\/\/([^/?#]+)(?:[/?#][^\s]*)?$/i;
const CONTROL_OR_SPACE: RegExp = /[\u0000-\u0020\u007f]/;

function isTextSize(value: Object | undefined): boolean {
  return value === 'small' || value === 'standard' || value === 'large';
}

function isTheme(value: Object | undefined): boolean {
  return value === 'white' || value === 'sepia' || value === 'gray' || value === 'dark';
}

function normalizeAuthority(authorityValue: string, scheme: string): string | undefined {
  if (authorityValue.length === 0 || authorityValue.length > 259 ||
      /[\/?#\\]/.test(authorityValue) || CONTROL_OR_SPACE.test(authorityValue) ||
      authorityValue.includes('@')) {
    return undefined;
  }
  let authority: string = authorityValue.toLowerCase();
  if (!VALID_HOST_PATTERN.test(authority)) {
    return undefined;
  }

  let host: string = authority;
  let portText: string | undefined;
  if (authority.startsWith('[')) {
    const closeBracket: number = authority.indexOf(']');
    if (closeBracket < 0) {
      return undefined;
    }
    host = authority.slice(0, closeBracket + 1);
    if (authority.length > closeBracket + 1) {
      portText = authority.slice(closeBracket + 2);
    }
  } else {
    const colonIndex: number = authority.lastIndexOf(':');
    if (colonIndex >= 0) {
      host = authority.slice(0, colonIndex);
      portText = authority.slice(colonIndex + 1);
    }
  }

  if (host.length === 0 || host.length > 253) {
    return undefined;
  }
  if (!host.startsWith('[')) {
    if (host.endsWith('.')) {
      host = host.slice(0, -1);
    }
    const labels: Array<string> = host.split('.');
    for (const label of labels) {
      if (label.length === 0 || label.length > 63 || label.startsWith('-') || label.endsWith('-') ||
          !/^[a-z0-9-]+$/.test(label)) {
        return undefined;
      }
    }
  }
  if (host.length === 0 || host.length > 253) {
    return undefined;
  }

  if (portText !== undefined) {
    const port: number = Number(portText);
    if (!/^\d{1,5}$/.test(portText) || !Number.isFinite(port) || port < 1 || port > 65535) {
      return undefined;
    }
    if (!((scheme === 'https' && port === 443) || (scheme === 'http' && port === 80))) {
      return host + ':' + port;
    }
  }
  return host;
}

export function normalizeReaderModePreferences(value: Object | undefined): ReaderModePreferences {
  if (value === undefined || value === null || typeof value !== 'object') {
    return { textSize: 'standard', theme: 'white' };
  }
  const record: Record<string, Object> = value as Record<string, Object>;
  const textSize: Object | undefined = record['textSize'];
  const theme: Object | undefined = record['theme'];
  return {
    textSize: isTextSize(textSize) ? textSize as ReaderModeTextSize : 'standard',
    theme: isTheme(theme) ? theme as ReaderModeTheme : 'white'
  };
}

export function readerModePageEligibility(value: string): ReaderModePageEligibility {
  if (typeof value !== 'string' || value.length === 0 || value.length > 4096 || CONTROL_OR_SPACE.test(value)) {
    return { eligible: false, normalizedUrl: '', host: '', reason: 'invalid-url' };
  }
  const match: RegExpMatchArray | null = value.match(URL_PATTERN);
  if (match === null) {
    return { eligible: false, normalizedUrl: '', host: '', reason: 'unsupported-url' };
  }
  const scheme: string = match[1].toLowerCase();
  const host: string | undefined = normalizeAuthority(match[2], scheme);
  if (host === undefined) {
    return {
      eligible: false,
      normalizedUrl: '',
      host: '',
      reason: match[2].includes('@') ? 'credentials-not-allowed' : 'invalid-host'
    };
  }
  const normalizedUrl: string = scheme + '://' + match[2].toLowerCase() + value.slice(match[0].indexOf(match[2]) + match[2].length);
  return { eligible: true, normalizedUrl, host, reason: 'eligible' };
}

export function readerHostForUrl(url: string): string | undefined {
  const result: ReaderModePageEligibility = readerModePageEligibility(url);
  return result.eligible ? result.host : undefined;
}

export function normalizeAutoReaderHosts(value: Array<string> | undefined): Array<string> {
  if (value === undefined || !Array.isArray(value)) {
    return [];
  }
  const result: Array<string> = [];
  for (const item of value) {
    if (result.length >= 32) {
      break;
    }
    if (typeof item !== 'string' || item.length === 0 || item.length > 259 ||
        /[\/?#\\]/.test(item) || CONTROL_OR_SPACE.test(item) || item.includes('@')) {
      continue;
    }
    const host: string | undefined = normalizeAuthority(item, 'https');
    if (host !== undefined && !result.includes(host)) {
      result.push(host);
    }
  }
  return result;
}

export function autoReaderEnabledFor(url: string, hosts: Array<string>): boolean {
  const host: string | undefined = readerHostForUrl(url);
  return host !== undefined && normalizeAutoReaderHosts(hosts).includes(host);
}

export function setAutoReaderHost(
  hosts: Array<string>,
  url: string,
  enabled: boolean,
  isPrivate: boolean
): Array<string> {
  const normalized: Array<string> = normalizeAutoReaderHosts(hosts);
  if (isPrivate) {
    return normalized;
  }
  const host: string | undefined = readerHostForUrl(url);
  if (host === undefined) {
    return normalized;
  }
  const existing: boolean = normalized.includes(host);
  if (enabled && !existing && normalized.length < 32) {
    normalized.push(host);
  } else if (!enabled && existing) {
    return normalized.filter((item: string) => item !== host);
  }
  return normalized;
}

export function isReadableArticleCandidate(title: string, textLength: number, paragraphCount: number): boolean {
  return title.trim().length > 0 && Number.isFinite(textLength) && textLength >= 180 &&
    Number.isFinite(paragraphCount) && paragraphCount >= 2;
}

export function normalizeReaderModeSettings(value: Object | undefined): ReaderModeSettings {
  if (value === undefined || value === null || typeof value !== 'object') {
    return {
      preferences: { textSize: 'standard', theme: 'white' },
      autoReaderHosts: []
    };
  }
  const record: Record<string, Object> = value as Record<string, Object>;
  const rawHosts: Object | undefined = record['autoReaderHosts'];
  const stringHosts: Array<string> = [];
  if (Array.isArray(rawHosts)) {
    const rawHostItems: Object[] = rawHosts as Object[];
    for (const item of rawHostItems) {
      if (typeof item === 'string') {
        stringHosts.push(item as string);
      }
    }
  }
  return {
    preferences: normalizeReaderModePreferences(record['preferences']),
    autoReaderHosts: normalizeAutoReaderHosts(stringHosts)
  };
}
