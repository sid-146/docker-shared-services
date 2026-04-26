DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'litellm_user') THEN
    CREATE USER litellm_user WITH PASSWORD 'litellm_password';
  END IF;
END
$$;

-- 2. Create the database if it does not exist
-- (We generate the CREATE command as a string, and \gexec tells psql to execute that string)
SELECT 'CREATE DATABASE litellm_db OWNER litellm_user'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'litellm_db')\gexec

-- 3. Grant privileges
-- (GRANT commands are naturally idempotent, so they don't need IF EXISTS checks.
-- They will just silently succeed if the permissions are already there).
GRANT ALL PRIVILEGES ON DATABASE litellm_db TO litellm_user;