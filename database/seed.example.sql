USE elevenlabs_agents_db;

INSERT INTO telegram_users (
  telegram_id,
  username,
  first_name,
  last_name,
  state
) VALUES (
  123456789,
  'telegram_username_placeholder',
  'FirstNamePlaceholder',
  'LastNamePlaceholder',
  'idle'
);

INSERT INTO elevenlabs_agents (
  user_id,
  elevenlabs_agent_id,
  display_name,
  current_prompt,
  welcome_message
) VALUES (
  1,
  'elevenlabs_agent_id_placeholder',
  'Example Agent',
  'Prompt placeholder for the selected ElevenLabs voice agent.',
  'Welcome message placeholder.'
);

UPDATE telegram_users
SET selected_agent_id = 1
WHERE id = 1;

INSERT INTO agent_knowledge_documents (
  agent_id,
  elevenlabs_document_id,
  title,
  source_type,
  source_url,
  status
) VALUES (
  1,
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
  1,
  1,
  'prompt_update',
  'Previous prompt placeholder.',
  'Prompt placeholder for the selected ElevenLabs voice agent.',
  'success'
);
