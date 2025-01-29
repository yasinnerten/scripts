#!/bin/bash

#SECRETS:
${SERVER_IP}
${NOTIFICATION_MAIL}
${NOTIFICATION_MAIL_SOURCE}

#ORIGINAL SCRIPT:
NFS_SERVER="${SERVER_IP}"
BACKUP_DIR="/DOCKER-DATA/GitLab/data/backups"
NFS_SHARE="/BACKUP/GitLab" # on target server
MOUNT_DIR="/mnt" # on source server
 
A="/usr/local/bin/docker-compose -f /DOCKER-DATA/GitLab/docker-compose.yml exec -T gitlab-omnibus gitlab-backup create SKIP=artifacts,registry"
 
if $A ; then
    echo Backup and cleaning successfully
else
    echo Gitlab backup failed | mail -s "Gitlab Backup failed" -r \<${NOTIFICATION_MAIL_SOURCE}\> \<${NOTIFICATION_MAIL}\>
fi
 
# Mount operation
if mount -t nfs $NFS_SERVER:$NFS_SHARE $MOUNT_DIR; then
    echo Mount Success
else
   echo  Mount failed | mail -s "Gitlab Backup Nfs Notification" -r \<${NOTIFICATION_MAIL_SOURCE}\> \<${NOTIFICATION_MAIL}\>
fi
 
# NFS file transfer
if cp -rn "$BACKUP_DIR/"* "$MOUNT_DIR/"; then
    echo Copy Success
 
   # List backup files older than 1 day
   BACKUP_FILES=$(find "$BACKUP_DIR" -type f -mtime +1)
 
   # Delete old backup files
   rm -f "$BACKUP_FILES"
else
    echo Copy failed | mail -s "Gitlab Backup Nfs Notification" -r \<${NOTIFICATION_MAIL_SOURCE}\> \<${NOTIFICATION_MAIL}\>
fi
 
# Unmount operation
if umount $MOUNT_DIR; then
    echo Unmount Success
else
    echo Unmount failed | mail -s "Gitlab Backup Nfs Notification" -r \<${NOTIFICATION_MAIL_SOURCE}\> \<${NOTIFICATION_MAIL}\>
fi
