<script setup>
import { computed } from 'vue';
import { useCardActions } from 'dashboard/composables/useCardActions';

const props = defineProps({
  conversationId: { type: Number, required: true },
  message: { type: Object, required: true },
});

const actions = computed(() =>
  (props.message.content_attributes?.items || []).flatMap(
    card => card.actions || []
  )
);

const { actionInProgress, handleAction } = useCardActions(
  computed(() => props.conversationId),
  computed(() => props.message.id)
);
</script>

<template>
  <div
    class="flex flex-col gap-3 px-4 py-3 border-t border-n-weak bg-n-alpha-1"
  >
    <p class="text-sm text-n-slate-12">
      {{ $t('CONVERSATION.AVI_SUGGESTION_LOCK.MESSAGE') }}
    </p>
    <div class="flex flex-wrap gap-2">
      <button
        v-for="action in actions"
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
</template>
