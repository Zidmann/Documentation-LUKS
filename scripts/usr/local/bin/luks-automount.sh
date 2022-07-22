#!/bin/bash

##################################################################################
## AUTHOR : Emmanuel ZIDEL-CAUFFET - Zidmann (emmanuel.zidel@gmail.com)
##################################################################################
## 2022/07/08 - First release of the script
##################################################################################

##################################################################################
# Beginning of the script - definition of the variables
##################################################################################
SCRIPT_VERSION="0.0.1"

# Load the configuration with the variables
CONF_DIR="/etc/luks-automount/common.cfg"
source "$CONF_DIR"

##################################################################################
# Auxiliary functions
function secure_dir_permission(){
	local DIR=$1
	chown root:root "$DIR"
	chmod 700 "$DIR"
}

function process_dir_parameter(){
	local NAME=$1
	local VALUE=$2
	if [ "$VALUE" == "" ]
	then
		echo "[-] Error - parameter $NAME is empty"
		exit 1
	fi
	if [ ! -d "$VALUE" ]
	then
		echo "[-] Error - the directory defined by $NAME ($VALUE) does not exist"
		exit 1
	fi

	secure_dir_permission "$VALUE"
}

function check_configuration(){
	process_dir_parameter "LOG_DIR" "$LOG_DIR"
	process_dir_parameter "HEADER_DIR" "$HEADER_DIR"
	process_dir_parameter "KEY_DIR" "$KEY_DIR"
}

function get_device_info(){
	local DEVICE=$1
	local PARAMETER=$2
	/sbin/blkid "$DEVICE" --output export | /bin/grep "^$PARAMETER=" | /bin/awk 'BEGIN{FS="="}{print $2}'
}

function get_filesystem_type(){
	local DEVICE=$1
	get_device_info "$DEVICE" "TYPE"
}

function get_uuid(){
	local DEVICE=$1
	get_device_info "$DEVICE" "PARTUUID"
}

function is_empty_dir(){
	local DIR=$1
	/usr/bin/find "$DIR" -maxdepth 0 -type d -empty | /bin/head -n1 | /bin/wc -l
}

function is_mounted_dir(){
	local DIR=$1
	/bin/awk -v vDIR="$DIR" 'BEGIN{FS=" "}{if($2==vDIR){print 1}}' /etc/mtab | /bin/head -n1 | /bin/wc -l
}

function clear_media_dir(){
	# Check if the media directory is empty
	IS_EMPTY=$(is_empty_dir "/media")
	if [[ "$IS_EMPTY" == "1" ]]
	then
		return
	fi
	
	# Clean all the empty directory in /media with no mounted point
	for DIR in /media/*;
	do
		IS_EMPTY=$(is_empty_dir "$DIR")
		if [[ "$IS_EMPTY" == "1" ]]
		then
			IS_MOUNTED=$(is_mounted_dir "$DIR")
			if [[ "$IS_MOUNTED" == "0" ]]
			then
				/bin/rmdir "$DIR"
			fi
		fi
	done
}

function send_notification(){
	local MSG=$1

	for USER in "${NOTIFICATION_USERS[@]}";
	do
		su - "$USER" -c "DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus notify-send \"$MSG\""
	done
}

function archive_log(){
	local DIR=$1
	local PERIOD=$2
	find "$DIR" -maxdepth 1 -type f -mtime "+$PERIOD" -exec zip {} \;
}

function delete_log(){
	local DIR=$1
	local PERIOD=$2
	find "$DIR" -maxdepth 1 -type f -mtime "+$PERIOD" -exec rm {} \;
}

function process_log(){
	archive_log "$LOG_DIR" "$LOG_ARCHIVE"
	delete_log "$LOG_DIR" "$LOG_RETENTION"
}

##################################################################################
# Main functions
function do_mount(){
	local DEVBASE=$1
	local DEVICE
	local UUID
	local TYPE
	local MAPPER
	local DEVICEMAPPER
	local MOUNTDIR

	clear_media_dir

	DEVICE="/dev/$DEVBASE"
	UUID=$(get_uuid "$DEVICE")
	echo "DEVICE=$DEVICE"
	echo "UUID=$UUID"

	KEYFILE="$KEY_DIR/$UUID.key"
	HEADERFILE="$HEADER_DIR/$UUID.header"

	if [[ ! -f "$KEYFILE" ]] && [[ ! -f "$HEADERFILE" ]]
	then
		echo "[i] Unknown partition"
		exit 0
	elif [ ! -f "$KEYFILE" ]
	then
		echo "[-] No LUKS key file found for this partition"
		send_notification "Device $DEVICE - no key found (UUID=$UUID)"
		exit 1
	elif [ ! -f "$HEADERFILE" ]
	then
		echo "[-] No LUKS header file found for this partition"
		send_notification "Device $DEVICE - no header found (UUID=$UUID)"
		exit 1
	fi

	TYPE=$(get_filesystem_type "$DEVICE")
	echo "TYPE=$TYPE"
	if [ "$TYPE" != "" ]
	then
		echo "[i] The partition has been replaced by a classical"
		return
	fi

	OPTS="rw,relatime"
	MAPPER="${DEVBASE}_crypt"
	DEVICEMAPPER="/dev/mapper/$MAPPER"
	MOUNTDIR="/media/${DEVBASE}_crypt"
	echo "MAPPER=$MAPPER"
	echo "DEVICEMAPPER=$DEVICEMAPPER"
	echo "MOUNTDIR=$MOUNTDIR"
	/bin/mkdir "$MOUNTDIR"
	/sbin/cryptsetup luksOpen "$DEVICE" "$MAPPER" --key-file "$KEYFILE" --header "$HEADERFILE"
	/bin/mount -o "$OPTS" "$DEVICEMAPPER" "$MOUNTDIR"

	send_notification "Device $DEVICE - secret LUKS volume opened (UUID=$UUID)"
	process_log
}

function do_unmount(){
	local DEVBASE=$1
	local DEVICE
	local MAPPER
	local DEVICEMAPPER
	local MOUNTDIR

	DEVICE="/dev/$DEVBASE"
	MAPPER="${DEVBASE}_crypt"
	DEVICEMAPPER="/dev/mapper/$MAPPER"
	MOUNTDIR="/media/${DEVBASE}_crypt"
	echo "DEVICE=$DEVICE"
	echo "MAPPER=$MAPPER"
	echo "DEVICEMAPPER=$DEVICEMAPPER"
	echo "MOUNTDIR=$MOUNTDIR"
	/bin/umount "$MOUNTDIR"
	/bin/rmdir "$MOUNTDIR"
	/sbin/cryptsetup luksClose "$DEVICEMAPPER"
	
	send_notification "Device $DEVICE - secret LUKS volume removed (UUID=$UUID)"
	clear_media_dir
	process_log
}

function unknown_command() {
	echo "[-] Unknown command"
	clear_media_dir
	process_log
}

##################################################################################
# Check if the configuration is valid, otherwise the script is stopped
check_configuration

##################################################################################
# Start to process the data
ACTION=$1
DEVBASE=$2

TODAYDATE="$(date +%Y%m%d)"
TODAYTIME="$(date +%H%M%S)"

/bin/mkdir -p "$LOG_DIR"
LOG_PATH="$LOG_DIR/$TODAYDATE.$TODAYTIME.$ACTION.log"

##################################################################################
case "${ACTION}" in
    add)
        do_mount "$DEVBASE" > >(tee "$LOG_PATH") 2>&1
        ;;
    remove)
        do_unmount "$DEVBASE" > >(tee "$LOG_PATH") 2>&1
        ;;
    **)
        LOG_PATH="$LOG_DIR/$TODAYDATE.$TODAYTIME.log"
        unknown_command > >(tee "$LOG_PATH") 2>&1
        ;;
esac
##################################################################################
