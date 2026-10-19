import { MESSAGE_TYPE } from 'shared/constants/messages';
import { CONTENT_TYPES } from 'dashboard/components-next/message/constants';

// AbastoVirtual posts each Avi suggestion as a card whose postbacks are
// `suggest_{uuid}_send` / `suggest_{uuid}_dismiss`. Other cards (HITL
// approvals, etc.) don't lock the reply box.
const SUGGESTION_PAYLOAD_PREFIX = 'suggest_';

export const hasAviSuggestionAction = (items = []) =>
  items.some(card =>
    (card.actions || []).some(action =>
      action.payload?.startsWith(SUGGESTION_PAYLOAD_PREFIX)
    )
  );

// A suggestion stops being pending when it is acted on (Chatwoot marks the
// card `dismissed`) or when AbastoVirtual deletes it after a rejection or
// because a newer card superseded it (the message turns into plain text).
const isPendingAviSuggestion = message =>
  message.content_type === CONTENT_TYPES.CARDS &&
  !message.content_attributes?.dismissed &&
  hasAviSuggestionAction(message.content_attributes?.items);

/**
 * The Avi suggestion the operator still has to answer, if it is the latest
 * thing in the conversation (activity messages like assignments don't count).
 */
export const getPendingAviSuggestion = (messages = []) => {
  const last = messages.findLast(
    message => message.message_type !== MESSAGE_TYPE.ACTIVITY
  );
  return last && isPendingAviSuggestion(last) ? last : null;
};
