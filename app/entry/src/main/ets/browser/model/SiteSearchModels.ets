import { validateBrowserUrl } from './BrowserTypes';

export interface SiteSearchParameter {
  name: string;
  value: string;
}

export interface SiteSearchFormSnapshot {
  pageUrl: string;
  pageTitle: string;
  actionUrl: string;
  method: string;
  searchFieldName: string;
  searchFieldType: string;
  searchSemantic: boolean;
  hasPasswordField: boolean;
  hasSensitiveField: boolean;
  hiddenFields: SiteSearchParameter[];
}

export interface SiteSearchTemplate {
  id: string;
  siteName: string;
  origin: string;
  path: string;
  queryFieldName: string;
  fixedFields: SiteSearchParameter[];
  lastUsedAt: number;
}

export interface SiteSearchSuggestion {
  templateId: string;
  siteName: string;
  query: string;
  url: string;
}

interface HttpUrlParts {
  origin: string;
  host: string;
  path: string;
  query: string;
}

const MAX_SITE_SEARCH_TEMPLATES: number = 32;
const MAX_FIXED_FIELDS: number = 8;
const MAX_QUERY_FIELDS: number = 24;
const MAX_URL_LENGTH: number = 2048;
const MAX_QUERY_LENGTH: number = 160;
const SENSITIVE_FIELD_PATTERN: RegExp = /(pass(word|wd)?|credential|auth|token|csrf|xsrf|session|cookie|secret|login|email|phone|mobile|account|user(name)?|nonce|verification|captcha)/i;

function httpUrlPartsFor(value: string): HttpUrlParts | undefined {
  const normalized: string = value.trim();
  const match: RegExpMatchArray | null = normalized.match(/^(https?):\/\/([^/?#]+)([^?#]*)(?:\?([^#]*))?(?:#.*)?$/i);
  if (match === null || normalized.length > MAX_URL_LENGTH || /\s/.test(normalized) || /[\u0000-\u001F\u007F\\]/.test(normalized) || !validateBrowserUrl(normalized).valid) {
    return undefined;
  }
  const authority: string = match[2].toLowerCase();
  if (authority.length === 0 || authority.includes('@')) {
    return undefined;
  }
  const scheme: string = match[1].toLowerCase();
  const normalizedAuthority: string = scheme === 'https' && authority.endsWith(':443') ? authority.slice(0, -4) : scheme === 'http' && authority.endsWith(':80') ? authority.slice(0, -3) : authority;
  const origin: string = `${scheme}://${normalizedAuthority}`;
  return { origin, host: authority, path: match[3].length > 0 ? match[3] : '/', query: match[4] ?? '' };
}

function decodedComponent(value: string): string {
  try {
    return decodeURIComponent(value.replace(/\+/g, ' '));
  } catch (_error) {
    return value.replace(/\+/g, ' ');
  }
}

function safeFieldName(value: string): boolean {
  return /^[A-Za-z][A-Za-z0-9_.-]{0,39}$/.test(value) && !SENSITIVE_FIELD_PATTERN.test(value);
}

function queryPairs(query: string): SiteSearchParameter[] | undefined {
  if (query.length > MAX_URL_LENGTH) {
    return undefined;
  }
  if (query.length === 0) {
    return [];
  }
  const fields: string[] = query.split('&');
  if (fields.length > MAX_QUERY_FIELDS) {
    return undefined;
  }
  const pairs: SiteSearchParameter[] = [];
  for (let index: number = 0; index < fields.length; index += 1) {
    const separator: number = fields[index].indexOf('=');
    const name: string = decodedComponent(separator < 0 ? fields[index] : fields[index].slice(0, separator));
    const value: string = decodedComponent(separator < 0 ? '' : fields[index].slice(separator + 1));
    if (!safeFieldName(name) || name.length > 40 || value.length > 256) {
      return undefined;
    }
    pairs.push({ name, value });
  }
  return pairs;
}

function copySafeFixedFields(fields: SiteSearchParameter[], queryFieldName: string): SiteSearchParameter[] | undefined {
  if (!Array.isArray(fields)) { return []; }
  if (fields.length > MAX_FIXED_FIELDS) { return undefined; }
  const copied: SiteSearchParameter[] = [];
  for (let index: number = 0; index < fields.length; index += 1) {
    const field: SiteSearchParameter = fields[index];
    if (field === undefined || field === null || typeof field !== 'object') { continue; }
    const name: string = typeof field.name === 'string' ? field.name.trim() : '';
    const value: string = typeof field.value === 'string' ? field.value : '';
    if (!safeFieldName(name) || name.toLowerCase() === queryFieldName.toLowerCase() || value.length > 128) {
      return undefined;
    }
    copied.push({ name, value });
  }
  return copied;
}

function hostDisplayName(host: string): string {
  const withoutPort: string = host.replace(/:\d+$/, '');
  const labels: string[] = withoutPort.split('.').filter((part: string) => part.length > 0);
  if (labels.length === 4 && labels.every((part: string) => /^\d{1,3}$/.test(part))) {
    return withoutPort;
  }
  const filtered: string[] = labels.filter((part: string) =>
    part !== 'www' && part !== 'm' && part !== 'mobile' && part !== 'search');
  return filtered.length >= 2 ? filtered[filtered.length - 2] : (filtered[0] ?? withoutPort);
}

function templateIdentity(origin: string, path: string, queryFieldName: string, fixed: SiteSearchParameter[]): string {
  const fixedPart: string = fixed
    .map((field: SiteSearchParameter) => `${field.name}=${field.value}`)
    .sort()
    .join('&');
  return `${origin}${path}?${queryFieldName}|${fixedPart}`;
}

export function siteSearchTemplateFromForm(
  snapshot: SiteSearchFormSnapshot,
  now: number
): SiteSearchTemplate | undefined {
  if (snapshot === undefined || snapshot === null || typeof snapshot !== 'object' || typeof snapshot.method !== 'string' || typeof snapshot.pageUrl !== 'string' || typeof snapshot.actionUrl !== 'string' || typeof snapshot.searchFieldName !== 'string' || typeof snapshot.searchFieldType !== 'string' || snapshot.method.trim().toLowerCase() !== 'get' || snapshot.searchSemantic !== true || snapshot.hasPasswordField !== false || snapshot.hasSensitiveField !== false) {
    return undefined;
  }
  const page: HttpUrlParts | undefined = httpUrlPartsFor(snapshot.pageUrl);
  const action: HttpUrlParts | undefined = httpUrlPartsFor(snapshot.actionUrl);
  const queryFieldName: string = snapshot.searchFieldName.trim();
  if (page === undefined || action === undefined || page.origin !== action.origin ||
    !safeFieldName(queryFieldName) || queryFieldName.length === 0 ||
    snapshot.searchFieldType.toLowerCase() === 'password') {
    return undefined;
  }
  const actionFields: SiteSearchParameter[] | undefined = queryPairs(action.query);
  if (actionFields === undefined || actionFields.some((field: SiteSearchParameter) =>
    field.name.toLowerCase() === queryFieldName.toLowerCase())) {
    return undefined;
  }
  const hidden: SiteSearchParameter[] = Array.isArray(snapshot.hiddenFields) ? snapshot.hiddenFields : [];
  const fixedFields: SiteSearchParameter[] | undefined = copySafeFixedFields(actionFields.concat(hidden), queryFieldName);
  if (fixedFields === undefined) {
    return undefined;
  }
  const host: string = action.host;
  const siteName: string = hostDisplayName(host);
  const safeNow: number = Number.isFinite(now) && now > 0 ? now : 0;
  return {
    id: templateIdentity(action.origin, action.path, queryFieldName, fixedFields),
    siteName,
    origin: action.origin,
    path: action.path,
    queryFieldName,
    fixedFields,
    lastUsedAt: safeNow
  };
}

export function siteSearchTemplateMatchesUrl(template: SiteSearchTemplate, url: string): boolean {
  const parts: HttpUrlParts | undefined = httpUrlPartsFor(url);
  if (parts === undefined || parts.origin !== template.origin || parts.path !== template.path) {
    return false;
  }
  const pairs: SiteSearchParameter[] | undefined = queryPairs(parts.query);
  if (pairs === undefined || pairs.length === 0) {
    return false;
  }
  const queryMatches: SiteSearchParameter[] = pairs.filter((field: SiteSearchParameter) =>
    field.name.toLowerCase() === template.queryFieldName.toLowerCase());
  if (queryMatches.length !== 1 || queryMatches[0].value.trim().length === 0 ||
    queryMatches[0].value.length > MAX_QUERY_LENGTH) {
    return false;
  }
  return template.fixedFields.every((fixed: SiteSearchParameter) => pairs.some(
    (field: SiteSearchParameter) => field.name === fixed.name && field.value === fixed.value
  ));
}

export function siteSearchUrlFor(template: SiteSearchTemplate, query: string): string {
  const normalizedQuery: string = query.trim();
  if (normalizedQuery.length === 0 || normalizedQuery.length > MAX_QUERY_LENGTH) {
    return '';
  }
  const fields: SiteSearchParameter[] = template.fixedFields.slice();
  fields.push({ name: template.queryFieldName, value: normalizedQuery });
  const queryText: string = fields.map((field: SiteSearchParameter) =>
    `${encodeURIComponent(field.name)}=${encodeURIComponent(field.value)}`
  ).join('&');
  const url: string = `${template.origin}${template.path}?${queryText}`;
  return url.length <= MAX_URL_LENGTH ? url : '';
}

function siteAliasesFor(template: SiteSearchTemplate): string[] {
  const host: string = template.origin.replace(/^https?:\/\//i, '').replace(/:\d+$/, '').toLowerCase();
  const labels: string[] = host.split('.').filter((part: string) =>
    part.length > 0 && part !== 'www' && part !== 'm' && part !== 'mobile' && part !== 'search');
  const aliases: string[] = [host];
  const name: string = hostDisplayName(host).toLowerCase();
  aliases.push(name);
  if (labels.length === 4 && labels.every((part: string) => /^\d{1,3}$/.test(part))) {
    aliases.push(labels.join('.'));
  }
  return aliases;
}

export function siteSearchSuggestionForInput(
  input: string,
  templates: SiteSearchTemplate[]
): SiteSearchSuggestion | undefined {
  const value: string = input.trim();
  const separator: number = value.search(/\s/);
  if (separator <= 0) {
    return undefined;
  }
  const alias: string = value.slice(0, separator).toLowerCase();
  const query: string = value.slice(separator).trim();
  if (query.length === 0 || query.length > MAX_QUERY_LENGTH) {
    return undefined;
  }
  const matched: SiteSearchTemplate[] = templates.filter((template: SiteSearchTemplate) =>
    siteAliasesFor(template).some((candidate: string) => candidate === alias));
  if (matched.length === 0) {
    return undefined;
  }
  matched.sort((left: SiteSearchTemplate, right: SiteSearchTemplate) => right.lastUsedAt - left.lastUsedAt);
  const selected: SiteSearchTemplate = matched[0];
  const url: string = siteSearchUrlFor(selected, query);
  return url.length === 0 ? undefined : {
    templateId: selected.id,
    siteName: selected.siteName,
    query,
    url
  };
}

export function normalizeSiteSearchTemplates(value: Object | undefined): SiteSearchTemplate[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const parsed: SiteSearchTemplate[] = value as SiteSearchTemplate[];
  const unique: Map<string, SiteSearchTemplate> = new Map();
  parsed.forEach((candidate: SiteSearchTemplate) => {
    if (candidate === undefined || candidate === null || typeof candidate !== 'object' || typeof candidate.origin !== 'string' ||
      typeof candidate.path !== 'string' || typeof candidate.queryFieldName !== 'string') {
      return;
    }
    const pageUrl: string = `${candidate.origin}/`;
    const actionUrl: string = `${candidate.origin}${candidate.path}`;
    const normalized: SiteSearchTemplate | undefined = siteSearchTemplateFromForm({
      pageUrl,
      pageTitle: typeof candidate.siteName === 'string' ? candidate.siteName : '',
      actionUrl,
      method: 'get',
      searchFieldName: candidate.queryFieldName,
      searchFieldType: 'search',
      searchSemantic: true,
      hasPasswordField: false,
      hasSensitiveField: false,
      hiddenFields: Array.isArray(candidate.fixedFields) ? candidate.fixedFields : []
    }, candidate.lastUsedAt);
    if (normalized !== undefined) {
      normalized.lastUsedAt = Number.isFinite(candidate.lastUsedAt) && candidate.lastUsedAt > 0
        ? candidate.lastUsedAt
        : 0;
      unique.set(normalized.id, normalized);
    }
  });
  return Array.from(unique.values())
    .sort((left: SiteSearchTemplate, right: SiteSearchTemplate) => right.lastUsedAt - left.lastUsedAt)
    .slice(0, MAX_SITE_SEARCH_TEMPLATES);
}

export function upsertSiteSearchTemplate(
  templates: SiteSearchTemplate[],
  template: SiteSearchTemplate
): SiteSearchTemplate[] {
  const normalized: SiteSearchTemplate[] = normalizeSiteSearchTemplates(templates);
  if (!Number.isFinite(template.lastUsedAt) || !siteSearchTemplateMatchesUrl(
    template, siteSearchUrlFor(template, 'validation-query')
  )) {
    return normalized;
  }
  const next: SiteSearchTemplate[] = normalized.filter((item: SiteSearchTemplate) => item.id !== template.id);
  next.unshift({
    id: template.id,
    siteName: template.siteName,
    origin: template.origin,
    path: template.path,
    queryFieldName: template.queryFieldName,
    fixedFields: template.fixedFields.map((field: SiteSearchParameter): SiteSearchParameter => ({ name: field.name, value: field.value })),
    lastUsedAt: template.lastUsedAt
  });
  return next.slice(0, MAX_SITE_SEARCH_TEMPLATES);
}