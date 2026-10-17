import { afterEach, beforeAll, expect, mock, test } from 'bun:test';
import { type PropsWithChildren } from 'react';
import { flushSync } from 'react-dom';
import { createRoot, type Root } from 'react-dom/client';

let ListInputModal: typeof import('./interfaces/ListInputModal').ListInputModal;
let root: Root;
let container: HTMLDivElement;
const act = mock(() => {});
const fixture = () => ({
  items: ['UNEMPLOYED, SER!!', 'A SCAVENGER, SER!!'],
  init_value: 'UNEMPLOYED, SER!!',
  message: 'Choose your former occupation.',
  title: 'Levy - Background',
  descriptions: {
    'UNEMPLOYED, SER!!': 'Traits: None.\nFinal Stats: +1 CON.',
    'A SCAVENGER, SER!!': 'Traits: Dodge Expert.\nFinal Stats: -1 CON.',
  } as Record<string, string> | null,
});
let data = fixture();
let dimensions: { width: number; height: number };
beforeAll(async () => {
  mock.module('./backend', () => ({ useBackend: () => ({ data, act }) }));
  const Window = ({
    children,
    width,
    height,
  }: PropsWithChildren<{ width: number; height: number }>) => {
    dimensions = { width, height };
    return <main>{children}</main>;
  };
  Window.Content = ({
    children,
    ...props
  }: PropsWithChildren<{ onKeyDown?: React.KeyboardEventHandler }>) => (
    <div {...props}>{children}</div>
  );
  mock.module('./layouts', () => ({ Window }));
  HTMLElement.prototype.scrollIntoView = () => {};
  ({ ListInputModal } = await import('./interfaces/ListInputModal'));
});
const render = () => {
  act.mockClear();
  container = document.createElement('div');
  document.body.append(container);
  root = createRoot(container);
  flushSync(() => root.render(<ListInputModal />));
};
const button = (label: string) =>
  Array.from(container.querySelectorAll<HTMLElement>('.Button')).find(
    (item) => item.textContent === label,
  )!;
const click = (element: HTMLElement) => flushSync(() => element.click());
afterEach(() => {
  flushSync(() => root.unmount());
  container.remove();
  data = fixture();
});
test('shows the selected background details and submits its exact option', () => {
  render();
  expect(container.textContent).toContain('Traits: None.');
  expect(container.textContent).not.toContain('Traits: Dodge Expert.');
  click(button('A SCAVENGER, SER!!'));
  expect(container.textContent).toContain('Final Stats: -1 CON.');
  expect(container.textContent).not.toContain('Traits: None.');
  click(button('MAKE IT SO'));
  expect(act).toHaveBeenCalledWith('submit', { entry: 'A SCAVENGER, SER!!' });
  expect(dimensions.width).toBe(600);
});
test('keyboard navigation updates details and cancellation sends no selection', () => {
  render();
  flushSync(() =>
    button('UNEMPLOYED, SER!!').dispatchEvent(
      new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }),
    ),
  );
  expect(container.textContent).toContain('Traits: Dodge Expert.');
  click(button('I RESCIND'));
  expect(act).toHaveBeenCalledWith('cancel');
  expect(act).not.toHaveBeenCalledWith('submit', expect.anything());
});
test('ordinary input lists keep their original compact layout', () => {
  data.descriptions = null;
  render();
  expect(dimensions.width).toBe(325);
  expect(container.textContent).not.toContain('Final Stats:');
  click(button('MAKE IT SO'));
  expect(act).toHaveBeenCalledWith('submit', { entry: 'UNEMPLOYED, SER!!' });
});
