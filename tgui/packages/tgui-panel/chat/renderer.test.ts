import { beforeEach, describe, expect, it } from 'bun:test';

import { MESSAGE_TYPE_UNKNOWN } from './constants';
import { createMainPage, serializeMessage } from './model';
import { chatRenderer } from './renderer';

describe('chat message types', () => {
  beforeEach(() => {
    chatRenderer.loaded = true;
    chatRenderer.rootNode = document.createElement('div');
    chatRenderer.scrollNode = document.createElement('div');
    chatRenderer.scrollTracking = false;
    chatRenderer.page = createMainPage();
    chatRenderer.messages = [];
    chatRenderer.visibleMessages = [];
    chatRenderer.queue = [];
  });

  for (const type of [1, true, {}, [], null, undefined, '']) {
    it(`infers the category for type ${JSON.stringify(type)}`, () => {
      chatRenderer.processBatch(
        [{ type, html: '<span class="say">Hello</span>' }],
        { notifyListeners: false },
      );
      expect(chatRenderer.messages[0].type).toBe('localchat');
      expect(chatRenderer.rootNode.textContent).toBe('Hello');
    });
  }

  it('handles an invalid type in queued history, duplicate messages and rebuilds', () => {
    const payload = { type: 1, text: 'A restored chat message' };
    chatRenderer.loaded = false;
    chatRenderer.processBatch([payload], { prepend: true });
    chatRenderer.onStateLoaded();
    expect(chatRenderer.messages[0].type).toBe(MESSAGE_TYPE_UNKNOWN);
    expect(chatRenderer.rootNode.textContent).toBe(payload.text);

    chatRenderer.processBatch([payload], { notifyListeners: false });
    expect(chatRenderer.messages).toHaveLength(1);
    expect(chatRenderer.messages[0].times).toBe(2);
    const saved = chatRenderer.messages.map(serializeMessage);
    expect(saved[0].type).toBe(MESSAGE_TYPE_UNKNOWN);
    chatRenderer.rootNode.textContent = '';
    chatRenderer.messages = [];
    chatRenderer.visibleMessages = [];
    chatRenderer.processBatch(saved, {
      prepend: true,
      notifyListeners: false,
    });
    chatRenderer.rebuildChat();
    expect(chatRenderer.messages[0].type).toBe(MESSAGE_TYPE_UNKNOWN);
    expect(chatRenderer.messages[0].times).toBe(2);

    // Happy DOM does not implement scrolling into view.
    chatRenderer.messages[0].node.scrollIntoView = () => {};
    const page = createMainPage();
    page.acceptedTypes[MESSAGE_TYPE_UNKNOWN] = false;
    chatRenderer.changePage(page);
    expect(chatRenderer.visibleMessages).toHaveLength(0);
    chatRenderer.changePage(createMainPage());
    expect(chatRenderer.visibleMessages).toHaveLength(1);
  });

  it('preserves explicit types and always displays internal messages', () => {
    chatRenderer.page.acceptedTypes.ooc = false;
    chatRenderer.processBatch(
      [
        { type: 'ooc', text: 'Hidden message' },
        { type: 'internal/reconnected' },
      ],
      { notifyListeners: false },
    );
    expect(chatRenderer.messages.map((message) => message.type)).toEqual([
      'ooc',
      'internal/reconnected',
    ]);
    expect(chatRenderer.visibleMessages).toHaveLength(1);
    expect(chatRenderer.visibleMessages[0].type).toBe('internal/reconnected');
  });
});
