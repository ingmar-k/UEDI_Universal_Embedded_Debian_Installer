#!/bin/bash
# Bash script that creates a Debian or Emdebian rootfs or even a complete SATA/USB/SD drive/card for a embedded device
# Should run on current Debian or Ubuntu versions
# Author: Ingmar Klein (ingmar.klein@hs-augsburg.de)

# This program (including documentation) is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License version 3 (GPLv3; http://www.gnu.org/licenses/gpl-3.0.html ) for more details.

# Description: Get the USB drive device and than create the partitions and format them
# BIG THANKS go to WarheadsSE for his SATA booting procedure, that made the direct SATA booting option in this script possible.
# Original thread, concerning the topic of direct sata booting can be found here: http://archlinuxarm.org/forum/viewtopic.php?t=2146

########################################################################
########################################################################
########################################################################
#####  ____                         _              __     _______  #####
##### |  _ \ ___   __ _  ___  _ __ | |_   _  __ _  \ \   / |___ /  #####
##### | |_) / _ \ / _` |/ _ \| '_ \| | | | |/ _` |  \ \ / /  |_ \  #####
##### |  __| (_) | (_| | (_) | |_) | | |_| | (_| |   \ V /  ___) | #####
##### |_|   \___/ \__, |\___/| .__/|_|\__,_|\__, |    \_/  |____/  #####
#####             |___/      |_|            |___/                  #####
#####															   #####
########################################################################
########################################################################
########################################################################



partition_n_format_disk()
{
if [ "${boot_directly_via_sata}" = "yes" ]
then
	write_log "Direct SATA boot is enabled. Preparing drive for SATA boot, now."
fi
device=""
echo "Now listing all available devices:
"

while [ -z "${device}" ]
do
parted -l

echo "
Please enter the name of the USB drive device (eg. /dev/sdb) OR press ENTER to refresh the device list:"

read device
if [ -e ${device} ] &&  [ "${device:0:5}" = "/dev/" ]
then
	umount ${device}* 2>/dev/null
	mount |grep ${device} >/dev/null
	if [ ! "$?" = "0" ]
	then
		echo "${device} partition table:"
		parted -s ${device} unit MB print
		echo "If you are sure that you want to repartition device '${device}', then type 'yes'.
Type anything else and/or hit Enter to cancel!"
		read affirmation
		if [ "${affirmation}" = "yes" ]
		then
			if [ ! "${boot_directly_via_sata}" = "yes" ]
			then 
				if [ ! -z "${size_swap_partition}" ]
				then
					write_log "USB drive device set to '${device}', according to user input."
					parted -s ${device} mklabel msdos
					if [ ! -z "${size_wear_leveling_spare}" ]
					then
						# first partition = root (ext3/ext4, size = rest of drive )
						parted -s --align=opt -- ${device} unit MiB mkpart primary ${rootfs_filesystem_type} ${size_alignment} -`expr ${size_swap_partition} + ${size_wear_leveling_spare}`
						# last partition = swap (swap, size = ${size_swap_partition} )
						parted -s --align=opt -- ${device} unit MiB mkpart primary linux-swap -`expr ${size_swap_partition} + ${size_wear_leveling_spare}` -${size_wear_leveling_spare} 
					else
						# first partition = root (ext3/ext4, size = rest of drive )
						parted -s --align=opt -- ${device} unit MiB mkpart primary ${rootfs_filesystem_type} ${size_alignment} -${size_swap_partition}
						# last partition = swap (swap, size = ${size_swap_partition} )
						parted -s --align=opt -- ${device} unit MiB mkpart primary linux-swap -${size_swap_partition} -0
					fi
					echo ">>> ${device} Partition table is now:"
					parted -s ${device} unit MiB print
				else
					write_log "ERROR: The setting for 'size_swap_partition' seems to be empty.
Exiting now!"
					regular_cleanup
					exit 29
				fi
			else
				if [ ! -z "${size_swap_partition}" ]
				then
					write_log "SATA drive device set to '${device}', according to user input."
					parted -s ${device} mklabel msdos
					if [ ! -z "${size_wear_leveling_spare}" ]
					then
						# first (implicit) partition for bootloader = 2048 sectors = 1MB
						# second partition for kernel
						parted -s --align=opt -- ${device} unit MiB mkpart primary 1 9 # 8MB second partition at the beginning of the drive for the kernel
						# third partition = root (ext3/ext4, size = rest of drive )
						parted -s --align=opt -- ${device} unit MiB mkpart primary ${rootfs_filesystem_type} 9 -`expr ${size_swap_partition} + ${size_wear_leveling_spare}`
						# last partition = swap (swap, size = ${size_swap_partition} )
						parted -s --align=opt -- ${device} unit MiB mkpart primary linux-swap -`expr ${size_swap_partition} + ${size_wear_leveling_spare}` -${size_wear_leveling_spare} 
					else
						# first (implicit) partition for bootloader = 2048 sectors = 1MB
						# second partition for kernel
						parted -s --align=opt -- ${device} unit MiB mkpart primary 1 9 # 16MB second partition at the beginning of the drive
						# third partition = root (ext3/ext4, size = rest of drive )
						parted -s --align=opt -- ${device} unit MiB mkpart primary ${rootfs_filesystem_type} 9 -${size_swap_partition}
						# last partition = swap (swap, size = ${size_swap_partition} )
						parted -s --align=opt -- ${device} unit MiB mkpart primary linux-swap -${size_swap_partition} -0
					fi
					echo ">>> ${device} Partition table is now:"
					parted -s ${device} unit MiB print
				else
					write_log "ERROR: The setting for 'size_swap_partition' seems to be empty.
Exiting now!"
					regular_cleanup
					exit 29
				fi
			fi
		else
			write_log "Action canceled by user. Exiting now!"
			regular_cleanup
			exit 29
		fi
	else
		write_log "ERROR: Some partition on device '${device}' is still mounted.
Exiting now!"
		regular_cleanup
		exit 30
	fi
else
	if [ ! -z "${device}" ] # in case of a refresh we don't want to see the error message ;-)
	then 
		write_log "ERROR: Device '${device}' doesn't seem to be a valid device!"
	fi
	device=""
fi

done

if [ ! "${boot_directly_via_sata}" = "yes" ]
then
	if [ -e ${device}1 ] && [ -e ${device}2 ]
	then
		mkfs.${rootfs_filesystem_type} ${device}1 # ${rootfs_filesystem_type} on root partition
		tune2fs -L "rootfs" ${device}1 # give rootfs partition the corresponding label
		mkswap ${device}2 # swap
	else
		write_log "ERROR: There should be 3 partitions on '${device}', but one or more seem to be missing.
Exiting now!"
		regular_cleanup
		exit 31
	fi
else # case of direct sata booting
	if [ -e ${device}1 ] && [ -e ${device}2 ] && [ -e ${device}3 ]
	then
		dd if=/dev/zero of=${device}1 >/dev/null # partition 1 needs to be raw, without a filesystem
		### Now writing the hex codes for SATA booting to the drive's bootsector
		perl <<EOF | dd of=${device} bs=512
print "\x00" x 0x1a4;
print "\x00\x5f\x01\x00";
print "\x00\xdf\x00\x00";
print "\x00\x80\x00\x00";
print "\x00" x (0x1b0 -0x1a4 -12 );
print "\x22\x80\x00\x00";
print "\x22\x00\x00\x00";
print "\x00\x80\x00\x00";
EOF
		dd if=${output_dir}/tmp/${sata_boot_stage1##*/} of=${device} bs=512 seek=34 && write_log "Stage1 bootloader successfully written to disk '${device}'." # write stage1 to disk
		dd if=${output_dir}/tmp/${sata_uboot##*/} of=${device} bs=512 seek=154 && write_log "Uboot successfully written to disk '${device}'." # write uboot to disk
		dd if=${output_dir}/tmp/uImage of=${device}1 bs=512 && write_log "Kernel successfully written to disk '${device}'." # write kernel to disk
		mkfs.${rootfs_filesystem_type} ${device}2 # ${rootfs_filesystem_type} on root partition
		tune2fs -L "rootfs" ${device}2 # give rootfs partition the corresponding label
		mkswap ${device}3 # swap
	else
		write_log "ERROR: There should be 3 partitions on '${device}', but one or more seem to be missing.
Exiting now!"
		regular_cleanup
		exit 31
	fi
fi

sleep 1
partprobe
}



# Description: Copy rootfs and kernel-modules to the drive and then unmount it
finalize_disk()
{
if [ -e ${device} ] &&  [ "${device:0:5}" = "/dev/" ]
then
	umount ${device}* 2>/dev/null
	sleep 3
	mount |grep ${device} >/dev/null
	if [ ! "$?" = "0" ]
	then
		# unpack the filesystem and kernel to the root partition
		write_log "Now unpacking the rootfs to the drive's root partition!"

		mkdir ${output_dir}/drive
		if [ "$?" = "0" ]
		then
			if [ ! "${boot_directly_via_sata}" = "yes" ]
			then
				rootfs_partition_number="1"
			else
				rootfs_partition_number="2"
			fi
			fsck -fy ${device}${rootfs_partition_number} # just to be sure
			mount ${device}${rootfs_partition_number} ${output_dir}/drive
			if [ "$?" = "0" ]
			then
				if [ -e ${output_dir}/${output_filename}.tar.${tar_format} ]
				then 
					tar_all extract "${output_dir}/${output_filename}.tar.${tar_format}" "${output_dir}/drive"
				else
					write_log "ERROR: File '${output_dir}/${output_filename}.tar.${tar_format}' doesn't seem to exist.
Exiting now!"
					regular_cleanup
					exit 80
				fi
				sleep 1
			else
				write_log "ERROR: Trying to mount '${device}1' to '${output_dir}/drive' and error occurred.
'mount' returned error code '$?'. Exiting now!"
				regular_cleanup
				exit 81
			fi
		else
			write_log "ERROR: Trying to create the temporary directory '${output_dir}/drive' and error occurred.
'mkdir' returned error code '$?'. Exiting now!"
			regular_cleanup
			exit 82
		fi
		
		sleep 3
		write_log "Nearly done! Now trying to unmount the drive."
		umount ${output_dir}/drive

		sleep 3
		write_log "Now doing a final filesystem check."
		fsck -fy ${device}${rootfs_partition_number} # final check

		if [ "$?" = "0" ]
		then
			write_log "drive successfully created!
You can remove the drive now
and try it with your pogoplug-V3.
ALL DONE!"
		else
			write_log "ERROR: Filesystem check on your card returned an error status. Maybe your card is going bad, or something else went wrong.
'fsck -fy ${device}${rootfs_partition_number}' returned error code '$?'."
		fi

		rm -r ${output_dir}/tmp
		rm -r ${output_dir}/drive
	else
		write_log "ERROR: Some partition on device '${device}' is still mounted. Exiting now!"
	fi
else
	write_log "ERROR: Device '${device}' doesn't seem to exist!
Exiting now"
	regular_cleanup
	exit 83
fi
}






