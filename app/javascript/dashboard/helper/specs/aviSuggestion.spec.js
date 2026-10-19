import { getPendingAviSuggestion } from '../aviSuggestion';

const suggestionCard = (attrs = {}) => ({
  id: 10,
  message_type: 1,
  content_type: 'cards',
  content_attributes: {
    dismiss_on_action: true,
    items: [
      {
        title: 'Respuesta sugerida',
        actions: [
          { type: 'postback', text: 'Enviar', payload: 'suggest_abc_send' },
          { type: 'link', text: 'Rechazar', uri: 'https://example.com' },
        ],
      },
    ],
    ...attrs,
  },
});

const incoming = { id: 1, message_type: 0, content_type: 'text' };
const activity = { id: 11, message_type: 2, content_type: 'text' };

describe('getPendingAviSuggestion', () => {
  it('returns the suggestion when it is the last message', () => {
    const card = suggestionCard();
    expect(getPendingAviSuggestion([incoming, card])).toBe(card);
  });

  it('ignores activity messages after the suggestion', () => {
    const card = suggestionCard();
    expect(getPendingAviSuggestion([incoming, card, activity])).toBe(card);
  });

  it('returns null once the suggestion was acted on', () => {
    expect(
      getPendingAviSuggestion([incoming, suggestionCard({ dismissed: true })])
    ).toBeNull();
  });

  it('returns null when the suggestion was deleted', () => {
    const deleted = {
      id: 10,
      message_type: 1,
      content_type: 'text',
      content_attributes: { deleted: true },
    };
    expect(getPendingAviSuggestion([incoming, deleted])).toBeNull();
  });

  it('returns null when something came after the suggestion', () => {
    expect(getPendingAviSuggestion([suggestionCard(), incoming])).toBeNull();
  });

  it('returns null for cards that are not Avi suggestions', () => {
    const hitl = suggestionCard({
      items: [{ actions: [{ type: 'postback', payload: 'hitl_abc_approve' }] }],
    });
    expect(getPendingAviSuggestion([incoming, hitl])).toBeNull();
  });

  it('returns null for an empty conversation', () => {
    expect(getPendingAviSuggestion([])).toBeNull();
  });
});
