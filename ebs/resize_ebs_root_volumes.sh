#!/bin/bash
instance_id=$2
size=$3
region=$4

get_root_volume_id(){
    echo "[$(date +%FT%T)] - Getting root device"
    
    root_device=$(aws ec2 describe-instances \
        --region "$region" \
        --instance-ids $instance_id \
        --output text \
    --query 'Reservations[*].Instances[*].RootDeviceName')
    
    old_volume_id=$(aws ec2 describe-instances \
        --region "$region" \
        --instance-ids $instance_id \
        --output text \
    --query 'Reservations[*].Instances[*].BlockDeviceMappings[?DeviceName==`'$root_device'`].[Ebs.VolumeId]')
    
    zone=$(aws ec2 describe-instances \
        --region "$region" \
        --instance-ids $instance_id \
        --output text \
    --query 'Reservations[*].Instances[*].Placement.AvailabilityZone')
    
    echo "[$(date +%FT%T)] - Instance $instance_id in $zone with original volume $old_volume_id"
}

stop_instance(){
    echo "[$(date +%FT%T)] - Stopping $instance_id in $zone with original volume"
    aws ec2 stop-instances \
    --region "$region" \
    --instance-ids $instance_id
    echo "[$(date +%FT%T)] - Stoping $instance_id..."
    aws ec2 wait instance-stopped \
    --region "$region" \
    --instance-ids $instance_id
}

detach_old_volume(){
    echo "[$(date +%FT%T)] - Detaching volume from $instance_id on region $region"
    aws ec2 detach-volume \
    --region "$region" \
    --volume-id "$old_volume_id"
}

create_old_volume_snapshot(){
    echo "[$(date +%FT%T)] - Creating snapshot from original volume $old_volume_id in region $region"
    snapshot_id=$(aws ec2 create-snapshot \
        --region "$region" \
        --volume-id "$old_volume_id" \
        --output text \
    --query 'SnapshotId')
    
    echo "[$(date +%FT%T)] - Waiting snapshot to complete..."
    
    aws ec2 wait snapshot-completed \
    --region "$region" \
    --snapshot-ids "$snapshot_id"
    echo "[$(date +%FT%T)] - Snapshot created ID: $snapshot_id"
}

create_new_volume(){
    new_volume_id=$(aws ec2 create-volume \
        --region "$region" \
        --availability-zone "$zone" \
        --size "$size" \
        --snapshot "$snapshot_id" \
        --output text \
    --query 'VolumeId')
    echo "[$(date +%FT%T)] - Creating new volume: $new_volume_id"
}

attach_new_volume(){
    echo "[$(date +%FT%T)] - Attaching volume to instance $instance_id on root $root_device on $region"
    
    aws ec2 attach-volume \
    --region "$region" \
    --instance "$instance_id" \
    --device "$root_device" \
    --volume-id "$new_volume_id"
    
    echo "[$(date +%FT%T)] - Waiting volume to be available..."
    
    aws ec2 wait volume-in-use \
    --region "$region" \
    --volume-ids "$new_volume_id"
}

start_instance(){
    echo "[$(date +%FT%T)] - Starting instance $instance_id on $region"
    aws ec2 start-instances \
    --region "$region" \
    --instance-ids "$instance_id"
    echo "[$(date +%FT%T)] - Waiting instance $instance_id... on $region"
    aws ec2 wait instance-running \
    --region "$region" \
    --instance-ids "$instance_id"
    aws ec2 describe-instances \
    --region "$region" \
    --instance-ids "$instance_id"
}

delete_old_volume(){
    echo "[$(date +%FT%T)] - Delete old volume $old_volume on $region"
    aws ec2 delete-volume \
    --region "$region" \
    --volume-id "$old_volume_id"
    aws ec2 delete-snapshot \
    --region "$region" \
    --snapshot-id "$snapshot_id"
}

case "$1" in
    "--resize")
        get_root_volume_id
        stop_instance
        detach_old_volume
        create_old_volume_snapshot
        create_new_volume
        attach_new_volume
        start_instance
        delete_old_volume
    ;;
    *)
        echo "Usage: ./resize_ebs_root_volume.sh --resize <instance_id> <new_volume_size> <aws_region>"
    ;;
esac


