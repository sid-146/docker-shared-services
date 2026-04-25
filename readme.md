use this command to execute sql script for the user creation.

For powershell  
`Get-Content postgres-init\01-setup-mlflow.sql | docker exec -i postgres-main psql -U admin -d default_db`

for cmd
`docker exec -i postgres-main psql -U admin -d default_db < postgres-init\01-setup-mlflow.sql`
