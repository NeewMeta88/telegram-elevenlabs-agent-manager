# Telegram ElevenLabs Agent Manager Workflow

This guide matches the importable workflow JSON in `n8n/telegram-elevenlabs-agent-manager.json`. The capitalized export file is kept in sync for compatibility with the original local n8n export.

## Credentials

- Telegram credential name: `Telegram account`
- MySQL credential name: `MySQL account`
- ElevenLabs API key: HTTP Request nodes set `xi-api-key` to `{{ $env.ELEVENLABS_API_KEY }}`

No Telegram token, ElevenLabs API key, or MySQL password is stored in the workflow JSON.

## Flow

1. `Telegram Trigger` listens for `message` and `callback_query` updates.
2. `Normalize Update` creates `telegram_user_id`, `chat_id`, `username`, `first_name`, `text`, `callback_data`, `callback_query_id`, and `is_callback`.
3. `Upsert User` inserts or updates `telegram_users` by Telegram id.
4. `Load User` loads the local user id, selected agent, and state.
5. `Build Context` merges Telegram and database fields into one routing object.
6. `Router` handles `/start`, `/menu`, `/agents`, `/current`, `/cancel`, menu callbacks, agent selection callbacks, edit callbacks, waiting text states, and fallback.

## Agent Security

Every agent read or write is filtered with the current local `telegram_users.id` as `user_id`. Agent callback data contains the internal agent id, but selection is accepted only after `Verify Selected Agent Owner` confirms ownership. Prompt, welcome, and knowledge updates all reload the selected agent through `telegram_users.selected_agent_id` and `elevenlabs_agents.user_id` before calling ElevenLabs.

## Menus

The main menu sends inline buttons for:

- My agents: `agents:list`
- Current agent: `agent:current`
- Update prompt: `edit:prompt`
- Update welcome message: `edit:welcome`
- Update knowledge base: `edit:knowledge`

The agents list queries only rows owned by the current user and builds `agent:select:<internal id>` callbacks.

## Update Flows

- Prompt updates PATCH `/v1/convai/agents/{{ elevenlabs_agent_id }}` with `conversation_config.agent.prompt.prompt`, save `current_prompt`, clear state, insert `agent_update_logs`, and notify the user.
- Welcome updates PATCH the same agent endpoint with `conversation_config.agent.first_message`, save `welcome_message`, clear state, insert `agent_update_logs`, and notify the user.
- Knowledge updates POST `/v1/convai/knowledge-base/text`, PATCH the selected agent with the created text document in `conversation_config.agent.prompt.knowledge_base`, save `agent_knowledge_documents`, clear state, insert `agent_update_logs`, and notify the user.

## Schema Compatibility

The workflow follows the current `database/schema.sql`: user state is cleared by setting it to `idle` because the column is `NOT NULL`, and agent list queries do not reference an `is_active` column because that column is not present in the existing schema.
