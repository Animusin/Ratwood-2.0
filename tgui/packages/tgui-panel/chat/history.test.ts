import { expect, it } from 'bun:test';

import { decodeChatHistory, encodeChatHistory } from './history';

const makeMessage = (text: string, createdAt = 1) => ({
  type: 'localchat',
  text,
  html: `<span>${text}</span>`,
  times: 2,
  createdAt,
});

it('loads chat saved in the original array format', async () => {
  const saved = [makeMessage('Old chat')];
  expect(await decodeChatHistory(saved)).toEqual(saved);
  expect(await decodeChatHistory(undefined)).toBeUndefined();
});

it('round-trips an empty history', async () => {
  expect(await decodeChatHistory(await encodeChatHistory([]))).toEqual([]);
});

it.skipIf(
  typeof CompressionStream === 'undefined' ||
    typeof DecompressionStream === 'undefined' ||
    typeof TextEncoderStream === 'undefined',
)('round-trips multiple batches and base64 chunks in order', async () => {
  let seed = 7;
  const alphabet =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  const messages = Array.from({ length: 100 }, (_, index) => {
    const random = Array.from({ length: 1024 }, () => {
      seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
      return alphabet[(seed >>> 16) % alphabet.length];
    }).join('');
    return makeMessage(`Сообщение 🐎 ${index}: ${random}`, index);
  });

  const encoded = await encodeChatHistory(messages);
  expect(typeof encoded).toBe('string');
  expect(encoded.length).toBeGreaterThan(32 * 1024);
  expect(await decodeChatHistory(encoded)).toEqual(messages);
});
