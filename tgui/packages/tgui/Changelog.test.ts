import { readFileSync } from 'node:fs';

import { expect, test } from 'bun:test';
import yaml from 'js-yaml';

import { mergeChangelog } from './interfaces/Changelog/merge';

const entry = {
  rscadd: 'Для администрации - добавлено удобное меню выдача заклинаний.',
};
const local = { '2026-09-29': { VasiliUnknown: [entry] } };

test('keeps local entries when the upstream monthly file is replaced', () => {
  const before = JSON.stringify(local);
  const upstream = {
    '2026-09-30': { Upstream: [{ bugfix: 'New upstream change' }] },
  };
  const merged = mergeChangelog([upstream, local]);
  expect(merged['2026-09-29'].VasiliUnknown).toEqual([entry]);
  expect(merged['2026-09-30']).toEqual(upstream['2026-09-30']);
  expect(Object.keys(merged)).toEqual(['2026-09-29', '2026-09-30']);
  expect(JSON.stringify(local)).toBe(before);
});

test('retains both authors and distinct changes for the same date', () => {
  const upstream = {
    '2026-09-29': {
      VasiliUnknown: [{ bugfix: 'Another change' }],
      Upstream: [{ rscadd: 'An upstream feature' }],
    },
  };
  const merged = mergeChangelog([upstream, local]);
  expect(merged['2026-09-29'].VasiliUnknown).toEqual([
    { bugfix: 'Another change' },
    entry,
  ]);
  expect(merged['2026-09-29'].Upstream).toEqual(
    upstream['2026-09-29'].Upstream,
  );
});

test('shows identical upstream and local entries only once', () => {
  expect(mergeChangelog([local, local])).toEqual(local);
});

test('supports local-only months and empty archives', () => {
  expect(mergeChangelog([null, {}, local])).toEqual(local);
  expect(mergeChangelog([])).toEqual({});
});

test('loads the real separate entry with its fixed date, wording and green-check type', () => {
  const load = (path: string) =>
    yaml.load(readFileSync(new URL(path, import.meta.url), 'utf8'), {
      schema: yaml.CORE_SCHEMA,
    }) as Record<string, Record<string, Record<string, string>[]>>;
  const upstream = load('../../../html/changelogs/archive/2026-09.yml');
  const persistent = load('../../../html/changelogs/local/2026-09.yml');
  expect(persistent).toEqual(local);
  expect(upstream['2026-09-29']?.VasiliUnknown).toBeUndefined();
  expect(
    mergeChangelog([upstream, persistent])['2026-09-29'].VasiliUnknown,
  ).toEqual([entry]);
});
