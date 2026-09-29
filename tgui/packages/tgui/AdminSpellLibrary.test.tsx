import { afterEach, beforeAll, expect, mock, test } from 'bun:test';
import { type PropsWithChildren } from 'react';
import { flushSync } from 'react-dom';
import { createRoot, type Root } from 'react-dom/client';

let AdminSpellLibrary: typeof import('./interfaces/AdminSpellLibrary').AdminSpellLibrary;
let root: Root;
let container: HTMLDivElement;
const act = mock(() => {});
const fixture = () => ({
  target_name: 'Test Wizard',
  target_key: 'testwizard',
  target_valid: true,
  mindless: false,
  known_spells: { '/spell/heal': true },
  categories: [
    { id: 'attack', name: 'Атака' },
    { id: 'healing', name: 'Лечение' },
  ],
  spells: [
    {
      path: '/spell/fireball',
      name: 'Fireball',
      desc: 'Burn the enemy.',
      category: 'attack',
      icon: 'test-icon',
      cooldown: 20,
      charge_time: 2,
    },
    {
      path: '/spell/heal',
      name: 'Heal',
      desc: 'Restore health.',
      category: 'healing',
      icon: 'test-icon',
      cooldown: 10,
      charge_time: 0,
    },
  ],
});
let data = fixture();

beforeAll(async () => {
  mock.module('./backend', () => ({ useBackend: () => ({ data, act }) }));
  const Window = ({ children }: PropsWithChildren) => <main>{children}</main>;
  Window.Content = ({
    children,
    ...props
  }: PropsWithChildren<{ className?: string }>) => (
    <div {...props}>{children}</div>
  );
  mock.module('./layouts', () => ({ Window }));
  ({ AdminSpellLibrary } = await import('./interfaces/AdminSpellLibrary'));
});
const render = () => {
  act.mockClear();
  container = document.createElement('div');
  document.body.append(container);
  root = createRoot(container);
  flushSync(() => root.render(<AdminSpellLibrary />));
};
const button = (text: string) =>
  Array.from(container.querySelectorAll<HTMLElement>('.Button')).find((item) =>
    item.textContent?.includes(text),
  )!;
const click = (element: HTMLElement) => flushSync(() => element.click());
afterEach(() => {
  flushSync(() => root.unmount());
  container.remove();
  data = fixture();
});

test('shows recipient, icons and descriptions, and grants the exact selected spell', () => {
  render();
  expect(container.textContent).toContain('Test Wizard (testwizard)');
  expect(container.textContent).toContain('Burn the enemy.');
  expect(container.querySelectorAll('.AdminSpellLibrary__icon')).toHaveLength(
    2,
  );
  click(button('Выдать'));
  expect(act).toHaveBeenCalledWith('grant', { path: '/spell/fireball' });
});
test('filters by purpose and prevents giving an already known spell', () => {
  render();
  click(button('Лечение (1)'));
  expect(container.querySelectorAll('article')).toHaveLength(1);
  expect(container.querySelector('article')?.textContent).toContain('Heal');
  click(button('Уже имеется'));
  expect(act).not.toHaveBeenCalled();
});
test('hides known spells and disables grants when the recipient is gone', () => {
  data.target_valid = false;
  render();
  click(button('Скрыть имеющиеся'));
  expect(container.querySelectorAll('article')).toHaveLength(1);
  click(button('Выдать'));
  expect(act).not.toHaveBeenCalled();
  expect(container.textContent).toContain('Откройте выдачу заново');
});
test('searches descriptions as well as names and paths', () => {
  render();
  const input = container.querySelector('input')!;
  flushSync(() => {
    Object.getOwnPropertyDescriptor(
      HTMLInputElement.prototype,
      'value',
    )!.set!.call(input, 'restore');
    input.dispatchEvent(new Event('input', { bubbles: true }));
  });
  expect(container.querySelectorAll('article')).toHaveLength(1);
  expect(container.querySelector('article')?.textContent).toContain('Heal');
});
