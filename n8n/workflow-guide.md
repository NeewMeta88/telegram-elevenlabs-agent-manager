# Telegram ElevenLabs Agent Manager

Node-by-node guide for manually building the n8n workflow.

## Security Rules

- Never select, read, or update an agent only by agent id.
- Always join `elevenlabs_agents` through the current `telegram_users.id`.
- Every action must use `telegram_user_id` from Telegram and `user_id` from MySQL.
- Users must not view or modify agents belonging to other Telegram users.
- Store Telegram and ElevenLabs secrets in n8n credentials or environment variables, not in node bodies.

## Credentials

- Telegram Bot API credential: token from BotFather.
- MySQL credential: host `mysql`, port `3306`, database `elevenlabs_agents_db`, user `app_user`, password `app_password`.
- ElevenLabs credential: HTTP header `xi-api-key: {{$env.ELEVENLABS_API_KEY}}` or an n8n HTTP credential.

## 1. Telegram Trigger

- Node name: `Telegram Trigger`
- Node type: `Telegram Trigger`
- Input source: Telegram updates.
- Output purpose: Receives normal messages and inline keyboard callback queries.
- Settings:
  - Updates: `message`, `callback_query`
  - Credential: Telegram Bot API

## 2. Normalize Update

- Node name: `Normalize Update`
- Node type: `Code`
- Input source: `Telegram Trigger`
- Output purpose: Produces one normalized object for both messages and callbacks.
- JavaScript:

```javascript
const update = $json;
const message = update.message || update.callback_query?.message || {};
const callbackQuery = update.callback_query || null;
const from = update.message?.from || callbackQuery?.from || {};

return [{
  json: {
    update_type: callbackQuery ? 'callback_query' : 'message',
    callback_query_id: callbackQuery?.id || null,
    chat_id: message.chat?.id,
    message_id: message.message_id,
    telegram_user_id: from.id,
    username: from.username || null,
    first_name: from.first_name || null,
    last_name: from.last_name || null,
    text: update.message?.text || null,
    callback_data: callbackQuery?.data || null,
    command: update.message?.text?.trim() || callbackQuery?.data || ''
  }
}];
```

## 3. Upsert Telegram User

- Node name: `Upsert Telegram User`
- Node type: `MySQL`
- Input source: `Normalize Update`
- Output purpose: Creates or updates the Telegram user record.
- Operation: Execute Query
- SQL:

```sql
INSERT INTO telegram_users (
  telegram_id,
  username,
  first_name,
  last_name
) VALUES (
  {{ $json.telegram_user_id }},
  {{ JSON.stringify($json.username) }},
  {{ JSON.stringify($json.first_name) }},
  {{ JSON.stringify($json.last_name) }}
)
ON DUPLICATE KEY UPDATE
  username = VALUES(username),
  first_name = VALUES(first_name),
  last_name = VALUES(last_name),
  updated_at = CURRENT_TIMESTAMP;
```

## 4. Load Current User

- Node name: `Load Current User`
- Node type: `MySQL`
- Input source: `Normalize Update`
- Output purpose: Loads database user id, state, and selected agent.
- Operation: Execute Query
- SQL:

```sql
SELECT
  tu.id AS user_id,
  tu.telegram_id,
  tu.username,
  tu.state,
  tu.selected_agent_id,
  ea.elevenlabs_agent_id AS selected_elevenlabs_agent_id,
  ea.display_name AS selected_agent_name
FROM telegram_users tu
LEFT JOIN elevenlabs_agents ea
  ON ea.id = tu.selected_agent_id
  AND ea.user_id = tu.id
WHERE tu.telegram_id = {{ $('Normalize Update').item.json.telegram_user_id }}
LIMIT 1;
```

## 5. Build Context

- Node name: `Build Context`
- Node type: `Code`
- Input source: `Normalize Update` and `Load Current User`
- Output purpose: Combines Telegram update data with the current database user.
- JavaScript:

```javascript
const update = $('Normalize Update').item.json;
const user = $('Load Current User').first().json;
const command = update.command || '';

return [{
  json: {
    ...update,
    ...user,
    route: command,
    is_waiting_prompt: user.state === 'waiting_prompt',
    is_waiting_welcome: user.state === 'waiting_welcome',
    is_waiting_knowledge: user.state === 'waiting_knowledge'
  }
}];
```

## 6. Router

- Node name: `Router`
- Node type: `Switch`
- Input source: `Build Context`
- Output purpose: Routes commands, callback data, and waiting states.
- Rules:
  - `/start`: `{{$json.route}}` equals `/start`
  - `/menu`: `{{$json.route}}` equals `/menu`
  - `/cancel`: `{{$json.route}}` equals `/cancel`
  - `agents:list`: `{{$json.route}}` equals `agents:list`
  - `agent:select:<id>`: `{{$json.route.startsWith('agent:select:')}}` is true
  - `edit:prompt`: `{{$json.route}}` equals `edit:prompt`
  - `edit:welcome`: `{{$json.route}}` equals `edit:welcome`
  - `edit:knowledge`: `{{$json.route}}` equals `edit:knowledge`
  - `waiting_prompt`: `{{$json.is_waiting_prompt && $json.update_type === 'message'}}` is true
  - `waiting_welcome`: `{{$json.is_waiting_welcome && $json.update_type === 'message'}}` is true
  - `waiting_knowledge`: `{{$json.is_waiting_knowledge && $json.update_type === 'message'}}` is true
  - Fallback: send error/help message

## 7. Send Main Menu

- Node name: `Send Main Menu`
- Node type: `Telegram`
- Input source: `/start`, `/menu`, and successful `/cancel`
- Output purpose: Shows available actions.
- Operation: Send Message
- Payload:

```json
{
  "chat_id": "={{$json.chat_id}}",
  "text": "Telegram ElevenLabs Agent Manager",
  "reply_markup": {
    "inline_keyboard": [
      [{ "text": "My agents", "callback_data": "agents:list" }],
      [{ "text": "Edit prompt", "callback_data": "edit:prompt" }],
      [{ "text": "Edit welcome message", "callback_data": "edit:welcome" }],
      [{ "text": "Add knowledge", "callback_data": "edit:knowledge" }]
    ]
  }
}
```

## 8. List User Agents

- Node name: `Load User Agents`
- Node type: `MySQL`
- Input source: `agents:list`
- Output purpose: Loads only agents owned by the current Telegram user.
- SQL:

```sql
SELECT
  ea.id,
  ea.display_name,
  ea.elevenlabs_agent_id
FROM elevenlabs_agents ea
WHERE ea.user_id = {{ $json.user_id }}
ORDER BY ea.display_name ASC;
```

- Node name: `Build Agents Keyboard`
- Node type: `Code`
- Input source: `Load User Agents`
- Output purpose: Builds an inline keyboard for owned agents.
- JavaScript:

```javascript
const rows = $input.all().map(item => item.json);
const ctx = $('Build Context').item.json;

if (!rows.length) {
  return [{
    json: {
      chat_id: ctx.chat_id,
      text: 'No agents are linked to your Telegram user yet.',
      reply_markup: { inline_keyboard: [[{ text: 'Menu', callback_data: '/menu' }]] }
    }
  }];
}

return [{
  json: {
    chat_id: ctx.chat_id,
    text: 'Choose an agent:',
    reply_markup: {
      inline_keyboard: rows.map(agent => ([{
        text: agent.display_name,
        callback_data: `agent:select:${agent.id}`
      }]))
    }
  }
}];
```

- Node name: `Send Agents List`
- Node type: `Telegram`
- Input source: `Build Agents Keyboard`
- Output purpose: Sends the owned-agent selection menu.

## 9. Select Agent With Ownership Check

- Node name: `Extract Agent Selection`
- Node type: `Code`
- Input source: `agent:select:<id>`
- Output purpose: Extracts selected local agent id from callback data.
- JavaScript:

```javascript
const ctx = $json;
const selectedAgentId = Number(ctx.route.split(':')[2]);

return [{
  json: {
    ...ctx,
    selected_agent_id_from_callback: selectedAgentId
  }
}];
```

- Node name: `Verify Selected Agent Owner`
- Node type: `MySQL`
- Input source: `Extract Agent Selection`
- Output purpose: Confirms the selected agent belongs to the current user.
- SQL:

```sql
SELECT id, display_name, elevenlabs_agent_id
FROM elevenlabs_agents
WHERE id = {{ $json.selected_agent_id_from_callback }}
  AND user_id = {{ $json.user_id }}
LIMIT 1;
```

- Node name: `Update Selected Agent`
- Node type: `MySQL`
- Input source: `Verify Selected Agent Owner`
- Output purpose: Stores selection only after ownership has been verified.
- SQL:

```sql
UPDATE telegram_users
SET selected_agent_id = {{ $json.id }},
    state = 'idle'
WHERE id = {{ $('Build Context').item.json.user_id }};
```

- Node name: `Send Agent Selected`
- Node type: `Telegram`
- Input source: `Update Selected Agent`
- Output purpose: Confirms selection or route to error if no verified row exists.
- Message: `Selected agent updated.`

## 10. Update Prompt Flow

- Node name: `Start Prompt Edit`
- Node type: `MySQL`
- Input source: `edit:prompt`
- Output purpose: Sets user state for the next text message.
- SQL:

```sql
UPDATE telegram_users
SET state = 'waiting_prompt'
WHERE id = {{ $json.user_id }}
  AND selected_agent_id IS NOT NULL;
```

- Node name: `Ask For Prompt`
- Node type: `Telegram`
- Input source: `Start Prompt Edit`
- Output purpose: Asks user to send the new prompt.
- Message: `Send the new prompt for the selected agent, or /cancel.`

- Node name: `Load Selected Agent For Prompt`
- Node type: `MySQL`
- Input source: `waiting_prompt`
- Output purpose: Loads selected agent with ownership check.
- SQL:

```sql
SELECT ea.id, ea.elevenlabs_agent_id, ea.current_prompt
FROM elevenlabs_agents ea
JOIN telegram_users tu ON tu.selected_agent_id = ea.id
WHERE tu.id = {{ $json.user_id }}
  AND ea.user_id = tu.id
LIMIT 1;
```

- Node name: `Patch ElevenLabs Prompt`
- Node type: `HTTP Request`
- Input source: `Load Selected Agent For Prompt`
- Output purpose: Updates the ElevenLabs agent prompt.
- Settings:
  - Method: `PATCH`
  - URL: `https://api.elevenlabs.io/v1/convai/agents/{{$json.elevenlabs_agent_id}}`
  - Headers:
    - `xi-api-key: {{$env.ELEVENLABS_API_KEY}}`
    - `Content-Type: application/json`
  - Body:

```json
{
  "conversation_config": {
    "agent": {
      "prompt": {
        "prompt": "={{$('Build Context').item.json.text}}"
      }
    }
  }
}
```

- Node name: `Save Prompt Update`
- Node type: `MySQL`
- Input source: `Patch ElevenLabs Prompt`
- Output purpose: Updates local prompt and logs the action.
- SQL:

```sql
UPDATE elevenlabs_agents
SET current_prompt = {{ JSON.stringify($('Build Context').item.json.text) }}
WHERE id = {{ $('Load Selected Agent For Prompt').first().json.id }}
  AND user_id = {{ $('Build Context').item.json.user_id }};

INSERT INTO agent_update_logs (
  agent_id,
  telegram_user_id,
  action,
  old_value,
  new_value,
  status
) VALUES (
  {{ $('Load Selected Agent For Prompt').first().json.id }},
  {{ $('Build Context').item.json.user_id }},
  'prompt_update',
  {{ JSON.stringify($('Load Selected Agent For Prompt').first().json.current_prompt) }},
  {{ JSON.stringify($('Build Context').item.json.text) }},
  'success'
);

UPDATE telegram_users
SET state = 'idle'
WHERE id = {{ $('Build Context').item.json.user_id }};
```

## 11. Update Welcome Message Flow

- Node name: `Start Welcome Edit`
- Node type: `MySQL`
- Input source: `edit:welcome`
- Output purpose: Sets user state for the next text message.
- SQL:

```sql
UPDATE telegram_users
SET state = 'waiting_welcome'
WHERE id = {{ $json.user_id }}
  AND selected_agent_id IS NOT NULL;
```

- Node name: `Ask For Welcome Message`
- Node type: `Telegram`
- Input source: `Start Welcome Edit`
- Output purpose: Asks user for welcome message text.
- Message: `Send the new welcome message for the selected agent, or /cancel.`

- Node name: `Load Selected Agent For Welcome`
- Node type: `MySQL`
- Input source: `waiting_welcome`
- Output purpose: Loads selected agent with ownership check.
- SQL:

```sql
SELECT ea.id, ea.elevenlabs_agent_id, ea.welcome_message
FROM elevenlabs_agents ea
JOIN telegram_users tu ON tu.selected_agent_id = ea.id
WHERE tu.id = {{ $json.user_id }}
  AND ea.user_id = tu.id
LIMIT 1;
```

- Node name: `Patch ElevenLabs Welcome`
- Node type: `HTTP Request`
- Input source: `Load Selected Agent For Welcome`
- Output purpose: Updates the ElevenLabs first message.
- Settings:
  - Method: `PATCH`
  - URL: `https://api.elevenlabs.io/v1/convai/agents/{{$json.elevenlabs_agent_id}}`
  - Headers: `xi-api-key`, `Content-Type: application/json`
  - Body:

```json
{
  "conversation_config": {
    "agent": {
      "first_message": "={{$('Build Context').item.json.text}}"
    }
  }
}
```

- Node name: `Save Welcome Update`
- Node type: `MySQL`
- Input source: `Patch ElevenLabs Welcome`
- Output purpose: Updates local welcome message and logs action.
- SQL:

```sql
UPDATE elevenlabs_agents
SET welcome_message = {{ JSON.stringify($('Build Context').item.json.text) }}
WHERE id = {{ $('Load Selected Agent For Welcome').first().json.id }}
  AND user_id = {{ $('Build Context').item.json.user_id }};

INSERT INTO agent_update_logs (
  agent_id,
  telegram_user_id,
  action,
  old_value,
  new_value,
  status
) VALUES (
  {{ $('Load Selected Agent For Welcome').first().json.id }},
  {{ $('Build Context').item.json.user_id }},
  'welcome_update',
  {{ JSON.stringify($('Load Selected Agent For Welcome').first().json.welcome_message) }},
  {{ JSON.stringify($('Build Context').item.json.text) }},
  'success'
);

UPDATE telegram_users
SET state = 'idle'
WHERE id = {{ $('Build Context').item.json.user_id }};
```

## 12. Update Knowledge Base Flow

- Node name: `Start Knowledge Edit`
- Node type: `MySQL`
- Input source: `edit:knowledge`
- Output purpose: Sets user state for the next text message.
- SQL:

```sql
UPDATE telegram_users
SET state = 'waiting_knowledge'
WHERE id = {{ $json.user_id }}
  AND selected_agent_id IS NOT NULL;
```

- Node name: `Ask For Knowledge`
- Node type: `Telegram`
- Input source: `Start Knowledge Edit`
- Output purpose: Asks user for text content to add as knowledge.
- Message: `Send the knowledge text to add to the selected agent, or /cancel.`

- Node name: `Load Selected Agent For Knowledge`
- Node type: `MySQL`
- Input source: `waiting_knowledge`
- Output purpose: Loads selected agent with ownership check.
- SQL:

```sql
SELECT ea.id, ea.elevenlabs_agent_id, ea.display_name
FROM elevenlabs_agents ea
JOIN telegram_users tu ON tu.selected_agent_id = ea.id
WHERE tu.id = {{ $json.user_id }}
  AND ea.user_id = tu.id
LIMIT 1;
```

- Node name: `Create ElevenLabs Knowledge Text`
- Node type: `HTTP Request`
- Input source: `Load Selected Agent For Knowledge`
- Output purpose: Creates a knowledge base text document in ElevenLabs.
- Settings:
  - Method: `POST`
  - URL: `https://api.elevenlabs.io/v1/convai/knowledge-base/text`
  - Headers:
    - `xi-api-key: {{$env.ELEVENLABS_API_KEY}}`
    - `Content-Type: application/json`
  - Body:

```json
{
  "name": "={{'telegram-knowledge-' + $('Build Context').item.json.user_id + '-' + Date.now()}}",
  "text": "={{$('Build Context').item.json.text}}"
}
```

- Node name: `Attach Knowledge To Agent`
- Node type: `HTTP Request`
- Input source: `Create ElevenLabs Knowledge Text`
- Output purpose: Adds the created knowledge document to the selected agent.
- Settings:
  - Method: `PATCH`
  - URL: `https://api.elevenlabs.io/v1/convai/agents/{{$('Load Selected Agent For Knowledge').first().json.elevenlabs_agent_id}}`
  - Headers: `xi-api-key`, `Content-Type: application/json`
  - Body:

```json
{
  "conversation_config": {
    "agent": {
      "prompt": {
        "knowledge_base": [
          {
            "id": "={{$json.id || $json.document_id}}",
            "type": "text"
          }
        ]
      }
    }
  }
}
```

- Node name: `Save Knowledge Update`
- Node type: `MySQL`
- Input source: `Attach Knowledge To Agent`
- Output purpose: Stores document metadata, logs action, and clears state.
- SQL:

```sql
INSERT INTO agent_knowledge_documents (
  agent_id,
  elevenlabs_document_id,
  title,
  source_type,
  status
) VALUES (
  {{ $('Load Selected Agent For Knowledge').first().json.id }},
  {{ JSON.stringify($('Create ElevenLabs Knowledge Text').first().json.id || $('Create ElevenLabs Knowledge Text').first().json.document_id) }},
  'Telegram knowledge text',
  'text',
  'ready'
);

INSERT INTO agent_update_logs (
  agent_id,
  telegram_user_id,
  action,
  new_value,
  status
) VALUES (
  {{ $('Load Selected Agent For Knowledge').first().json.id }},
  {{ $('Build Context').item.json.user_id }},
  'knowledge_update',
  {{ JSON.stringify($('Build Context').item.json.text) }},
  'success'
);

UPDATE telegram_users
SET state = 'idle'
WHERE id = {{ $('Build Context').item.json.user_id }};
```

## 13. Cancel Flow

- Node name: `Cancel State`
- Node type: `MySQL`
- Input source: `/cancel`
- Output purpose: Clears current waiting state for the current user only.
- SQL:

```sql
UPDATE telegram_users
SET state = 'idle'
WHERE id = {{ $json.user_id }};
```

- Node name: `Send Cancelled`
- Node type: `Telegram`
- Input source: `Cancel State`
- Output purpose: Confirms cancellation and links back to menu.
- Message: `Cancelled. Use /menu to continue.`

## 14. Error Handling Messages

- Node name: `Send No Agent Selected`
- Node type: `Telegram`
- Input source: edit flows when `selected_agent_id` is null or selected agent load returns no rows.
- Output purpose: Prevents updates without an owned selected agent.
- Message: `No agent is selected. Open /menu and choose My agents first.`

- Node name: `Send Unauthorized Agent`
- Node type: `Telegram`
- Input source: `Verify Selected Agent Owner` when no rows are returned.
- Output purpose: Blocks cross-user access attempts.
- Message: `That agent is not available for your account.`

- Node name: `Send Unknown Command`
- Node type: `Telegram`
- Input source: Router fallback.
- Output purpose: Handles unsupported messages or callback data.
- Message: `Unknown command. Use /menu to continue.`

- Node name: `Log Failed Update`
- Node type: `MySQL`
- Input source: HTTP Request error branches.
- Output purpose: Records failed API updates without exposing secrets.
- SQL:

```sql
INSERT INTO agent_update_logs (
  agent_id,
  telegram_user_id,
  action,
  new_value,
  status,
  error_message
) VALUES (
  {{ $json.agent_id || $('Build Context').item.json.selected_agent_id || 0 }},
  {{ $('Build Context').item.json.user_id }},
  {{ JSON.stringify($json.action || 'agent_update') }},
  {{ JSON.stringify($('Build Context').item.json.text || '') }},
  'failed',
  {{ JSON.stringify($json.message || 'Unknown workflow error') }}
);

UPDATE telegram_users
SET state = 'idle'
WHERE id = {{ $('Build Context').item.json.user_id }};
```

- Node name: `Send Generic Error`
- Node type: `Telegram`
- Input source: Error branches.
- Output purpose: Tells the user the action failed without leaking internals.
- Message: `The update could not be completed. Please try again or use /cancel.`
