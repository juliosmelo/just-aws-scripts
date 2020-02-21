#!/bin/bash
set -e

db_instance_identifier=$2
db_snapshot_identifier=$3
vpc_id=$4
db_instance_class=$5

restore_from_snapshot(){
    echo "[$(date +%FT%T)] - Starting restoring the snapshot $db_snapshot_identifier"
    echo "[$(date +%FT%T)] - Database indentifier $db_instance_identifier"
    
    aws rds restore-db-instance-from-db-snapshot \
    --db-snapshot-identifier "$db_snapshot_identifier" \
    --no-publicly-accessible --vpc-security-group-ids "$vpc_id" \
    --deletion-protection --db-name "$db_name" \
    --db-instance-identifier "$db_instance_identifier" \
    --db-instance-class "$db_instance_class"
    
    echo "[$(date +%FT%T)] - Waiting database to be available $db_instance_identifier"
    echo "[$(date +%FT%T)] - Database indentifier $db_instance_identifier"
    
    aws rds wait db-instance-available --db-instance-identifier "$db_instance_identifier"
    echo "[$(date +%FT%T)] - Done $db_instance_identifier"
}

case "$1" in
    --restore)
        restore_from_snapshot
    ;;
    *)
        echo "Usage: $0 --restore <db_instance_identifier> <db_snapshot_identifier> <vpc_id> <db_instance_class>"
    ;;
esac
