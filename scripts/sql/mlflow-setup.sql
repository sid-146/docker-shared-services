-- 1. Create the dedicated MLflow user if it does not exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'mlflow') THEN
    CREATE USER mlflow WITH PASSWORD 'mlflowpass';
  END IF;
END
$$;

-- 2. Create the database if it does not exist
-- (We generate the CREATE command as a string, and \gexec tells psql to execute that string)
SELECT 'CREATE DATABASE mlflowdb OWNER mlflow'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'mlflowdb')\gexec

-- 3. Grant privileges
-- (GRANT commands are naturally idempotent, so they don't need IF EXISTS checks.
-- They will just silently succeed if the permissions are already there).
GRANT ALL PRIVILEGES ON DATABASE mlflowdb TO mlflow;
-- GRANT ALL PRIVILEGES ON DATABASE mlflow_db TO admin;
