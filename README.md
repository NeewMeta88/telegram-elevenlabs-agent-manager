# Telegram ElevenLabs Agent Manager

n8n-based Telegram bot for managing ElevenLabs voice agents. The bot stores Telegram users, their ElevenLabs agents, knowledge documents, and update history in MySQL.

## Stack

- n8n
- MySQL 8
- Telegram Bot API
- ElevenLabs API
- Docker Compose

## Local Setup

1. Create a Telegram bot via BotFather:
   - Open Telegram and start a chat with `@BotFather`.
   - Run `/newbot`.
   - Follow the prompts for bot name and username.

2. Get the Telegram bot token from BotFather and keep it private.

3. Get an ElevenLabs API key from your ElevenLabs account settings.

4. Create or choose existing ElevenLabs agents that this bot will manage. Users can also link agents later from Telegram with the Add new agent menu action.

5. Copy the environment template:

   ```bash
   cp .env.example .env
   ```

6. Fill in `.env` with local/test values:
   - `N8N_HOST`
   - `N8N_PORT`
   - `N8N_PROTOCOL`
   - `WEBHOOK_URL`
   - `N8N_ENCRYPTION_KEY`
   - `N8N_BLOCK_ENV_ACCESS_IN_NODE=false`
   - `GENERIC_TIMEZONE`
   - `MYSQL_ROOT_PASSWORD`
   - `MYSQL_DATABASE`
   - `MYSQL_USER`
   - `MYSQL_PASSWORD`
   - `MYSQL_PORT`
   - `TELEGRAM_BOT_TOKEN`
   - `ELEVENLABS_API_KEY`
   - `ELEVENLABS_AGENT_ID`
   - `TELEGRAM_USER_ID`
   - `TELEGRAM_USERNAME`
   - `TELEGRAM_FIRST_NAME`

   The imported workflow reads Telegram and ElevenLabs secrets from environment variables in HTTP Request nodes:
   - `{{$env.TELEGRAM_BOT_TOKEN}}`
   - `{{$env.ELEVENLABS_API_KEY}}`

   For local self-hosted n8n, environment variable access in nodes must be enabled:

   ```bash
   N8N_BLOCK_ENV_ACCESS_IN_NODE=false
   ```

7. Start local services:

   ```bash
   docker compose up -d
   ```

8. Open n8n at `http://localhost:5678`.

9. Create n8n credentials:
   - Telegram Bot API: use the token from BotFather.
   - MySQL: use host `mysql`, port `3306`, database `elevenlabs_agents_db`, user `app_user`, password `app_password`.

   The workflow sends Telegram replies and ElevenLabs API requests through HTTP Request nodes using environment variables. Do not hardcode tokens in workflow nodes.

10. Expose local n8n with ngrok:

    ```bash
    ngrok http 5678
    ```

11. Set `WEBHOOK_URL` in `.env` to the ngrok HTTPS URL, then restart n8n:

    ```bash
    docker compose restart n8n
    ```

12. Import the n8n workflow JSON into n8n.

13. Add seed data with your Telegram user ID and ElevenLabs agent ID. Use `database/seed.example.sql` as a template and keep real values out of version control.

14. Test bot commands in Telegram. Confirm that the bot can identify the Telegram user, add an ElevenLabs agent, list or select owned agents, update the selected agent, and remove a local bot link.

15. Export the final n8n workflow JSON before submission.

MySQL is available locally on `127.0.0.1:${MYSQL_PORT}` using the value from `.env`.

## Local Credentials

- Database: `elevenlabs_agents_db`
- User: `app_user`
- Password: `app_password`
- Host from host machine: `127.0.0.1`
- Host from n8n container: `mysql`
- Port from host machine: value of `MYSQL_PORT` in `.env`, default template value `3307`
- Port from n8n container: `3306`

## Database

`database/schema.sql` is the canonical final MySQL structure for submission. It is mounted into the MySQL init directory and runs on first database startup. It creates the complete final schema:

- `telegram_users`
- `elevenlabs_agents`
- `agent_knowledge_documents`
- `agent_update_logs`

`database/seed.example.sql` contains placeholder-only sample data for local testing.

Migration files under `database/migrations/` are optional local update helpers for an existing development database. They are not required to understand or submit the final database structure.

## Agent Management

Add new agent:

- In Telegram, use `/add_agent` or the Add new agent button.
- Open `https://elevenlabs.io/app/agents/new`.
- Create a new agent.
- Open the agent customization page.
- Click the three dots in the top-right corner.
- Copy the Agent ID and send it to the bot.

The bot validates that the ID starts with `agent_`, checks the agent through the ElevenLabs API, and links it to the current Telegram user in MySQL.

Remove agent:

- In Telegram, use `/remove_agent` or the Remove agent button.
- Choose one of your active linked agents.
- Confirm removal.

Removing an agent only soft-removes the local bot link by setting `elevenlabs_agents.is_active = FALSE` and `removed_at = CURRENT_TIMESTAMP`. It does not call the ElevenLabs delete API and does not delete the real ElevenLabs agent.

## Security

- Do not commit `.env`, real Telegram bot tokens, ElevenLabs API keys, ngrok URLs, or production credentials.
- The workflow uses `{{$env.TELEGRAM_BOT_TOKEN}}` and `{{$env.ELEVENLABS_API_KEY}}` in HTTP Request nodes. Keep these values in local environment files only.
- Use the n8n MySQL credential for database access from workflow nodes.
- Keep `database/seed.example.sql` placeholder-only. Create a local untracked seed file for real test IDs if needed.
- Rotate any token that is accidentally committed or shared.
- The default MySQL credentials are for local technical-test use only and should not be reused in production.

## Troubleshooting

MySQL connection issues:

- From n8n, use MySQL host `mysql` and port `3306`.
- From the host machine, use `127.0.0.1` and the `MYSQL_PORT` value from `.env`.
- If schema changes do not appear, remove the MySQL volume and start again because init scripts run only on first database creation.

Webhook issues:

- `WEBHOOK_URL` must be the public ngrok HTTPS URL.
- Restart n8n after changing `.env`.
- Keep ngrok running while testing Telegram webhooks.
- If the ngrok URL changes, update `.env`, restart n8n, and re-activate or refresh the workflow webhook.

Telegram callback issues:

- Verify the Telegram credential uses the current BotFather token.
- Confirm the workflow is active in n8n.
- Check that callback data matches the workflow routing logic.
- Make sure the Telegram user ID exists in `telegram_users` and has access to the selected agent.

## Final Testing Checklist

- `/start`
- `/menu`
- Add new agent
- My agents
- Select agent
- Update prompt
- Update welcome message
- Update knowledge base
- Remove agent
- Security test with a second Telegram user

## Final Submission Checklist

- `n8n/telegram-elevenlabs-agent-manager.json` imports into n8n.
- `database/schema.sql` is the standalone final MySQL schema and creates all required tables, indexes, and foreign keys.
- Workflow HTTP Request nodes read `TELEGRAM_BOT_TOKEN` and `ELEVENLABS_API_KEY` from environment variables.
- Local self-hosted n8n has `N8N_BLOCK_ENV_ACCESS_IN_NODE=false`.
- README setup steps are complete and reproducible.
- No real secrets are committed.

## Final Submission Files

Required submission files:

- `n8n/telegram-elevenlabs-agent-manager.json`
- `database/schema.sql`

Additional reproducibility files:

- `docker-compose.yml`
- `.env.example`
- `database/seed.example.sql`
