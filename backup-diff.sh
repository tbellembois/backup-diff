#!/bin/bash - 
set -o nounset                              # Treat unset variables as an error

function show_help() {

    echo "$0 [-S server_name][-U server_user][-d][-f][-v][-k] SOURCE DESTINATION"
    echo " "
    echo "    SOURCE = the source directory to backup, with NO trailing /"
    echo "    DESTINATION = the backup directory, with a trailing /"
    echo "    -v = debug mode"
    echo "    -e = rsync ssh command"
    echo "    -S = the FQDN of the server to backup"
    echo "    -U = the server username to log with, default=root"
    echo "    -d = dry run, simulate the backup"
    echo "    -f = force, forces the backup even if the destination directory already contains files of directories not related to previous backup"
}

if [ ! "$#" -ge 2 ]
then
    show_help
    exit 1
fi

#
# default arguments
#
SERVER_NAME=""
SERVER_USER="root"
FORCE=false
DRYRUN=""
REMOTE=false
VERBOSE=false
RSYNC_VERBOSE=""
SSH_COMMAND="/usr/bin/ssh"

#
# parsing options
#
OPTIND=1
while getopts "S:U:e:fdv" opt; do
  case $opt in
    S ) SERVER_NAME=$OPTARG
      ;;
    e ) SSH_COMMAND=$OPTARG
      ;;
    U ) SERVER_USER=$OPTARG
      ;;
    f ) FORCE=true
      ;;
    v ) VERBOSE=true
      ;;
    d ) DRYRUN="--dry-run"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

#
# arguments
#
BACKUP_SOURCE=${@:$OPTIND:1}
BACKUP_DEST_DIR=${@:$OPTIND+1:1}

#
# contants
#
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_SOURCE_DIRNAME=$(basename "$BACKUP_SOURCE")
BACKUP_NAME="$BACKUP_SOURCE_DIRNAME"_"$DATE"
BACKUP_DEST="$BACKUP_DEST_DIR""$BACKUP_NAME"
BACKUP_NAME_REGEX=".*/""$BACKUP_SOURCE_DIRNAME""_[0-9]\{8\}-[0-9]\{6\}"


if [ "$VERBOSE" = true ]; then
    echo "BACKUP_SOURCE: $BACKUP_SOURCE"
    echo "BACKUP_DEST_DIR: $BACKUP_DEST_DIR"
    echo "BACKUP_SOURCE_DIRNAME: $BACKUP_SOURCE_DIRNAME"
    echo "BACKUP_NAME: $BACKUP_NAME"
    echo "BACKUP_DEST: $BACKUP_DEST"
    echo "BACKUP_NAME_REGEX: $BACKUP_NAME_REGEX"
    echo "SERVER_NAME: $SERVER_NAME"
    echo "SERVER_USER: $SERVER_USER"
    RSYNC_VERBOSE="--verbose"
fi

#
# arguments syntax check
#
echo "#### Checking script arguments syntax ####"
echo "-> BACKUP_SOURCE: $BACKUP_SOURCE"
if [[ $BACKUP_SOURCE =~ ^/[a-zA-Z0-9_/-]+[^/]$ ]]; then
    echo "   syntax looks to be ok... "
else
    echo "   is NOT a valid directory name ! Leaving..."
    exit 1
fi
echo "-> BACKUP_DEST_DIR: $BACKUP_DEST_DIR"
if [[ $BACKUP_DEST_DIR =~ ^/[a-zA-Z0-9_/-]+/$ ]]; then
    echo "   syntax looks to be ok... "
else
    echo "   is NOT a valid directory name ! Leaving..."
    exit 1
fi

#
# local or distant backup
#
if [ ${#SERVER_NAME} -ge 1 ]; then
    echo "#### Remote backup configured ####"
    echo "#### Checking remote access ####"
    echo "-> server $SERVER_NAME with user $SERVER_USER"

    if (ssh $SERVER_USER@$SERVER_NAME 'echo "test"'); then
        echo "Looks good."
    else
        echo "Can NOT access $SERVER_NAME with user $USER_NAME"
        exit 1
    fi
    REMOTE=true
else
    echo "#### Local backup configured ####"
fi

#
# test if source directory exists
#
echo "#### Testing source directory ####"
if [ ! -d "$BACKUP_SOURCE" ]; then
    echo "Source directory $BACKUP_SOURCE_DIRNAME does not exists !"
    exit 1
fi
echo "-> ok"

#
# test if destination directory exists
#
echo "#### Testing destination directory ####"
if [ "$REMOTE" = true ]; then
    if ( ssh -q $SERVER_USER@$SERVER_NAME "[ ! -d \"$BACKUP_DEST_DIR\"" ] ); then
        echo "Destination directory $BACKUP_DEST_DIR does not exists on server $SERVER_NAME !"
        exit 1
    fi
else
    if [ ! -d "$BACKUP_DEST_DIR" ]; then
        echo "Destination directory $BACKUP_DEST_DIR does not exists !"
        exit 1
    fi
fi
echo "-> ok"

function full_backup() {

    echo "-> performing a full backup."
    echo "-> backup destination: $BACKUP_DEST"
    
    if [ "$REMOTE" = true ]; then
        echo "-> remote destination: $SERVER_NAME"
    
        rsync --archive \
              --one-file-system \
              --hard-links \
              --human-readable \
              --inplace \
              --numeric-ids \
              $RSYNC_VERBOSE \
              --progress \
              $DRYRUN \
              $SSH_COMMAND \
              $BACKUP_SOURCE \
              $SERVER_USER@$SERVER_NAME:$BACKUP_DEST 

    else
        
        rsync --archive \
              --one-file-system \
              --hard-links \
              --human-readable \
              --inplace \
              --numeric-ids \
              $RSYNC_VERBOSE \
              --progress \
              $DRYRUN \
              $SSH_COMMAND \
              $BACKUP_SOURCE \
              $BACKUP_DEST 

    fi

    return $?

}

function linked_backup() {

    echo "-> Performing a linked backup."

    if [ "$REMOTE" = true ]; then
        echo "-> remote destination: $SERVER_NAME"

        rsync --archive \
              --one-file-system \
              --hard-links \
              --human-readable \
              --inplace \
              --numeric-ids \
              $RSYNC_VERBOSE \
              --progress \
              --link-dest=$REFERENCE \
              $DRYRUN \
              $SSH_COMMAND \
              $BACKUP_SOURCE \
              $SERVER_USER@$SERVER_NAME:$BACKUP_DEST

    else

        rsync --archive \
              --one-file-system \
              --hard-links \
              --human-readable \
              --inplace \
              --numeric-ids \
              $RSYNC_VERBOSE \
              --progress \
              --link-dest=$REFERENCE \
              $DRYRUN \
              $SSH_COMMAND \
              $BACKUP_SOURCE \
              $BACKUP_DEST

    fi

    return $?

}

# test if the destination directory is empty
echo "#### Testing destination directory content ####"
if [ "$REMOTE" = true ]; then

        if ( ssh -q $SERVER_USER@$SERVER_NAME "find \"$BACKUP_DEST_DIR\" -maxdepth 0 -empty | read v" ); then
            echo "Destination directory $BACKUP_DEST_DIR is empty on server $SERVER_NAME."

            r=$(full_backup)
            if [[ $? -gt 0 ]] 
            then
                echo $r
                exit 1
            else
                exit 0
            fi

        fi
else

    if find "$BACKUP_DEST_DIR" -maxdepth 0 -empty | read v; then
        echo "The destination directory $BACKUP_DEST_DIR is empty."

        r=$(full_backup)
        if [[ $? -gt 0 ]] 
        then
            echo $r
            exit 1
        else
            exit 0
        fi

    fi

fi
echo "-> directory not empty"

# getting the last backup
#- %T@ gives you the modification time like a unix timestamp
#- sort -n sorts numerically
#- tail -1 takes the last line (highest timestamp)
#- cut -f2 -d" " cuts away the first field (the timestamp) from the output.
echo "#### Looking for a previous backup ####"
REFERENCE_CMD="find \"$BACKUP_DEST_DIR\" -maxdepth 1 -regextype sed -regex \"$BACKUP_NAME_REGEX\" -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d' '"

if [ "$VERBOSE" = true ]; then
    echo "REFERENCE_CMD: $REFERENCE_CMD"
fi

if [ "$REMOTE" = true ]; then
    REFERENCE=$(ssh -q $SERVER_USER@$SERVER_NAME "$REFERENCE_CMD")
else
    REFERENCE=$(eval $REFERENCE_CMD)
fi

echo "->reference:$REFERENCE"

# checking the find output
if [[ $REFERENCE =~ ^[a-zA-Z0-9_/-]+$ ]]; then
    echo "Found the last reference backup: $REFERENCE."

    r=$(linked_backup)
    if [[ $? -gt 0 ]] 
    then
        echo $r
        exit 1
    else
        exit 0
    fi
    
else
    echo "The destination directory $BACKUP_DEST_DIR is NOT empty but does NOT contain previous backups."   

    if [ "$FORCE" = true ] ; then
        echo "Force option detected"
	    r=$(full_backup)
        if [[ $? -gt 0 ]] 
        then
            echo $r
            exit 1
        else
            exit 0
        fi
    else
	    echo "Leaving... (use -f to force backup)"
    fi
    exit 0
fi

#echo $BACKUP_DEST_DIR
#echo $BACKUP_NAME_REGEX

