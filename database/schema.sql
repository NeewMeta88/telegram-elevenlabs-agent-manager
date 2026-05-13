CREATE DATABASE IF NOT EXISTS elevenlabs_agents_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE elevenlabs_agents_db;

CREATE TABLE IF NOT EXISTS telegram_users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  telegram_id BIGINT UNSIGNED NOT NULL,
  username VARCHAR(255) NULL,
  first_name VARCHAR(255) NULL,
  last_name VARCHAR(255) NULL,
  state VARCHAR(100) NOT NULL DEFAULT 'idle',
  selected_agent_id BIGINT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_telegram_users_telegram_id (telegram_id),
  KEY idx_telegram_users_state (state),
  KEY idx_telegram_users_selected_agent_id (selected_agent_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS elevenlabs_agents (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  elevenlabs_agent_id VARCHAR(255) NOT NULL,
  display_name VARCHAR(255) NOT NULL,
  current_prompt TEXT NULL,
  welcome_message TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_elevenlabs_agents_user_agent (user_id, elevenlabs_agent_id),
  KEY idx_elevenlabs_agents_user_id (user_id),
  KEY idx_elevenlabs_agents_external_id (elevenlabs_agent_id),
  CONSTRAINT fk_elevenlabs_agents_user
    FOREIGN KEY (user_id) REFERENCES telegram_users (id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE telegram_users
  ADD CONSTRAINT fk_telegram_users_selected_agent
  FOREIGN KEY (selected_agent_id) REFERENCES elevenlabs_agents (id)
  ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS agent_knowledge_documents (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  agent_id BIGINT UNSIGNED NOT NULL,
  elevenlabs_document_id VARCHAR(255) NULL,
  title VARCHAR(255) NOT NULL,
  source_type VARCHAR(50) NOT NULL DEFAULT 'text',
  source_url VARCHAR(1000) NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_agent_knowledge_documents_agent_id (agent_id),
  KEY idx_agent_knowledge_documents_external_id (elevenlabs_document_id),
  KEY idx_agent_knowledge_documents_status (status),
  CONSTRAINT fk_agent_knowledge_documents_agent
    FOREIGN KEY (agent_id) REFERENCES elevenlabs_agents (id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS agent_update_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  agent_id BIGINT UNSIGNED NOT NULL,
  telegram_user_id BIGINT UNSIGNED NOT NULL,
  action VARCHAR(100) NOT NULL,
  old_value TEXT NULL,
  new_value TEXT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'success',
  error_message TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_agent_update_logs_agent_id (agent_id),
  KEY idx_agent_update_logs_telegram_user_id (telegram_user_id),
  KEY idx_agent_update_logs_action (action),
  KEY idx_agent_update_logs_created_at (created_at),
  CONSTRAINT fk_agent_update_logs_agent
    FOREIGN KEY (agent_id) REFERENCES elevenlabs_agents (id)
    ON DELETE CASCADE,
  CONSTRAINT fk_agent_update_logs_telegram_user
    FOREIGN KEY (telegram_user_id) REFERENCES telegram_users (id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
