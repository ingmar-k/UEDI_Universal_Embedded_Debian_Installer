#!/bin/bash
# Bash script that creates a Debian or Emdebian rootfs or even a complete SATA/USB/SD drive/card for a embedded device
# Should run on current Debian or Ubuntu versions
# Author: Ingmar Klein (ingmar.klein@hs-augsburg.de)

# This program (including documentation) is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License version 3 (GPLv3; http://www.gnu.org/licenses/gpl-3.0.html ) for more details.

# Description: Get the card/drive device and then create the partitions and format them

#################################################
#################################################
#################################################
###    _     ____   ____ _____ _ _____        ###
###   | |   |  _ \ / ___|___ // |___ /_  __   ###
###   | |   | |_) | |     |_ \| | |_ \ \/ /   ###
###   | |___|  __/| |___ ___) | |___) >  <    ###
###   |_____|_|    \____|____/|_|____/_/\_\   ###
###                                           ###
#################################################
#################################################
#################################################


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
write_log "Machine specific, additional chroot system configuration successfully finished!"

}


partition_n_format_disk()
{
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


if [ -e ${device}1 ] && [ -e ${device}2 ]
then
	mkfs.${rootfs_filesystem_type} -L "rootfs" ${device}1 # ${rootfs_filesystem_type} on root partition
	###tune2fs -L "rootfs" ${device}1 # give rootfs partition the corresponding label
	mkswap ${device}2 # swap
else
	write_log "ERROR: There should be 3 partitions on '${device}', but one or more seem to be missing.
Exiting now!"
	regular_cleanup
	exit 31
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
			rootfs_partition_number="1"
			
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






