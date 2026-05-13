# Telegram ElevenLabs Agent Manager Workflow

This guide matches the importable workflow JSON in `n8n/telegram-elevenlabs-agent-manager.json`.

## Credentials

- Telegram trigger credential name: `Telegram account`
- MySQL credential name: `MySQL account`
- Telegram sendMessage HTTP Request nodes use `{{ $env.TELEGRAM_BOT_TOKEN }}` in the Telegram Bot API URL.
- ElevenLabs API key: HTTP Request nodes set `xi-api-key` to `{{ $env.ELEVENLABS_API_KEY }}`
- Local self-hosted n8n must allow node access to environment variables with `N8N_BLOCK_ENV_ACCESS_IN_NODE=false`.

No Telegram token, ElevenLabs API key, or MySQL password is stored in the workflow JSON.

## Flow

1. `Telegram Trigger` listens for `message` and `callback_query` updates.
2. `Normalize Update` creates `telegram_user_id`, `chat_id`, `username`, `first_name`, `text`, `callback_data`, `callback_query_id`, and `is_callback`.
3. `Upsert User` inserts or updates `telegram_users` by Telegram id.
4. `Load User` loads the local user id, selected agent, and state.
5. `Build Context` merges Telegram and database fields into one routing object.
6. `Router` handles `/start`, `/menu`, `/agents`, `/current`, `/add_agent`, `/remove_agent`, `/cancel`, menu callbacks, add/remove callbacks, agent selection callbacks, edit callbacks, waiting text states, and fallback.

## Agent Security

Every agent read or write is filtered with the current local `telegram_users.id` as `user_id` and `elevenlabs_agents.is_active = TRUE`. Agent callback data contains the internal agent id, but selection, update, and removal actions are accepted only after ownership and active status are confirmed. Prompt, welcome, and knowledge updates all reload the selected agent through `telegram_users.selected_agent_id`, `elevenlabs_agents.user_id`, and `elevenlabs_agents.is_active` before calling ElevenLabs.

## Menus

The main menu sends inline buttons for:

- My agents: `agents:list`
- Add new agent: `agent:add`
- Remove agent: `agent:remove:list`
- Current agent: `agent:current`
- Update prompt: `edit:prompt`
- Update welcome message: `edit:welcome`
- Update knowledge base: `edit:knowledge`

The agents list queries only active rows owned by the current user and builds `agent:select:<internal id>` callbacks.

## Add Agent Flow

- `/add_agent` and `agent:add` set `telegram_users.state` to `waiting_add_agent_id`.
- The bot sends instructions for creating an ElevenLabs agent, opening its customization page, using the top-right three dots, and copying the Agent ID.
- The next text message is trimmed and must start with `agent_`.
- `Get ElevenLabs Agent` calls `GET /v1/convai/agents/{{agent_id}}` with `xi-api-key: {{ $env.ELEVENLABS_API_KEY }}`.
- `Check Existing Agent Link` prevents linking an ElevenLabs agent id that already belongs to another Telegram user.
- Existing same-user links are reactivated with `is_active = TRUE` and `removed_at = NULL`; new links are inserted for the current user.
- Successful add clears state to `idle`, logs `add_agent`, and returns menu buttons.

## Remove Agent Flow

- `/remove_agent` and `agent:remove:list` load only active agents for the current user.
- `agent:remove:confirm:<id>` verifies `id`, `user_id`, and `is_active = TRUE`, then sends a confirmation message.
- `agent:remove:do:<id>` verifies ownership and active status again.
- `Soft Remove Agent` updates only the local MySQL link with `is_active = FALSE` and `removed_at = CURRENT_TIMESTAMP`.
- If the removed agent was selected, `telegram_users.selected_agent_id` is set to `NULL`.
- The flow logs `remove_agent` and returns My agents/Menu buttons.
- The workflow never calls a destructive ElevenLabs delete endpoint.

## Update Flows

- Prompt updates PATCH `/v1/convai/agents/{{ elevenlabs_agent_id }}` with `conversation_config.agent.prompt.prompt`, save `current_prompt`, clear state, insert `agent_update_logs`, and notify the user.
- Welcome updates PATCH the same agent endpoint with `conversation_config.agent.first_message`, save `welcome_message`, clear state, insert `agent_update_logs`, and notify the user.
- Knowledge updates POST `/v1/convai/knowledge-base/text`, PATCH the selected agent with the created text document in `conversation_config.agent.prompt.knowledge_base`, save `agent_knowledge_documents`, clear state, insert `agent_update_logs`, and notify the user.

## Schema Compatibility

The workflow follows the canonical final `database/schema.sql`: user state is cleared by setting it to `idle` because the column is `NOT NULL`, agent lists and updates require `is_active = TRUE`, and soft removal uses `is_active = FALSE` plus `removed_at`.
