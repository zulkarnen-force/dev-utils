Database Backup & Restore (Docker Container)

This script allows you to backup and restore databases running inside Docker containers using container environment variables automatically.

Supported databases:
PostgreSQL
MySQL
MongoDB

Backups are compressed (.gz) and can be uploaded to a remote storage using rclone.

Requirements
Make sure these are installed on the host machine:
Docker
Python 3
rclone (already configured)

Backup Database
Basic Usage (Recommended)

If your database container uses standard environment variables
(e.g. POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB),
you do not need to pass DB credentials.

```
python3 backup_db_container.py \
  --container apollo-junior-go-db \
  --db-type postgres \
  --remote pcloud706:/personal/database/apollo
```

The script will:

Read DB credentials from the container

Create a compressed backup

Upload it to the remote storage

Keep only the latest backups (default: 7 files)

Optional: Override Database Values

You can override values if needed:

python3 backup_db_container.py \
  --container apollo-junior-go-db \
  --db-type postgres \
  --db-name mydb \
  --db-user myuser \
  --db-password mypassword \
  --remote pcloud706:/personal/database/apollo

CLI arguments always have higher priority than container env vars.

Restore Database
1. Download Backup File

First, download the backup from remote storage:

rclone copy pcloud706:/personal/database/apollo/mydb_20260227_120000.sql.gz .

Extract it:

gunzip mydb_20260227_120000.sql.gz
2. Restore PostgreSQL
cat mydb_20260227_120000.sql | docker exec -i apollo-junior-go-db \
  psql -U POSTGRES_USER POSTGRES_DB

Example (explicit):

cat mydb_20260227_120000.sql | docker exec -i apollo-junior-go-db \
  psql -U postgres apollo
3. Restore MySQL
cat mydb_20260227_120000.sql | docker exec -i apollo-mysql-db \
  mysql -u root -p mydb

You will be prompted for the password.

4. Restore MongoDB

If the backup was created using mongodump --archive:

cat mydb_20260227_120000.sql | docker exec -i apollo-mongo-db \
  mongorestore --archive --drop
Retention Policy

By default, the script keeps 7 latest backups.

You can change it:

--retention 14
Notes

The container must be running

Backup is created outside the container (host temp directory)

Restore commands overwrite existing data

Always verify the target database before restoring

Example Use Case

Daily cron backup:

0 2 * * * python3 /opt/backup/backup_db_container.py \
  --container apollo-junior-go-db \
  --db-type postgres \
  --remote pcloud706:/personal/database/apollo