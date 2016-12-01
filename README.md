# check_nfs_mount
Check if eveything is fine with the NFS mounts.

In case an unmounted file system is found, remount it.

You can cron the check to make sure all your filesystems are up. For example to run it every minute:
```
*/1 * * * * /usr/local/bin/check_nfs_mount.sh
```
