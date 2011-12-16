#!/bin/sh

# partition size in MB
BOOT_ROM_SIZE=8
SYSTEM_ROM_SIZE=100
DATA_SIZE=100
CACHE_SIZE=100
RECOVERY_ROM_SIZE=20

help() {

bn=`basename $0`
cat << EOF
usage $bn <option> device_node

options:
  -h				displays this help message
  -s				only get partition size
EOF

}

# check the if root?
userid=`id -u`
if [ $userid -ne "0" ]; then
	echo "you're not root?"
	exit
fi


# parse command line
moreoptions=1
node="na"
cal_only=0
while [ "$moreoptions" = 1 -a $# -gt 0 ]; do
	case $1 in
		-h) help; exit ;;
		-s) cal_only=1 ;;
		*)  moreoptions=0; node=$1 ;;
	esac
	[ "$moreoptions" = 0 ] && [ $# -gt 1 ] && help && exit
	[ "$moreoptions" = 1 ] && shift
done

if [ ! -e ${node} ]; then
	help
	exit
fi


# call sfdisk to create partition table
# get total card size
total_size=`sfdisk -s ${node}`
total_size=`expr ${total_size} / 1024`
rom_size=`expr ${BOOT_ROM_SIZE} + ${SYSTEM_ROM_SIZE} + ${DATA_SIZE}`
rom_size=`expr ${rom_size} + ${CACHE_SIZE} + ${RECOVERY_ROM_SIZE}`
bvfat_size=`expr ${total_size} - ${rom_size} - 20 `
vfat_size=`expr ${total_size} - ${rom_size} - 20 - 20 `
system_start=`expr ${BOOT_ROM_SIZE} + ${vfat_size} + 1`
extend_start=`expr ${system_start} + ${SYSTEM_ROM_SIZE} + 1`
extend_size=`expr ${DATA_SIZE} + ${CACHE_SIZE} + 8`
recovery_start=`expr ${extend_start} + ${extend_size} + 1`
data_start=`expr ${extend_start} + 1`
cache_start=`expr ${data_start} + ${DATA_SIZE} + 3`

# create partitions
if [ "${cal_only}" -eq "1" ]; then
cat << EOF
VFAT   : ${vfat_size}MB
SYSTEM : ${SYSTEM_ROM_SIZE}MB
RECO   : ${RECOVERY_ROM_SIZE}MB
DATA   : ${DATA_SIZE}MB
CACHE  : ${CACHE_SIZE}MB
EOF
exit
fi

# destroy the partition table
dd if=/dev/zero of=${node} bs=1024 count=1


sfdisk --force -uM ${node} << EOF
,${bvfat_size},b
,${SYSTEM_ROM_SIZE},83
,${extend_size},5
,${RECOVERY_ROM_SIZE},83
,${DATA_SIZE},83
,${CACHE_SIZE},83
EOF

sfdisk --force -uM ${node} -N1 << EOF
8,${vfat_size},b
EOF

# format the SDCARD/DATA/CACHE partition
part=""
echo ${node} | grep mmcblk > /dev/null
if [ "$?" -eq "0" ]; then
	part="p"
fi

mkfs.vfat ${node}${part}1
mkfs.ext3 ${node}${part}5
mkfs.ext3 ${node}${part}6
