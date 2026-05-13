USE elevenlabs_agents_db;

SET @add_is_active = (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE elevenlabs_agents ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE AFTER welcome_message',
    'SELECT 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'elevenlabs_agents'
    AND COLUMN_NAME = 'is_active'
);

PREPARE add_is_active_stmt FROM @add_is_active;
EXECUTE add_is_active_stmt;
DEALLOCATE PREPARE add_is_active_stmt;

SET @add_removed_at = (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE elevenlabs_agents ADD COLUMN removed_at TIMESTAMP NULL AFTER is_active',
    'SELECT 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'elevenlabs_agents'
    AND COLUMN_NAME = 'removed_at'
);

PREPARE add_removed_at_stmt FROM @add_removed_at;
EXECUTE add_removed_at_stmt;
DEALLOCATE PREPARE add_removed_at_stmt;

SET @drop_old_external_index = (
  SELECT IF(
    COUNT(*) > 0,
    'ALTER TABLE elevenlabs_agents DROP INDEX idx_elevenlabs_agents_external_id',
    'SELECT 1'
  )
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'elevenlabs_agents'
    AND INDEX_NAME = 'idx_elevenlabs_agents_external_id'
);

PREPARE drop_old_external_index_stmt FROM @drop_old_external_index;
EXECUTE drop_old_external_index_stmt;
DEALLOCATE PREPARE drop_old_external_index_stmt;

SET @add_unique_external_index = (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE elevenlabs_agents ADD UNIQUE KEY uq_elevenlabs_agents_external_id (elevenlabs_agent_id)',
    'SELECT 1'
  )
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'elevenlabs_agents'
    AND INDEX_NAME = 'uq_elevenlabs_agents_external_id'
);

PREPARE add_unique_external_index_stmt FROM @add_unique_external_index;
EXECUTE add_unique_external_index_stmt;
DEALLOCATE PREPARE add_unique_external_index_stmt;

SET @add_user_active_index = (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE elevenlabs_agents ADD KEY idx_elevenlabs_agents_user_active (user_id, is_active)',
    'SELECT 1'
  )
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'elevenlabs_agents'
    AND INDEX_NAME = 'idx_elevenlabs_agents_user_active'
);

PREPARE add_user_active_index_stmt FROM @add_user_active_index;
EXECUTE add_user_active_index_stmt;
DEALLOCATE PREPARE add_user_active_index_stmt;
