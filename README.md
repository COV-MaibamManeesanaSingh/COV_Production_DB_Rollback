### Production DB Rollback

### PosgresSQL DB Backup

1. `su - postgres`
2. `pg_basebackup -D /backups/full_backup -W`
   -U postgres: Tells the utility to use the correct database role.

-W: Forces a password prompt (if you have one set).

3. `mkdir -p /var/lib/postgresql/recovered_prod_db`
4. Fix ownership just in case
   chown -R postgres:postgres /var/lib/postgresql/recovered_prod

5. # Create the signal file
   touch /var/lib/postgresql/recovered_prod/signal.recovery

# Edit the configuration (using a text editor or a simple append)

# We need to change the PORT so it doesn't clash with Production (5432)

cat >> /var/lib/postgresql/recovered_prod_db/postgresql.conf <<EOF
port = 5433
restore_command = 'cp /var/lib/postgresql/backups/wal_archive/%f %p'
recovery_target_time = '2026-03-05 08:30:00' # Your SAFE point-in-time
recovery_target_action = 'promote'
EOF

Verify your "Tail Backup"
You mentioned you did a tail backup. For Postgres to see those transactions, the WAL files must be in the restore_command path (which I set as /backups/wal_archive above).

Check this: Does /backups/wal_archive contain the most recent files from your pg_switch_wal() command? If not, copy the files from your production pg_wal folder to the archive folder manually before starting.

---

GreatSecret@#7830
