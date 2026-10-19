<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import BaseBubble from './Base.vue';
import { useMessageContext } from '../provider.js';
import MessageApi from 'dashboard/api/inbox/message.js';
import { useCardActions } from 'dashboard/composables/useCardActions';
import { hasAviSuggestionAction } from 'dashboard/helper/aviSuggestion';

const store = useStore();
const { t } = useI18n();
const { contentAttributes, conversationId, id, content } = useMessageContext();

const cards = computed(() => contentAttributes.value?.items || []);
const isDismissed = computed(() => contentAttributes.value?.dismissed);
// Avi suggestions have to be sent, rejected or dismissed through their own
// actions: a plain dismiss would hide the card without AbastoVirtual
// knowing what the operator did with it.
const canDismiss = computed(() => !hasAviSuggestionAction(cards.value));
const { actionInProgress, handleAction } = useCardActions(conversationId, id);

async function dismiss() {
  const { data } = await MessageApi.dismiss(conversationId.value, id.value);
  store.dispatch('updateMessage', data);
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
      v-if="canDismiss"
      class="mt-2 text-xs opacity-50 hover:opacity-80 transition-opacity"
      @click="dismiss"
    >
      {{ t('GENERAL_SETTINGS.DISMISS') }}
    </button>
  </BaseBubble>
</template>
