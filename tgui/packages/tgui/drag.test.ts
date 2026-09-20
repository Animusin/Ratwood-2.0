import { beforeAll, beforeEach, describe, expect, test } from 'bun:test';

const windowUpdates: Record<string, string>[] = [];
let drag: typeof import('./drag');
let storage: typeof import('common/storage').storage;

beforeAll(async () => {
  Object.defineProperty(window, 'devicePixelRatio', {
    value: 2,
    configurable: true,
  });
  Object.defineProperty(window, 'screenLeft', { value: 0, configurable: true });
  Object.defineProperty(window, 'screenTop', { value: 0, configurable: true });
  Object.defineProperty(window.screen, 'availWidth', {
    value: 960,
    configurable: true,
  });
  Object.defineProperty(window.screen, 'availHeight', {
    value: 540,
    configurable: true,
  });
  Object.defineProperty(globalThis, 'Byond', {
    value: {
      windowId: 'geometry-test',
      winset: (_id: string, update: Record<string, string>) => {
        windowUpdates.push(update);
        return Promise.resolve();
      },
      winget: () => Promise.resolve({ x: 0, y: 0 }),
    },
    configurable: true,
  });
  ({ storage } = await import('common/storage'));
  drag = await import('./drag');
  await drag.setupDrag();
});

beforeEach(async () => {
  windowUpdates.length = 0;
  drag.setWindowKey('buildmode-catalog-test');
  await storage.set('buildmode-catalog-test', {
    pos: [260, 140],
    size: [900, 620],
  });
});

describe('remembered window geometry', () => {
  test('restores user size and position without applying display scaling twice', async () => {
    await drag.recallWindowGeometry({
      fancy: true,
      rememberSize: true,
      scale: true,
      size: [400, 300],
    });
    expect(windowUpdates).toContainEqual({ size: '900x620' });
    expect(windowUpdates).toContainEqual({ pos: '260,140' });
  });
  test('leaves the default size behavior of other windows unchanged', async () => {
    await drag.recallWindowGeometry({
      fancy: true,
      scale: true,
      size: [400, 300],
    });
    expect(windowUpdates).toContainEqual({ size: '800x600' });
    expect(windowUpdates).toContainEqual({ pos: '260,140' });
  });
  test('uses the default size for the first opening', async () => {
    await storage.remove('buildmode-catalog-test');
    await drag.recallWindowGeometry({
      fancy: true,
      rememberSize: true,
      scale: true,
      size: [400, 300],
    });
    expect(windowUpdates).toContainEqual({ size: '800x600' });
  });
  test('fits remembered size and position on a smaller monitor', async () => {
    await storage.set('buildmode-catalog-test', {
      pos: [1800, 900],
      size: [4000, 2400],
    });
    await drag.recallWindowGeometry({
      fancy: true,
      rememberSize: true,
      scale: true,
      locked: true,
    });
    expect(windowUpdates).toContainEqual({ size: '1920x1080' });
    expect(windowUpdates).toContainEqual({ pos: '0,0' });
  });
});
