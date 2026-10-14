-- 1. Create the dedicated Folioman user if it does not exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'folioman') THEN
    CREATE USER folioman WITH PASSWORD 'folioman-db-password';
  END IF;
END
$$;

-- 2. Create the databases if they do not exist
SELECT 'CREATE DATABASE folioman OWNER folioman'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'folioman')\gexec

SELECT 'CREATE DATABASE "folioman-client" OWNER folioman'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'folioman-client')\gexec

-- 3. Grant privileges
GRANT ALL PRIVILEGES ON DATABASE folioman TO folioman;
GRANT ALL PRIVILEGES ON DATABASE "folioman-client" TO folioman;
