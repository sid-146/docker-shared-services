-- 1. Create the dedicated Langfuse user if it does not exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'langfuse_user') THEN
    CREATE USER langfuse_user WITH PASSWORD 'langfuse_password';
  END IF;
END
$$;

-- 2. Create the database if it does not exist
SELECT 'CREATE DATABASE langfuse_db OWNER langfuse_user'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'langfuse_db')\gexec

-- 3. Grant privileges
GRANT ALL PRIVILEGES ON DATABASE langfuse_db TO langfuse_user;
