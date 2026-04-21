# Interactive Card Messages for Agent Dashboard

Interactive card messages allow AgentBots (or any API client) to create private,
actionable messages visible only to agents. These cards render with buttons that
trigger webhooks back to the originating bot, enabling workflows like AI
suggestions, human-in-the-loop approvals, and interactive operator tooling.

## Creating a Card Message

Send a `POST` request to the Messages API with `content_type: "cards"` and
`private: true`.

### Endpoint

```
POST /api/v1/accounts/{account_id}/conversations/{conversation_id}/messages
```

### Authentication

Use the AgentBot access token:

```
Headers:
  api_access_token: {agent_bot_access_token}
  Content-Type: application/json
```

### Payload

```json
{
  "content_type": "cards",
  "private": true,
  "content": "Optional text shown above the cards.",
  "content_attributes": {
    "dismiss_on_action": true,
    "items": [
      {
        "title": "Card Title",
        "description": "Card description text.",
        "media_url": "https://example.com/image.png",
        "actions": [
          {
            "type": "postback",
            "text": "Approve",
            "payload": "approve_123"
          },
          {
            "type": "postback",
            "text": "Reject",
            "payload": "reject_123"
          },
          {
            "type": "link",
            "text": "View Details",
            "uri": "https://example.com/details"
          }
        ]
      }
    ]
  }
}
```

### Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `content_type` | string | yes | Must be `"cards"` |
| `private` | boolean | yes | Set to `true` for agent-only visibility |
| `content` | string | no | Text displayed above the cards |
| `content_attributes.dismiss_on_action` | boolean | no | Auto-dismiss after any postback action |
| `content_attributes.items` | array | yes | One or more card objects |

### Card Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | no | Card heading |
| `description` | string | no | Card body text |
| `media_url` | string | no | Image URL displayed at the top |
| `actions` | array | yes | One or more action buttons |

### Action Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | yes | `"postback"` or `"link"` |
| `text` | string | yes | Button label |
| `payload` | string | yes* | Postback data sent to webhook (*required for postback) |
| `uri` | string | yes* | URL to open (*required for link) |

## Action Types

### Postback

When an agent clicks a postback button, Chatwoot sends a webhook to the
AgentBot that created the message:

```
POST {agent_bot.outgoing_url}
```

Webhook payload:

```json
{
  "event": "message_action_executed",
  "action_payload": "approve_123",
  "id": 42,
  "content": "Optional text shown above the cards.",
  "content_type": "cards",
  "private": true,
  "conversation": {
    "id": 1,
    "inbox_id": 1,
    "status": "open",
    "meta": {
      "assignee": { "id": 1, "name": "Agent Name" },
      "sender": { "id": 1, "name": "Contact Name" }
    }
  },
  "account": { "id": 1, "name": "Account Name" },
  "sender": { "id": 1, "name": "Bot Name", "type": "agent_bot" }
}
```

The `action_payload` field contains the `payload` value from the button that was
clicked. Use this to determine which action to take in your bot.

### Link

Link buttons open the specified URL in a new browser tab. No webhook is sent.

## Dismissing Cards

Cards can be dismissed (hidden without the "Message deleted" residue) in two
ways:

### Auto-dismiss

Set `dismiss_on_action: true` in `content_attributes` when creating the message.
The card will be dismissed automatically after any postback button is clicked.

### Manual Dismiss

Each card displays a "Dismiss" link. Agents can click it to hide the card.

### API Dismiss

```
POST /api/v1/accounts/{account_id}/conversations/{conversation_id}/messages/{message_id}/dismiss
```

This sets `content_attributes.dismissed = true` on the message. Dismissed
messages are filtered from the conversation view entirely (no avatar, no
metadata residue).

## Execute Action API

You can also trigger a postback programmatically:

```
POST /api/v1/accounts/{account_id}/conversations/{conversation_id}/messages/{message_id}/execute_action
```

```json
{
  "action_payload": "approve_123"
}
```

Returns the updated message object. If `dismiss_on_action` is set, the message
will be marked as dismissed in the response.

## Examples

### AI Reply Suggestion

```json
{
  "content_type": "cards",
  "private": true,
  "content": "Customer is asking about refund policy.",
  "content_attributes": {
    "dismiss_on_action": true,
    "items": [
      {
        "title": "Suggested Reply",
        "description": "We offer a full refund within 30 days of purchase. Would you like me to process that for you?",
        "actions": [
          { "type": "postback", "text": "Approve & Send", "payload": "approve_refund" },
          { "type": "postback", "text": "Edit First", "payload": "edit_refund" },
          { "type": "postback", "text": "Reject", "payload": "reject_refund" }
        ]
      }
    ]
  }
}
```

### Human-in-the-Loop Approval

```json
{
  "content_type": "cards",
  "private": true,
  "content": "Customer wants to cancel their subscription.",
  "content_attributes": {
    "items": [
      {
        "title": "Retention Offer",
        "description": "Offer 30% discount for 3 months?",
        "actions": [
          { "type": "postback", "text": "Apply Discount", "payload": "retention_discount_30" },
          { "type": "postback", "text": "Process Cancellation", "payload": "process_cancel" }
        ]
      },
      {
        "title": "Escalation",
        "description": "Transfer to retention specialist",
        "actions": [
          { "type": "postback", "text": "Escalate", "payload": "escalate_retention" },
          { "type": "link", "text": "View Account", "uri": "https://crm.example.com/account/123" }
        ]
      }
    ]
  }
}
```

### Multi-step Workflow

Your bot can chain interactions by creating new card messages after processing
each action. For example:

1. Bot creates card: "Customer wants refund" with Approve/Reject
2. Agent clicks "Approve"
3. Bot receives `message_action_executed` webhook with `payload: "approve_refund"`
4. Bot processes the refund and creates a new card: "Refund processed. Send confirmation?" with Send/Skip
5. Agent clicks "Send"
6. Bot sends the confirmation message to the customer
