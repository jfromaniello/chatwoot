import { ref, unref } from 'vue';
import { useStore } from 'vuex';
import MessageApi from 'dashboard/api/inbox/message.js';

/**
 * Runs the actions of a card message: links open in a new tab, postbacks go
 * to the bot through `execute_action` and the updated message is stored.
 */
export function useCardActions(conversationId, messageId) {
  const store = useStore();
  const actionInProgress = ref(false);

  async function handleAction(action) {
    if (action.type === 'link') {
      window.open(action.uri, '_blank', 'noopener,noreferrer');
      return;
    }

    if (action.type === 'postback') {
      actionInProgress.value = true;
      try {
        const { data } = await MessageApi.executeAction(
          unref(conversationId),
          unref(messageId),
          { action_payload: action.payload }
        );
        store.dispatch('updateMessage', data);
      } finally {
        actionInProgress.value = false;
      }
    }
  }

  return { actionInProgress, handleAction };
}
