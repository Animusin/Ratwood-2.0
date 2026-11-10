/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import type { Store } from 'common/redux';
import { storage } from 'common/storage';
import DOMPurify from 'dompurify';

import {
  addHighlightSetting,
  importSettings,
  loadSettings,
  removeHighlightSetting,
  updateHighlightSetting,
  updateSettings,
} from '../settings/actions';
import { selectSettings } from '../settings/selectors';
import {
  addChatPage,
  changeChatPage,
  changeScrollTracking,
  clearChat,
  loadChat,
  moveChatPageLeft,
  moveChatPageRight,
  rebuildChat,
  removeChatPage,
  saveChatToDisk,
  toggleAcceptedType,
  updateMessageCount,
} from './actions';
import { MAX_PERSISTED_MESSAGES, MESSAGE_SAVE_INTERVAL } from './constants';
import { decodeChatHistory, encodeChatHistory } from './history';
import { createMessage, serializeMessage } from './model';
import { chatRenderer } from './renderer';
import { selectChat, selectCurrentChatPage } from './selectors';
import { createSequenceHistory } from './sequenceHistory';

// List of blacklisted tags
const FORBID_TAGS = ['a', 'iframe', 'link', 'video'];

const CHAT_HISTORY_KEY = 'chat-messages';
const COMPRESSED_CHAT_HISTORY_KEY = 'chat-messages-gzip';
const MESSAGES_PER_FRAME = 64;

type ChatMessage = { html?: string };

const loadChatHistory = async () => {
  try {
    const compressed = await storage.get(COMPRESSED_CHAT_HISTORY_KEY);
    const history = await decodeChatHistory(compressed);
    if (history) {
      return history;
    }
  } catch (error) {
    console.warn('Failed to load compressed chat history', error);
  }
  return storage.get(CHAT_HISTORY_KEY).then(decodeChatHistory);
};

const loadChatFromStorage = async (
  store: Store,
  restoreHistory: (messages: ChatMessage[]) => void,
) => {
  const [state, messages] = await Promise.all([
    storage.get('chat-state'),
    loadChatHistory(),
  ]);
  // Discard incompatible versions
  if (state && state.version <= 4) {
    store.dispatch(loadChat());
    return;
  }
  if (messages) {
    restoreHistory([
      ...messages,
      createMessage({ type: 'internal/reconnected' }),
    ]);
  }
  store.dispatch(loadChat(state));
};

export const chatMiddleware = (store: Store) => {
  let initialized = false;
  let loaded = false;
  let saving = false;
  let restarting = false;
  let scheduled: number | null = null;
  let scheduledAsFrame = false;
  let historyPending: ChatMessage[] = [];
  const messagesPending: ChatMessage[] = [];
  const acceptSequence = createSequenceHistory();

  const pendingCount = () => historyPending.length + messagesPending.length;

  const flushMessages = (limit = pendingCount()) => {
    if (!loaded || !chatRenderer.isReady()) {
      return;
    }

    if (historyPending.length) {
      const batch = historyPending.splice(0, limit);
      for (const message of batch) {
        if (message.html) {
          message.html = DOMPurify.sanitize(message.html, { FORBID_TAGS });
        }
      }
      chatRenderer.processBatch(batch, { notifyListeners: false });
      limit -= batch.length;
    }

    if (limit > 0 && messagesPending.length) {
      chatRenderer.processBatch(messagesPending.splice(0, limit));
    }
  };

  const scheduleMessages = () => {
    if (!loaded || scheduled !== null || !pendingCount()) {
      return;
    }
    const flushFrame = () => {
      scheduled = null;
      flushMessages(MESSAGES_PER_FRAME);
      scheduleMessages();
    };
    scheduledAsFrame = !document.hidden;
    scheduled = scheduledAsFrame
      ? requestAnimationFrame(flushFrame)
      : window.setTimeout(flushFrame, 16);
  };

  document.addEventListener('visibilitychange', () => {
    if (scheduled !== null) {
      if (scheduledAsFrame) {
        cancelAnimationFrame(scheduled);
      } else {
        clearTimeout(scheduled);
      }
      scheduled = null;
    }
    scheduleMessages();
  });

  const saveChatToStorage = async (immediate = false) => {
    if (
      !loaded ||
      !chatRenderer.isReady() ||
      (!immediate && (saving || restarting || historyPending.length))
    ) {
      return;
    }

    if (immediate) {
      flushMessages();
    }
    const state = selectChat(store.getState());
    const messages = chatRenderer.messages
      .slice(-MAX_PERSISTED_MESSAGES)
      .map(serializeMessage);

    if (immediate) {
      // The server can disconnect this panel before compression completes.
      restarting = true;
    } else {
      saving = true;
    }

    try {
      const history = immediate ? messages : await encodeChatHistory(messages);
      if (!immediate && restarting) {
        return;
      }

      if (typeof history === 'string') {
        await Promise.all([
          storage.set('chat-state', state),
          storage.set(COMPRESSED_CHAT_HISTORY_KEY, history),
        ]);
      } else {
        await Promise.all([
          storage.set('chat-state', state),
          storage.set(CHAT_HISTORY_KEY, history),
        ]);
        // Keep the previous snapshot available until the replacement is stored.
        await storage.remove(COMPRESSED_CHAT_HISTORY_KEY);
      }
    } catch (error) {
      console.warn('Failed to save chat history', error);
    } finally {
      if (!immediate) {
        saving = false;
      }
    }
  };

  chatRenderer.events.on('batchProcessed', (countByType) => {
    // Use this flag to workaround unread messages caused by
    // loading them from storage. Side effect of that, is that
    // message count can not be trusted, only unread count.
    if (loaded) {
      store.dispatch(updateMessageCount(countByType));
    }
  });
  chatRenderer.events.on('scrollTrackingChanged', (scrollTracking) => {
    store.dispatch(changeScrollTracking(scrollTracking));
  });
  return (next) => (action) => {
    const { type, payload } = action;
    const settings = selectSettings(store.getState());
    // Load the chat once settings are loaded
    if (!initialized && settings.initialized) {
      setInterval(() => saveChatToStorage(), MESSAGE_SAVE_INTERVAL);
      initialized = true;
      loadChatFromStorage(store, (history) => {
        historyPending = history;
      });
    }
    if (type === 'chat/message') {
      let payload_obj;
      try {
        payload_obj = JSON.parse(payload);
      } catch (err) {
        return;
      }

      if (payload_obj?.content && acceptSequence(payload_obj.sequence)) {
        messagesPending.push(payload_obj.content);
        scheduleMessages();
      }
      return;
    }
    if (type === loadChat.type) {
      next(action);
      const page = selectCurrentChatPage(store.getState());
      chatRenderer.changePage(page);
      chatRenderer.onStateLoaded();
      loaded = true;
      scheduleMessages();
      return;
    }
    if (
      type === changeChatPage.type ||
      type === addChatPage.type ||
      type === removeChatPage.type ||
      type === toggleAcceptedType.type ||
      type === moveChatPageLeft.type ||
      type === moveChatPageRight.type
    ) {
      flushMessages();
      next(action);
      const page = selectCurrentChatPage(store.getState());
      chatRenderer.changePage(page);
      return;
    }
    if (type === rebuildChat.type) {
      flushMessages();
      chatRenderer.rebuildChat();
      return next(action);
    }

    if (
      type === updateSettings.type ||
      type === loadSettings.type ||
      type === addHighlightSetting.type ||
      type === removeHighlightSetting.type ||
      type === updateHighlightSetting.type ||
      type === importSettings.type
    ) {
      flushMessages();
      next(action);
      const nextSettings = selectSettings(store.getState());
      chatRenderer.setHighlight(
        nextSettings.highlightSettings,
        nextSettings.highlightSettingById,
      );

      return;
    }
    if (type === 'roundrestart') {
      // Save chat as soon as possible
      saveChatToStorage(true);
      return next(action);
    }
    if (type === saveChatToDisk.type) {
      flushMessages();
      chatRenderer.saveToDisk();
      return;
    }
    if (type === clearChat.type) {
      flushMessages();
      chatRenderer.clearChat();
      return;
    }
    return next(action);
  };
};
