/** A locally persisted favicon belonging to one navigable page URL. */
export interface PageIconRecord {
  url: string;
  localPath: string;
  updatedAt: number;
}

export function validPageIconRecord(record: PageIconRecord): boolean {
  return record !== undefined && typeof record.url === 'string' && record.url.trim().length > 0 &&
    typeof record.localPath === 'string' && record.localPath.trim().length > 0 &&
    typeof record.updatedAt === 'number' && Number.isFinite(record.updatedAt);
}

export function copyPageIconRecord(record: PageIconRecord): PageIconRecord {
  return {
    url: record.url,
    localPath: record.localPath,
    updatedAt: record.updatedAt
  };
}

/** Resolve only a persisted local path. The caller renders its native fallback when absent. */
export function pageIconPathForUrl(records: PageIconRecord[], url: string): string | undefined {
  const normalizedUrl: string = url.trim();
  if (normalizedUrl.length === 0) {
    return undefined;
  }
  const exactRecord: PageIconRecord | undefined = records.find((item: PageIconRecord) =>
    validPageIconRecord(item) && item.url.trim() === normalizedUrl);
  if (exactRecord !== undefined) {
    return exactRecord.localPath.trim();
  }
  const siteKey: string = pageIconSiteKey(normalizedUrl);
  if (siteKey.length === 0) {
    return undefined;
  }
  const siteRecord: PageIconRecord | undefined = records.find((item: PageIconRecord) =>
    validPageIconRecord(item) && pageIconSiteKey(item.url.trim()) === siteKey);
  return siteRecord?.localPath.trim();
}

/** Favicons belong to the site, so a query/path variant can reuse its icon. */
function pageIconSiteKey(url: string): string {
  const schemeEnd: number = url.indexOf('://');
  if (schemeEnd <= 0) {
    return '';
  }
  const authorityStart: number = schemeEnd + 3;
  const pathStart: number = url.indexOf('/', authorityStart);
  const queryStart: number = url.indexOf('?', authorityStart);
  const fragmentStart: number = url.indexOf('#', authorityStart);
  let authorityEnd: number = url.length;
  if (pathStart >= 0) {
    authorityEnd = Math.min(authorityEnd, pathStart);
  }
  if (queryStart >= 0) {
    authorityEnd = Math.min(authorityEnd, queryStart);
  }
  if (fragmentStart >= 0) {
    authorityEnd = Math.min(authorityEnd, fragmentStart);
  }
  const authority: string = url.slice(authorityStart, authorityEnd).trim().toLowerCase();
  return authority.length === 0 ? '' : `${url.slice(0, schemeEnd).toLowerCase()}://${authority}`;
}

/** Replace the URL's cache entry while keeping the collection bounded. */
export function upsertPageIconRecord(
  records: PageIconRecord[],
  incoming: PageIconRecord,
  maxRecords: number = 256
): PageIconRecord[] {
  if (!validPageIconRecord(incoming)) {
    return records.filter((item: PageIconRecord) => validPageIconRecord(item)).map(copyPageIconRecord);
  }
  const normalized: PageIconRecord = {
    url: incoming.url.trim(),
    localPath: incoming.localPath.trim(),
    updatedAt: incoming.updatedAt
  };
  const next: PageIconRecord[] = records
    .filter((item: PageIconRecord) => validPageIconRecord(item) && item.url.trim() !== normalized.url)
    .map(copyPageIconRecord);
  next.push(normalized);
  const limit: number = Math.max(1, Math.floor(maxRecords));
  return next.length > limit ? next.slice(next.length - limit) : next;
}
