# backup_diff

`backup_diff` is a bash differential rsync backup script. The destination can be local or remote.

`backup_diff` uses the `--link-dest` option of `rsync` to hard link unchanged files (no space used).

`backup_diff` looks for a previous backup in the destination directory to create this link. If no previous backup is found a full backup is then performed.

## Example

```bash
    backup_diff.sh -S backup-server.org /home/bellembois/workspace /backup/bellembois
```

Backups the `/home/bellembois/workspace` directory on `backup-server.org` in `/backup/bellembois`.

Running this script every hour will create the following directories:

```bash
    drwxr-xr-x   3 root root  4096 Mar 25 07:01 workspace_20160325-080001
    drwxr-xr-x   3 root root  4096 Mar 25 08:01 workspace_20160325-090001
    drwxr-xr-x   3 root root  4096 Mar 25 09:01 workspace_20160325-100001
    drwxr-xr-x   3 root root  4096 Mar 25 10:01 workspace_20160325-110001
    drwxr-xr-x   3 root root  4096 Mar 25 11:01 workspace_20160325-120001
    ...
```

## Usage

```bash
    backup_diff [-S server_name][-U server_user][-d][-f][-v] SOURCE DESTINATION
```
- `-U`: the server username to log with, default=`root`
- `-S`: the FQDN of the server to backup
- `-v`: debug mode
- `-d`: dry-run, simulate the backup
- `-f`: force, forces the backup even if the destination directory already contains files of directories not related to previous backup

    This option is required to perform several different backups in the same destination directory.

## Dependencies

`rsync`, `ssh`, `notify-send`

## Limitations

- the backup can not performed from a remote to a local directory (planned)

## Roadmap

- remote to local backup
- mail notification on errors
