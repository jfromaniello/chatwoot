<script setup>
import { computed, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import BaseBubble from './Base.vue';
import { useMessageContext } from '../provider.js';
import MessageApi from 'dashboard/api/inbox/message.js';

const store = useStore();
const { t } = useI18n();
const { contentAttributes, conversationId, id, content } = useMessageContext();

const cards = computed(() => contentAttributes.value?.items || []);
const isDismissed = computed(() => contentAttributes.value?.dismissed);
const dismissOnAction = computed(
  () => contentAttributes.value?.dismiss_on_action
);
const actionInProgress = ref(false);

async function dismiss() {
  const { data } = await MessageApi.dismiss(conversationId.value, id.value);
  store.dispatch('updateMessage', data);
}

async function handleAction(action) {
  if (action.type === 'link') {
    window.open(action.uri, '_blank', 'noopener,noreferrer');
    return;
  }

  if (action.type === 'postback') {
    actionInProgress.value = true;
    try {
      await MessageApi.executeAction(conversationId.value, id.value, {
        action_payload: action.payload,
      });
      if (dismissOnAction.value) {
        await dismiss();
      }
    } finally {
      actionInProgress.value = false;
    }
  }
}
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <BaseBubble v-if="!isDismissed" class="px-4 py-3" data-bubble-name="card">
    <p v-if="content" class="mb-3 text-sm">
      {{ content }}
    </p>
    <div class="flex flex-col gap-3">
      <div
        v-for="(card, index) in cards"
        :key="index"
        class="rounded-lg overflow-hidden bg-n-alpha-black1"
      >
        <img
          v-if="card.media_url"
          class="w-full object-contain max-h-[150px]"
          :src="card.media_url"
          :alt="card.title"
        />
        <div class="p-3">
          <h4 v-if="card.title" class="text-sm font-medium leading-snug mb-1">
            {{ card.title }}
          </h4>
          <p v-if="card.description" class="text-xs opacity-80 mb-2">
            {{ card.description }}
          </p>
          <div v-if="card.actions?.length" class="flex flex-wrap gap-2">
            <button
              v-for="action in card.actions"
              :key="action.payload || action.uri"
              :disabled="actionInProgress"
              class="flex-1 min-w-[80px] px-3 py-1.5 text-xs font-medium rounded-lg transition-colors disabled:opacity-50"
              :class="
                action.type === 'link'
                  ? 'bg-n-alpha-black1 hover:bg-n-alpha-black2 text-current'
                  : 'bg-n-brand text-white hover:opacity-90'
              "
              @click="handleAction(action)"
            >
              {{ action.text }}
            </button>
          </div>
        </div>
      </div>
    </div>
    <button
      class="mt-2 text-xs opacity-50 hover:opacity-80 transition-opacity"
      @click="dismiss"
    >
      {{ t('GENERAL_SETTINGS.NOTIFICATIONS.DISMISS') }}
    </button>
  </BaseBubble>
</template>
