#!/bin/bash
# Bash script that creates a Debian or Emdebian rootfs or even a complete SATA/USB/SD drive/card for a embedded device
# Should run on current Debian or Ubuntu versions
# Author: Ingmar Klein (ingmar.klein@hs-augsburg.de)

# This program (including documentation) is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License version 3 (GPLv3; http://www.gnu.org/licenses/gpl-3.0.html ) for more details.

# Description: Get the card/drive device and then create the partitions and format them
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


############################################################
################# Check for debugging mode #################
######### And activate it, if set in settings file #########
############################################################
if [ "${DEBUG}" = "1" ]
then
	set -xv # set verbose mode and show executed commands 
fi
############################################################
############################################################


do_post_debootstrap_config_machine()
{
write_log "Starting machine specific post-debootstrap configuration steps."

if [ -e ${output_dir}/mnt_debootstrap/lib/modules/gmac_copro_firmware ]
then
	write_log "Moving gmac-firmware file to the right position ('/lib/firmware')."
	mkdir -p ${output_dir}/mnt_debootstrap/lib/firmware/
	mv ${output_dir}/mnt_debootstrap/lib/modules/gmac_copro_firmware ${output_dir}/mnt_debootstrap/lib/firmware/ 2>>${output_dir}/log.txt
else
	write_log "Could not find '${output_dir}/mnt_debootstrap/lib/modules/gmac_copro_firmware'. So, not moving it."
fi

write_log "Machine specific, additional chroot system configuration successfully finished!"

}


partition_n_format_disk()
{
if [ "${external_bootloader}" = "yes" ]
then
	write_log "Direct booting, using a external bootlaoder, is enabled. Preparing drive for direct booting, now."
fi

device="" # initalize 'device' as empty variable, to make sure
echo "Now listing all available devices:
"

while [ -z "${device}" ]
do
	parted -l

	read -t 60 -p "
__________________________________________________

Please enter the name of the drive/card device (eg. /dev/sdb) OR press ENTER to refresh the device list:
__________________________________________________

" device

	if [ ! -z "${device}" -a -e ${device} -a "${device:0:5}" = "/dev/" ]
	then
		umount ${device}* 2>/dev/null
		mount |grep ${device} >/dev/null
		if [ ! "$?" = "0" ]
		then
			echo "'${device}' partition table:"
			parted -s ${device} unit MB print
			read -t 300 -p "
__________________________________________________
		
If you are sure that you want to repartition device '${device}', then please type 'yes'.
Type anything else and/or hit Enter to cancel:
__________________________________________________

" affirmation
			if [ ! -z "${affirmation}" -a "${affirmation}" = "yes" ]
			then
				if [ ! "${external_bootloader}" = "yes" ]
				then 
					if [ ! -z "${size_swap_partition}" ]
					then
						write_log "Card/drive device set to '${device}', according to user input."
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
				else # case of using a external bootloader for direct booting
					if [ ! -z "${size_swap_partition}" ]
					then
						write_log "Card/drive device set to '${device}', according to user input."
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
				write_log "Action canceled by user, or timed out.
Exiting now!
You can rerun the drive creation (only) by using the '--install' or '-i' call parameter of this script!
Just run 'sudo ./build_emdebian_debian_system.sh --help' for more information."
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

if [ ! "${external_bootloader}" = "yes" ]
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
		if [ -f ${output_dir}/tmp/u-boot.wrapped -a -f ${output_dir}/tmp/stage1.wrapped* ] # case of using the older bootloader files
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
			dd if=`ls ${output_dir}/tmp/stage1.wrapped*` of=${device} bs=512 seek=34 && write_log "Stage1 (stage1.wrapped*) bootloader successfully written to disk '${device}'." # write stage1 to disk
			dd if=${output_dir}/tmp/u-boot.wrapped of=${device} bs=512 seek=154 && write_log "Uboot (u-boot.wrapped) successfully written to disk '${device}'." # write uboot to disk
			dd if=${output_dir}/tmp/uImage of=${device}1 bs=512 && write_log "Kernel successfully written to disk '${device}'." # write kernel to disk
			mkfs.${rootfs_filesystem_type} ${device}2 # ${rootfs_filesystem_type} on root partition
			tune2fs -L "rootfs" ${device}2 # give rootfs partition the corresponding label
			mkswap ${device}3 # swap
		elif [ -f ${output_dir}/tmp/u-boot.img -a -f ${output_dir}/tmp/u-boot-spl.bin ] # case of using the newer bootloader files
		then
			mkfs.vfat -L "boot" ${device}1 >/dev/null # partition 1 needs to formatted with the FAT filesystem
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
			dd if=${output_dir}/tmp/u-boot-spl.bin of=${device} bs=512 seek=34 && write_log "Stage1 (u-boot-spl.bin) bootloader successfully written to disk '${device}'." # write stage1 to disk
			mkdir ${output_dir}/mnt_direct_boot
			sleep 1
			if [ -d "${output_dir}/mnt_direct_boot/" ]
			then
				mount ${device}1 ${output_dir}/mnt_direct_boot/ && write_log "Successfully mounted the FAT partition '${device}1'." # mount FAT drive to '${output_dir}/mnt_direct_boot'
			else
				write_log "ERROR: Could not find the directory '${output_dir}/mnt_direct_boot' needed as a mount point.
Exiting now!"
				regular cleanup
				exit 32
			fi
			cp ${output_dir}/tmp/u-boot.img ${output_dir}/mnt_direct_boot/ && write_log "Uboot successfully copied to the first disk partition '${device}1'." # copy uboot to disk
			cp ${output_dir}/tmp/uImage ${output_dir}/mnt_direct_boot && write_log "Kernel successfully copied to the disk's first partition '${device}1'." # copy kernel to disk
			sleep 3
			umount ${output_dir}/mnt_direct_boot && write_log "FAT partition '${device}1' successfully unmounted."
			mkfs.${rootfs_filesystem_type} ${device}2 # ${rootfs_filesystem_type} on root partition
			tune2fs -L "rootfs" ${device}2 # give rootfs partition the corresponding label
			mkswap -L "swap" ${device}3 # swap
		else
			write_log "ERROR: Direct booting via a external bootloader was enabled in the settings file.
However, no appropriate combination of bootloader files could be found in '${output_dir}/tmp/'!
Please check. Exiting now!"
			regular_cleanup
			exit 33
		fi
	else
		write_log "ERROR: There should be 3 partitions on '${device}', but one or more seem to be missing.
Exiting now!"
		regular_cleanup
		exit 34
	fi
fi

sleep 1
partprobe
}



# Description: Copy rootfs and kernel-modules to the drive and then unmount it
finalize_disk()
{
if [ ! -z "${device}" -a -e ${device} -a "${device:0:5}" = "/dev/" ]
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
			if [ ! "${external_bootloader}" = "yes" ]
			then
				rootfs_partition_number="1"
			else
				rootfs_partition_number="2"
			fi
			fsck -fy ${device}${rootfs_partition_number} # just to be sure
			mount ${device}${rootfs_partition_number} ${output_dir}/drive
			if [ "$?" = "0" ]
			then
				if [ -f "${output_dir}/${output_filename}.tar.${tar_format}" ]
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
You can remove the drive now and try it with your pogoplug-V3.
ALL DONE!"
		else
			write_log "ERROR: Filesystem check on your card returned an error status. Maybe your card is going bad, or something else went wrong.
'fsck -fy ${device}${rootfs_partition_number}' returned error code '$?'."
		fi

		rm -r ${output_dir}/tmp
		rm -r ${output_dir}/drive
		if [ "${external_bootloader}" = "yes" ]
		then
			rm -r ${output_dir}/mnt_direct_boot/
		fi
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






