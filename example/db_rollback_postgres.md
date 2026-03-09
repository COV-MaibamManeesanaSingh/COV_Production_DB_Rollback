### Postgres DB Rollback

-- Pre-requisite for Database Recovery

1. Use `pg_basebackup` cli to make a backup - this could be in .tar or in plain folder/files
2.

3. Enable WAL Archiving

-- update the archive_location
Edit postgresql.conf

```
# Settings for Production
archive_mode = on
archive_command = 'cp %p /var/lib/postgresql/backups/wal_archive/%f'
wal_level = replica
```

3. Take a Base Backup
   -- Run inside the container as the postgres user

```bash
pg_basebackup -D /var/lib/postgresql/backups/full_snapshot -F p -P -U postgres
```

[SIMULATE THE DISASTER]

```sql
-- 1. SETUP
DROP DATABASE IF EXISTS prod_sales;
CREATE DATABASE prod_sales;
-- \c prod_sales

-- 2. THE "GOOD" STATE
CREATE TABLE orders (
  order_id INT PRIMARY KEY,
  customer_name VARCHAR(30),
  amount DECIMAL(10,2),
  order_date TIMESTAMP NOT NULL
);

INSERT INTO orders (order_id, customer_name, amount, order_date)
VALUES (1, 'Alice', 150.00, '2026-03-01 14:00:00'),
       (2, 'Bob', 200.00, '2026-03-01 16:30:00');

-- Capture Safe Point
SELECT now() AS safe_point_in_time;
-- Assume: '2026-03-05 16:00:00'

------
-- DISASTER
-- Oops! Someone forgot a WHERE clause
UPDATE orders SET amount = 0.00;

-- This record was created AFTER the safe point and will be lost in the rollback

INSERT INTO orders (order_id, customer_name, amount, order_date)
VALUES (3, 'NEW_USER_AFTER_DISASTER', 800.00, '2026-03-01 14:00:00'),

```

--- At this point, we already have a backup and WAL log files

---

1. Create a backup folder: `mkdir /var/lib/postgres/recovered_db`
2. Update ownership `chown postgres:postgres /var/lib/postgresql/recovered_db`
3. Restore the Physical Backup:
   `tar -xvf /backups/base_backup.tar.gz -C /var/lib/postgresql/recovered_db`
   OR
   `cp -a /backups/full_snapshot/. /var/lib/postgresql/recovered_db`
4. Configure Poin-in-Time Recovery (PITR):

# Settings for the recovered instance

```
port = 5433 # Must be different from Prod (5433)
listen_addresses = '*'
restore_command = 'cp /var/lib/postgres/backups/wal_archive/%f %p'
recovery_target_time = '2026-03-02 11:40:08'
recovery_target_action = 'promote' # Once reached, make the DB writable
```

5. Add the recovery signal:

```bash
touch /var/lib/postgresql/recovered_db/signal.recovery
```

6. Start the new instance:

```bash
su - postgres
pg_ctl -D /var/lib/postgresql/recovered_db/ -l /var/lib/postgresql/recovered_db/recovery.log  start

```
