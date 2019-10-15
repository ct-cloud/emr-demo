#!/bin/bash
# to scan unused disk and mount to /data/disk* as default

function disk_scan() {
  echo "********* scanning unmount disk... *********"
  ALL_DISK=`fdisk -l | grep -Ev "mapper|root|swap|docker" |grep ^"Disk /"|cut -d ' ' -f2 |cut -d: -f1`
  DISK_TO_MOUNT=()
  for i in ${ALL_DISK}
  do 
      IS_EXIST=`df -Th | grep ${i} | wc -l`
      if [[ ${IS_EXIST} -eq '0' ]]; then
        DISK_TO_MOUNT=(${DISK_TO_MOUNT[@]} ${i})
      fi
  done
  echo "********* found unused disk ${DISK_TO_MOUNT[@]} *********"
}

function part_format() {
  for i in ${DISK_TO_MOUNT[@]}
  do
     parted -s "${i}" mklabel gpt
     parted -a optimal -s "${i}" mkpart primary 0% 100% 
     partprobe ${i}
     echo -e "********* disk ${i} partition done *********"
     sleep 1
     mkfs.xfs -f "${i}1" 1> /dev/null
     echo "********* mkfs.xfs done *********"
  done 
}

function disk_mount() {
  MOUNT_PARENT_DIR="/data"
  DISK_INDEX=1
  for i in ${DISK_TO_MOUNT[@]}
  do 
     MOUNT_DIR="${MOUNT_PARENT_DIR}/disk${DISK_INDEX}"
     echo "********* starting to mount Partition ${i}1 to dir ${MOUNT_DIR} *********"
     if [[ ! -d "${MOUNT_DIR}" ]];then
     	startup_auto_mount "${i}1" "${MOUNT_DIR}"
     else
	read -p "${MOUNT_DIR} in used, Input new mount point: " NEW_POINT
        if [[ -d "${NEW_POINT}" ]];then
            echo "********* ${NEW_POINT} in used, exit *********"
            exit 1
        else
            startup_auto_mount "${i}1" "${NEW_POINT}"
         fi
      fi
      DISK_INDEX=$(($DISK_INDEX+1))
  done
}

function startup_auto_mount() {
    PART=$1
    MOUNT_DIR=$2
    mkdir -p "${MOUNT_DIR}"
    UUID_NUM=`blkid | grep "${PART}" | cut -d ' ' -f2 | cut -d '"' -f2`
    echo "UUID=${UUID_NUM} ${MOUNT_DIR} xfs    defaults 0 0" >> /etc/fstab
    mount -a
    [[ $? -eq 0 ]] && echo "********* ${i} mount to ${MOUNT_DIR} success *********"
}

function main() {
  disk_scan
  if [[ -z ${DISK_TO_MOUNT[@]} ]]; then
    echo '********* no disk need to be mounted, exit *********'
    exit
  fi
  part_format ${DISK_TO_MOUNT[@]}
  disk_mount
}

main


