# Telegram ElevenLabs Agent Manager

n8n-based Telegram bot for managing ElevenLabs voice agents. The bot stores Telegram users, their ElevenLabs agents, knowledge documents, and update history in MySQL.

## Stack

- n8n
- MySQL 8
- Telegram Bot API
- ElevenLabs API
- Docker Compose

## Local Setup

1. Copy the environment template:

   ```bash
   cp .env.example .env
   ```

2. Fill in `.env` with local/test values. Do not commit real secrets.

3. Start services:

   ```bash
   docker compose up -d
   ```

4. Open n8n at `http://localhost:5678`.

MySQL is available locally on `127.0.0.1:3307`.

## Local Credentials

- Database: `elevenlabs_agents_db`
- User: `app_user`
- Password: `app_password`
- Host from host machine: `127.0.0.1`
- Host from n8n container: `mysql`
- Port from host machine: `3307`
- Port from n8n container: `3306`

## Database

`database/schema.sql` is mounted into the MySQL init directory and runs on first database startup. It creates:

- `telegram_users`
- `elevenlabs_agents`
- `agent_knowledge_documents`
- `agent_update_logs`

`database/seed.example.sql` contains placeholder-only sample data for local testing.

## Final Submission Files

Submit these files for the technical test:

- `docker-compose.yml`
- `.gitignore`
- `.env.example`
- `database/schema.sql`
- `database/seed.example.sql`
- `README.md`
