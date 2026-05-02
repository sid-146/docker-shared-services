DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'doc_agent_user') THEN
    CREATE USER doc_agent_user WITH PASSWORD 'doc_agent_password';
  END IF;
END
$$;

-- 2. Create the database if it does not exist
-- (We generate the CREATE command as a string, and \gexec tells psql to execute that string)
SELECT 'CREATE DATABASE doc_agents_db OWNER doc_agent_user'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'doc_agents_db')\gexec

-- 3. Grant privileges
-- (GRANT commands are naturally idempotent, so they don't need IF EXISTS checks.
-- They will just silently succeed if the permissions are already there).
GRANT ALL PRIVILEGES ON DATABASE doc_agents_db TO doc_agent_user;