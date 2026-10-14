-- 1. Create the dedicated Curio user if it does not exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'curio') THEN
    CREATE USER curio WITH PASSWORD 'curio';
  END IF;
END
$$;

-- 2. Create the database if it does not exist
SELECT 'CREATE DATABASE curio_db OWNER curio'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'curio_db')\gexec

-- 3. Grant privileges
GRANT ALL PRIVILEGES ON DATABASE curio_db TO curio;
