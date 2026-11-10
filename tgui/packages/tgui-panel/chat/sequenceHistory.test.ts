import { expect, it } from 'bun:test';

import { createSequenceHistory } from './sequenceHistory';

it('accepts late messages and joins adjacent sequence ranges', () => {
  const accept = createSequenceHistory();
  for (const sequence of [6, 3, 2, 5, 4, 7, 1]) {
    expect(accept(sequence)).toBe(true);
  }
  for (let sequence = 1; sequence <= 7; sequence++) {
    expect(accept(sequence)).toBe(false);
  }
});

it('preserves the sequence across a large gap', () => {
  const accept = createSequenceHistory();
  expect(accept(5)).toBe(true);
  expect(accept(10000)).toBe(true);
  expect(accept(6)).toBe(true);
  expect(accept(10000)).toBe(false);
  expect(accept(5)).toBe(false);
});
