USE elevenlabs_agents_db;

SET @telegram_id_placeholder = 123456789;
SET @elevenlabs_agent_id_placeholder = 'elevenlabs_agent_id_placeholder';

INSERT INTO telegram_users (
  telegram_id,
  username,
  first_name,
  last_name,
  state
) VALUES (
  @telegram_id_placeholder,
  'telegram_username_placeholder',
  'FirstNamePlaceholder',
  'LastNamePlaceholder',
  'idle'
);

SET @telegram_user_db_id = (
  SELECT id
  FROM telegram_users
  WHERE telegram_id = @telegram_id_placeholder
);

INSERT INTO elevenlabs_agents (
  user_id,
  elevenlabs_agent_id,
  display_name,
  current_prompt,
  welcome_message
) VALUES (
  @telegram_user_db_id,
  @elevenlabs_agent_id_placeholder,
  'Example Agent',
  'Prompt placeholder for the selected ElevenLabs voice agent.',
  'Welcome message placeholder.'
);

SET @agent_db_id = (
  SELECT id
  FROM elevenlabs_agents
  WHERE user_id = @telegram_user_db_id
    AND elevenlabs_agent_id = @elevenlabs_agent_id_placeholder
);

UPDATE telegram_users
SET selected_agent_id = @agent_db_id
WHERE telegram_id = @telegram_id_placeholder;

INSERT INTO agent_knowledge_documents (
  agent_id,
  elevenlabs_document_id,
  title,
  source_type,
  source_url,
  status
) VALUES (
  @agent_db_id,
  'elevenlabs_document_id_placeholder',
  'Example Knowledge Document',
  'url',
  'https://example.com/knowledge-document-placeholder',
  'ready'
);

INSERT INTO agent_update_logs (
  agent_id,
  telegram_user_id,
  action,
  old_value,
  new_value,
  status
) VALUES (
  @agent_db_id,
  @telegram_user_db_id,
  'prompt_update',
  'Previous prompt placeholder.',
  'Prompt placeholder for the selected ElevenLabs voice agent.',
  'success'
);
