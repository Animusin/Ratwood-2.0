import type { serializeMessage } from './model';

type ChatHistory = ReturnType<typeof serializeMessage>[];

const GZIP_PREFIX = 'gzip:';
const MESSAGES_PER_BATCH = 32;
// Each full chunk must be divisible by 3 to avoid intermediate base64 padding.
const BASE64_CHUNK_SIZE = 24 * 1024;

const yieldToBrowser = () =>
  new Promise<void>((resolve) => setTimeout(resolve, 0));

export const encodeChatHistory = async (messages: ChatHistory) => {
  if (
    typeof CompressionStream === 'undefined' ||
    typeof DecompressionStream === 'undefined' ||
    typeof TextEncoderStream === 'undefined'
  ) {
    return messages;
  }

  let offset = 0;
  const json = new ReadableStream<string>({
    start(controller) {
      controller.enqueue('[');
    },
    async pull(controller) {
      if (offset === messages.length) {
        controller.enqueue(']');
        controller.close();
        return;
      }

      // Let the browser handle input and render between batches.
      await yieldToBrowser();
      const batch = messages.slice(offset, offset + MESSAGES_PER_BATCH);
      const separator = offset === 0 ? '' : ',';
      controller.enqueue(separator + JSON.stringify(batch).slice(1, -1));
      offset += batch.length;
    },
  });
  const compressed = json
    .pipeThrough(new TextEncoderStream())
    .pipeThrough(new CompressionStream('gzip'));
  const bytes = new Uint8Array(await new Response(compressed).arrayBuffer());

  let encoded = GZIP_PREFIX;
  for (let offset = 0; offset < bytes.length; offset += BASE64_CHUNK_SIZE) {
    if (offset > 0) {
      await yieldToBrowser();
    }
    const chunk = bytes.subarray(offset, offset + BASE64_CHUNK_SIZE);
    encoded += btoa(String.fromCharCode(...chunk));
  }
  return encoded;
};

export const decodeChatHistory = async (
  stored: unknown,
): Promise<ChatHistory | undefined> => {
  if (Array.isArray(stored)) {
    return stored;
  }
  if (typeof stored !== 'string' || !stored.startsWith(GZIP_PREFIX)) {
    return undefined;
  }

  const binary = atob(stored.slice(GZIP_PREFIX.length));
  const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
  const decompressed = new Blob([bytes])
    .stream()
    .pipeThrough(new DecompressionStream('gzip'));
  const messages = await new Response(decompressed).json();
  return Array.isArray(messages) ? messages : undefined;
};
