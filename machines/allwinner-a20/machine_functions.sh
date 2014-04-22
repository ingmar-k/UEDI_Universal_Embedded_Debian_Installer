#!/bin/bash
# Bash script that creates a Debian rootfs or even a complete SD memory card for a Allwinner A10 board
# Should run on current Debian or Ubuntu versions
# Author: Ingmar Klein (ingmar.klein@hs-augsburg.de)
# Created in scope of the Master project, winter semester 2012/2013 under the direction of Professor Nik Klever, at the University of Applied Sciences Augsburg.


# This program (including documentation) is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License version 3 (GPLv3; http://www.gnu.org/licenses/gpl-3.0.html ) for more details.

################################################################################
################################################################################
################################################################################
###       _    _ _          _                            _    ____   ___     ###
###      / \  | | |_      _(_)_ __  _ __   ___ _ __     / \  |___ \ / _ \    ###
###     / _ \ | | \ \ /\ / / | '_ \| '_ \ / _ \ '__|   / _ \   __) | | | |   ###
###    / ___ \| | |\ V  V /| | | | | | | |  __/ |     / ___ \ / __/| |_| |   ###
###   /_/   \_\_|_| \_/\_/ |_|_| |_|_| |_|\___|_|    /_/   \_\_____|\___/    ###
###																			 ###
################################################################################
################################################################################
################################################################################


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


# Description: Do some further configuration of the system, after debootstrap has finished
do_post_debootstrap_config_machine()
{

write_log "Starting machine specific post-debootstrap configuration steps."

write_log "Creating the udev rule for 'mali' and 'ump', now."
echo "KERNEL==\"mali\", MODE=\"0660\", GROUP=\"video\"
KERNEL==\"ump\", MODE=\"0660\", GROUP=\"video\"" > ${qemu_mnt_dir}/etc/udev/rules.d/50-mali.rules

sed -i 's/^reboot//' ${qemu_mnt_dir}/setup.sh 2>>/post_debootstrap_config_errors.txt # remove the 'reboot'
sed -i 's/^exit 0//' ${qemu_mnt_dir}/setup.sh 2>>/post_debootstrap_config_errors.txt # and the 'exit 0' from the standard script, in order to be able to concatenate further code lines before reboot and exit 
sed -i 's|^exit 0|chmod 777 /dev/g2d\nchmod 777 /dev/disp\nchmod 777 /dev/cedar_dev\nexit 0|' ${qemu_mnt_dir}/etc/rc.local 2>>/post_debootstrap_config_errors.txt

echo "
echo \"Trying to compile the mali drivers and libraries, now.\"
cd /root/mali_build 2>>/mali_drv_compile_errors.txt
if [ \"\${?}\" = \"0\" ]
then
	echo \"Successfully changed into directory '/root/mali_build'.\" && echo \"Successfully changed into directory '/root/mali_build'.\" >> /mali_drv_compile.txt
	
	cd /root/mali_build/libdri2 2>>/mali_drv_compile_errors.txt
	if [ \"\${?}\" = \"0\" ]
	then
		echo \"Successfully changed into directory '\`pwd\`'.\" && echo \"Successfully changed into directory '\`pwd\`'.\" >> /mali_drv_compile.txt 
		./autogen.sh 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran the 'autogen.sh' (libdri2) command.\" && echo \"Successfully ran the 'autogen.sh' (libdri2) command.\" >> /mali_drv_compile.txt
		./configure --prefix=/usr --x-includes=/usr/include --x-libraries=/usr/lib 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran the configuration for libdri2.\" && echo \"Successfully ran the configuration for libdri2.\" >> /mali_drv_compile.txt
		make -j2 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran the 'make' (libdri2) command.\" && echo \"Successfully ran the 'make' (libdri2) command.\" >> /mali_drv_compile.txt
		make install 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran the 'make install' (libdri2) command.\" && echo \"Successfully ran the 'make install' (libdri2) command.\" >> /mali_drv_compile.txt
	else
		echo \"Could not change directory into '/root/mali_build/libdri2'
Please investigate!\" >>/mali_drv_compile_errors.txt
	fi
	
	cd /root/mali_build/sunxi-mali 2>>/mali_drv_compile_errors.txt
	if [ \"\${?}\" = \"0\" ]
	then
		echo \"Changed directory to '\`pwd\`'.\" && echo \"Changed directory to '\`pwd\`'.\" >> /mali_drv_compile.txt
		make config VERSION=${mali_module_version} ABI=armhf EGL_TYPE=x11 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran the 'make config' command of 'sunxi-mali'.\" >> /mali_drv_compile.txt
		make -j2 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran the 'make' (sunxi-mali) command.\" && echo \"Successfully ran the 'make' (sunxi-mali) command.\" >> /mali_drv_compile.txt
		make install 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran the 'make install' (sunxi-mali) command.\" && echo \"Successfully ran the 'make install' (sunxi-mali) command.\" >> /mali_drv_compile.txt
	else
		echo \"Could not change directory into '/root/mali_build/sunxi-mali'
Please investigate!\" >>/mali_drv_compile_errors.txt
	fi
	
	cd lib/sunxi-mali-proprietary && echo \"Changed directory to '\`pwd\`'.\" && echo \"Changed directory to '\`pwd\`'.\" >> /mali_drv_compile.txt
	if [ \"\${?}\" = \"0\" ]
	then
		make VERSION=${mali_module_version} ABI=armhf EGL_TYPE=x11 -j2 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran the 'make' (sunxi-mali-proprietary) command.\" && echo \"Successfully ran the 'make' (sunxi-mali-proprietary) command.\" >> /mali_drv_compile.txt
		make install 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran the 'make install' (sunxi-mali-proprietary) command.\" && echo \"Successfully ran the 'make install' (sunxi-mali-proprietary) command.\" >> /mali_drv_compile.txt
		cd ../../test 2>>/mali_drv_compile_errors.txt && echo \"Changed directory to '../../test'.\" && echo \"Changed directory to '../../test'.\" >> /mali_drv_compile.txt
		make -j2 test 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran the 'make test' (sunxi-mali) command.\" && echo \"Successfully ran the 'make test' (sunxi-mali) command.\" >> /mali_drv_compile.txt
	else
		echo \"Could not change directory into '/root/mali_build/sunxi-mali-proprietary'
Please investigate!\" >>/mali_drv_compile_errors.txt
	fi
	
	cd /root/mali_build/libump 2>>/mali_drv_compile_errors.txt && echo \"Changed directory to '\`pwd\`'.\" && echo \"Changed directory to '\`pwd\`'.\" >> /mali_drv_compile.txt
	if [ \"\${?}\" = \"0\" ]
	then
		autoreconf -i 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran autoreconf.\" && echo \"Successfully ran autoreconf.\" >> /mali_drv_compile.txt
		./configure 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran the configuration for 'libump'.\" && echo \"Successfully ran the configuration for 'libump'.\" >> /mali_drv_compile.txt
		make -j2 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran the 'make' (libump) command.\" && echo \"Successfully ran the 'make' (libump) command.\" >> /mali_drv_compile.txt
		make install 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran the 'make install' (libump) command.\" && echo \"Successfully ran the 'make install' (libump) command.\" >> /mali_drv_compile.txt
	else
		echo \"Could not change directory into '/root/mali_build/libump'
Please investigate!\" >>/mali_drv_compile_errors.txt
	fi
	
	cd /root/mali_build/xf86-video-fbturbo 2>>/mali_drv_compile_errors.txt
	if [ \"\${?}\" = \"0\" ]
	then
		echo \"Changed directory to '\`pwd\`'.\" && echo \"Changed directory to '\`pwd\`'.\" >> /mali_drv_compile.txt
		autoreconf -vi 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran autoreconf.\" && echo \"Successfully ran autoreconf.\" >> /mali_drv_compile.txt
		./configure --prefix=/usr 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran the configuration for the 'xf86-video-fbturbo' driver.\" && echo \"Successfully ran the configuration for the 'xf86-video-fbturbo' driver.\" >> /mali_drv_compile.txt
		make -j2 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran the 'make' (xf86-video-fbturbo) command.\" && echo \"Successfully ran the 'make' (xf86-video-fbturbo) command.\" >> /mali_drv_compile.txt
		make install 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran the 'make install' (xf86-video-fbturbo) command.\" && echo \"Successfully ran the 'make install' (xf86-video-fbturbo) command.\" >> /mali_drv_compile.txt
		cp -f ./xorg.conf /etc/X11/xorg.conf && echo \"Successfully copied the 'xorg.conf' (xf86-video-fbturbo).\" && echo \"Successfully copied the 'xorg.conf' (xf86-video-fbturbo).\" >> /mali_drv_compile.txt
	else
		echo \"Could not change directory into '/root/mali_build/xf86-video-fbturbo'
Please investigate!\" >>/mali_drv_compile_errors.txt
	fi
	
	cd /root/mali_build/libcedarx 2>>/mali_drv_compile_errors.txt
	if [ \"\${?}\" = \"0\" ]
	then
		echo \"Changed directory to '\`pwd\`'.\" && echo \"Changed directory to '\`pwd\`'.\" >> /mali_drv_compile.txt
		./autogen.sh 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran 'libcedarx' autogen.sh.\" && echo \"Successfully ran 'libcedarx' autogen.sh.\" >> /mali_drv_compile.txt
		./configure --host=arm-linux-gnueabihf --prefix=/usr 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran 'libcedarx' configure.\" && echo \"Successfully ran 'libcedarx' configure.\" >> /mali_drv_compile.txt
		make -j2 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran 'libcedarx' make.\" && echo \"Successfully ran 'libcedarx' make.\" >> /mali_drv_compile.txt
		make install 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran 'libcedarx' make install.\" && echo \"Successfully ran 'libcedarx' make install.\" >> /mali_drv_compile.txt
	else
		echo \"Could not change directory into '/root/mali_build/libcedarx'
Please investigate!\" >>/mali_drv_compile_errors.txt
	fi
	
	cd /root/mali_build/libvdpau-sunxi 2>>/mali_drv_compile_errors.txt
	if [ \"\${?}\" = \"0\" ]
	then
		echo \"Changed directory to '\`pwd\`'.\" && echo \"Changed directory to '\`pwd\`'.\" >> /mali_drv_compile.txt
		make -j2 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran 'libvdpau-sunxi' make.\" && echo \"Successfully ran 'libvdpau-sunxi' make.\" >> /mali_drv_compile.txt
		make install 2>>/mali_drv_compile_errors.txt && echo \"Successfully ran 'libvdpau-sunxi' make install.\" && echo \"Successfully ran 'libvdpau-sunxi' make install.\" >> /mali_drv_compile.txt
		export VDPAU_DRIVER=sunxi && echo \"Successfully exported 'VDPAU_DRIVER=sunxi'.\" && echo \"Successfully exported 'VDPAU_DRIVER=sunxi'.\" >> /mali_drv_compile.txt
	else
		echo \"Could not change directory into '/root/mali_build/libvdpau-sunxi'
Please investigate!\" >>/mali_drv_compile_errors.txt
	fi
	
else
	echo \"ERROR: Couldn't change into directory '/root/mali_build/'!\" >>/post_debootstrap_errors.txt
fi

ldconfig -v

echo \"export XDG_CACHE_HOME=\"/dev/shm/.cache\"\" >> /home/${username}/.bashrc

if [ ! -z \"${additional_desktop_packages}\" ] # undo network configuration for systems with a desktop environment, because the network manager handles the configuration there!!!
then
	mv /etc/resolv.conf /etc/resolv.conf.bak
	touch /etc/resolv.conf
	mv /etc/network/interfaces /etc/network/interfaces.bak
	cat <<END > /etc/network/interfaces
auto lo
iface lo inet loopback
END

fi
swapoff /swapfile
swapoff /dev/zram0
sleep 1
rm /swapfile

reboot 2>>/post_debootstrap_errors.txt
exit 0" >> ${qemu_mnt_dir}/setup.sh
chmod +x ${qemu_mnt_dir}/setup.sh

write_log "Preparing all repositories needed for graphics drivers etc. ."
mkdir -p ${qemu_mnt_dir}/root/mali_build && write_log "Directory for graphics driver build successfully created."

if [ "${use_cache}" = "yes" ]
then
	if [ -d "${output_dir_base}/cache/" ]
	then
		for i in sunxi_mali_git sunxi_mali_proprietary_git xf86_video_fbturbo_git libdri2_git libcedarx_git libvdpau_sunxi_git libump_git
		do
			tmp="${output_dir_base}/cache/\${${i}_tarball}"
			tmp=`eval echo ${tmp}`
			tmp_2="\${${i}}"
			tmp_2=`eval echo ${tmp_2}`
			tmp_3="${i}"
			tmp_3="${tmp_3%%_git}"
			tmp_3="${tmp_3//_/-}"
			if [ -f ${tmp} ]
			then
				write_log "Using ${i} tarball '${tmp}' from cache."
				tar_all extract "${tmp}" "${qemu_mnt_dir}/root/mali_build"
				cd ${qemu_mnt_dir}/root/mali_build/${tmp_3} && git pull
			else
				write_log "Tarball '${tmp}' NOT found in cache.
Generating it now."
				get_n_check_file "${tmp_2}" "${i}" "${qemu_mnt_dir}/root/mali_build"
				cd ${qemu_mnt_dir}/root/mali_build
				tar_all compress "${tmp}" ${tmp_3} && write_log "Cache tarball for ${i} successfully created."
			fi
		done
	fi
else
	for i in sunxi_mali_git sunxi_mali_proprietary_git xf86_video_fbturbo_git libdri2_git libcedarx_git libvdpau_sunxi_git libump_git
	do
		get_n_check_file "${tmp_2}" "${tmp_3}" "${qemu_mnt_dir}/root/mali_build"
	done
fi

write_log "Machine specific, additional chroot system configuration successfully finished!"

}



# Description: Get the SD-card device and than create the partitions and format them
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
##################################################
##################################################
		
If you are sure that you want to repartition device '${device}', then please type 'yes'.
Type anything else and/or hit Enter to cancel:

##################################################
##################################################

" affirmation
			if [ ! -z "${affirmation}" -a "${affirmation}" = "yes" ]
			then
				if [ ! -z "${size_swap_partition}" ]
				then
					write_log "Card/drive device set to '${device}', according to user input."
					parted -s ${device} mklabel msdos
					if [ ! -z "${size_wear_leveling_spare}" ]
					then
						# first partition = boot (raw, size = ${size_boot_partition} )
						parted -s --align=opt -- ${device} unit MiB mkpart primary fat16 1 ${size_boot_partition}
						# second partition = root (rest of the drive size)
						parted --align=opt -- ${device} unit MiB mkpart primary ext4 ${size_boot_partition} -`expr ${size_swap_partition} + ${size_wear_leveling_spare}`
						# last partition = swap (swap, size = ${size_swap_partition} )
						parted -s --align=opt -- ${device} unit MiB mkpart primary linux-swap -`expr ${size_swap_partition} + ${size_wear_leveling_spare}` -${size_wear_leveling_spare} 
					else
						# first partition = boot (raw, size = ${size_boot_partition} )
						parted -s --align=opt -- ${device} unit MiB mkpart primary fat16 1 ${size_boot_partition}
						# second partition = root (rest of the drive size)
						parted --align=opt -- ${device} unit MiB mkpart primary ext4 ${size_boot_partition} -${size_swap_partition}
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

if [ -e ${device}1 ] && [ -e ${device}2 ] && [ -e ${device}3 ]
then
	mkfs.vfat ${device}1 # vfat on boot partition
	if [ "${rootfs_filesystem_type}" = "ext4" ]
	then
		mkfs.${rootfs_filesystem_type} -L "rootfs" -E lazy_itable_init=0,lazy_journal_init=0 ${device}2 # root partition: disable ext4 lazy_initialization, in order to increase performance!
	else
		mkfs.${rootfs_filesystem_type} -L "rootfs" ${device}2 # root partition
	fi
	mkswap -L "mmc_swap" ${device}3 # swap
else
	write_log "ERROR: There should be 3 partitions on '${device}', but one or more seem to be missing.
Exiting now!"
	regular_cleanup
	exit 31
fi

sleep 1
partprobe
}



# Description: Copy bootloader, rootfs and kernel to the SD-card and then unmount it
finalize_disk()
{
# Copy bootloader to the boot partition
write_log "Getting the bootloader and trying to copy it to the boot partition, now!"

get_n_check_file "${bootloader_package}" "bootloader_package" "${output_dir}/tmp/"
get_n_check_file "${bootloader_script_bin}" "bootloader_script_bin" "${output_dir}/tmp/"
tar_all extract "${output_dir}/tmp/${bootloader_package##*/}" "${output_dir}/tmp/"

if [ -e ${device} ] &&  [ "${device:0:5}" = "/dev/" ]
then
	umount ${device}*
	mount |grep ${device}
	if [ ! "$?" = "0" ]
	then
		if [ -f "${output_dir}/tmp/u-boot-sunxi-with-spl.bin" ] # combined file, containing both u-boot.img and sunxi-spl.bin in ONE single file
		then
			dd if=${output_dir}/tmp/u-boot-sunxi-with-spl.bin of=${device} bs=1024 seek=8
			if [ "$?" = "0" ]
			then
				write_log "Combined bootloader file (u-boot-sunxi-with-spl.bin) successfully copied to SD-card ('${device}')!"
			else
				write_log "ERROR: Something went wrong While trying to copy the combined bootloader file 'u-boot-sunxi-with-spl.bin'
to the device '${device}'. 'dd' exited with error code '$?'."
			fi
		elif [ -f "${output_dir}/tmp/sunxi-spl.bin" ] # sunxi-spl.bin (stage 1 bootloader for sd card booting)
		then
			dd if=${output_dir}/tmp/sunxi-spl.bin of=${device} bs=1024 seek=8
			if [ "$?" = "0" ]
			then
				write_log "Bootloader part 1 (sunxi-spl.bin) successfully copied to SD-card ('${device}')!"
			else
				write_log "ERROR: Something went wrong While trying to copy the part 1 bootloader file 'sunxi-spl.bin'
to the device '${device}'. 'dd' exited with error code '$?'."
			fi
			
			if [ -f "${output_dir}/tmp/u-boot.bin" ] # u-boot.bin (only part of "older" U-Boot source code versions; superceeded by 'u-boot.img', see below!)
			then
				dd if=${output_dir}/tmp/u-boot.bin of=${device} bs=1024 seek=32
				if [ "$?" = "0" ]
				then
					write_log "Bootloader part 2 (u-boot.bin) successfully copied to SD-card ('${device}')!"
				else
					write_log "ERROR: Something went wrong While trying to copy the part 2 bootloader file 'u-boot.bin'
to the device '${device}'. 'dd' exited with error code '$?'."
				fi
			elif [ -f "${output_dir}/tmp/u-boot.img" ] # u-boot.img, used in more recent versions of the sunxi U-Boot source code (instead of u-boot.bin)
			then
				dd if=${output_dir}/tmp/u-boot.img of=${device} bs=1024 seek=40
				if [ "$?" = "0" ]
				then
					write_log "Bootloader part 2 (u-boot.img) successfully copied to SD-card ('${device}')!"
				else
					write_log "ERROR: Something went wrong While trying to copy the part 2 bootloader file 'u-boot.img'
to the device '${device}'. 'dd' exited with error code '$?'."
				fi
			else
				write_log "ERROR: No stage 2 bootlaoder binary found.
Neither 'u-boot.bin', nor 'u-boot.img' seem to exist in directory '${output_dir}/tmp/'.
You won't be able to boot the card, without copying the file to the second partition.
Please be sure to check this!"
			fi
		else
			write_log "ERROR: Bootloader binary 'sunxi-spl.bin' doesn't seem to exist in directory '${output_dir}/tmp/'.
You won't be able to boot the card, without copying the file to the second partition.
Please be sure to check this!"
		fi
	else
		write_log "ERROR! Some partition on device '${device}' is still mounted. Exiting now!"
	fi
else
	write_log "ERROR! Device '${device}' doesn't seem to exist!
	Exiting now"
	regular_cleanup
	exit 33
fi

# unpack the filesystem and kernel to the root partition

write_log "Now unpacking the rootfs to the SD-card's root partition!"

mkdir -p ${output_dir}/drive/boot
mkdir -p ${output_dir}/drive/root
if [ "$?" = "0" ]
then
	fsck -fy ${device}1 # just to be sure
	fsck -fy ${device}2 # just to be sure
	mount ${device}1 ${output_dir}/drive/boot # TODO: check for mount error for this one, too!
	if [ ! "$?" = "0" ]
	then
		write_log "ERROR while trying to mount '${device}1' to '${output_dir}/drive/boot'. Exiting now!"
		regular_cleanup
		exit 34
	fi
	mount ${device}2 ${output_dir}/drive/root
	if [ "$?" = "0" ]
	then
		if [ -e ${output_dir}/${output_filename}.tar.${tar_format} ]
		then 
			tar_all extract "${output_dir}/${output_filename}.tar.${tar_format}" "${output_dir}/drive/root"
			cp ${output_dir}/drive/root/uImage ${output_dir}/drive/boot/ 
			cp ${output_dir}/tmp/${bootloader_script_bin##*/} ${output_dir}/drive/boot/			
		else
			write_log "ERROR: File '${output_dir}/${output_filename}.tar.${tar_format}' doesn't seem to exist. Exiting now!"
			regular_cleanup
			exit 35
		fi
		sleep 1
	else
		write_log "ERROR while trying to mount '${device}2' to '${output_dir}/drive'. Exiting now!"
		regular_cleanup
		exit 36
	fi
else
	write_log "ERROR while trying to create the temporary directory '${output_dir}/drive/root'. Exiting now!"
	regular_cleanup
	exit 37
fi

sleep 3
write_log "Unmounting the drive now."
umount ${output_dir}/drive/root
umount ${output_dir}/drive/boot

sleep 3
write_log "Running fsck to make sure the filesystem on the card is fine."
fsck -fy ${device}1 && write_log "'fsck' on '${device}1' finished without errors." # final check
fsck -fy ${device}2 && write_log "'fsck' on '${device}2' finished without errors." # final check
if [ "$?" = "0" ]
then
	write_log "SD-card successfully created!
You can remove the card now and try it in your Allwinner A10 based board.
ALL DONE!"

else
	write_log "ERROR! Filesystem check on your card returned an error status. Maybe your card is going bad, or something else went wrong."
fi

rm -r ${output_dir}/tmp
rm -r ${output_dir}/drive
}



#############################
##### HELPER Functions: #####
#############################


# Description: Helper function to help with installing packages via apt. Without this, one wrong entry in the package list leads to the whole list being discarded. With it, apt gets called for each package alone, which only leads to an error if one package can't be installed.
apt_get_helper()
{
apt_choice=${1}
if [ "${apt_choice}" = "write_script" ]
then
	write_log "Writing the 'apt_helper.sh' helper script for the apt install processes."
	cat<<END>${qemu_mnt_dir}/apt_helper.sh
#!/bin/bash
# helper script to install a list of packages, even if one or more errors occur

apt_get_helper()
{
apt_choice=\${1}
package_list=\${2}
update_choice=\${3}

	if [ "\${apt_choice}" = "download" ]
	then
		apt-get install -y -d \${2} 2>>/apt_get_errors.txt
	elif [ "\${apt_choice}" = "install" ]
	then
		apt-get install -y \${2} 2>>/apt_get_errors.txt
	elif [ "\${apt_choice}" = "dep_download" ]
	then
		apt-get build-dep -y -d \${2} 2>>/apt_get_errors.txt
	elif [ "\${apt_choice}" = "dep_install" ]
	then
		apt-get build-dep -y \${2} 2>>/apt_get_errors.txt
	fi
	if [ "\$?" = "0" ]
	then
		echo "Packages '\${2}' \${apt_choice}ed successfully!"
	else
		set -- \${package_list}

		while [ \$# -gt 0 ]
		do
			if [ "\${update_choice}" = "upd" ] && [ ! "\${apt_get_update_done}" = "true" ]
			then
				apt-get update
				apt_get_update_done="true"
			fi
			if [ "\${apt_choice}" = "download" ]
			then
				apt-get install -y -d \${1} 2>>/apt_get_errors.txt
			elif [ "\${apt_choice}" = "install" ]
			then
				apt-get install -y \${1} 2>>/apt_get_errors.txt
			elif [ "\${apt_choice}" = "dep_download" ]
			then
				apt-get build-dep -y -d \${1} 2>>/apt_get_errors.txt
			elif [ "\${apt_choice}" = "dep_install" ]
			then
				apt-get build_dep -y \${1} 2>>/apt_get_errors.txt
			fi
			if [ "\$?" = "0" ]
			then
				echo "'\${1}' \${apt_choice}ed successfully!"
			else
				echo "ERROR while trying to \${apt_choice} '\${1}'."
			fi

			shift
		done
	fi
}
END
elif [ "${apt_choice}" = "download" ] || [ "${apt_choice}" = "install" ]
then
	package_list=${2}
	update_choice=${3}

	if [ "${apt_choice}" = "download" ]
	then
		apt-get install -y -d ${2} 2>>${output_dir}/apt_get_errors.txt
	elif [ "${apt_choice}" = "install" ]
	then
		apt-get install -y ${2} 2>>${output_dir}/apt_get_errors.txt
	elif [ "\${apt_choice}" = "dep_download" ]
	then
		apt-get build-dep -y -d \${2} 2>>${output_dir}/apt_get_errors.txt
	elif [ "\${apt_choice}" = "dep_install" ]
	then
		apt-get build-dep -y \${2} 2>>${output_dir}/apt_get_errors.txt
	fi
	if [ "$?" = "0" ]
	then
		write_log "List of packages '${2}' ${apt_choice}ed successfully!"
	else
		set -- ${package_list}

		while [ $# -gt 0 ]
		do
			if [ "${update_choice}" = "upd" ] && [ ! "${apt_get_update_done}" = "true" ]
			then
				apt-get update
				apt_get_update_done="true"
			fi
			if [ "${apt_choice}" = "download" ]
			then
				apt-get install -y -d ${1} 2>>${output_dir}/apt_get_errors.txt
			elif [ "${apt_choice}" = "install" ]
			then
				apt-get install -y ${1} 2>>${output_dir}/apt_get_errors.txt
			elif [ "\${apt_choice}" = "dep_download" ]
			then
				apt-get build-dep -y -d \${1} 2>>${output_dir}/apt_get_errors.txt
			elif [ "\${apt_choice}" = "dep_install" ]
			then
				apt-get build_dep -y \${1} 2>>${output_dir}/apt_get_errors.txt
			fi
			if [ "$?" = "0" ]
			then
				write_log "'${1}' ${apt_choice}ed successfully!"
			else
				write_log "ERROR while trying to ${apt_choice} '${1}'."
			fi

			shift
		done
	fi
else
	write_log "ERROR: Parameter 1 should either be 'write_script' or 'download' or 'install'.
	Invalid parameter '${apt_choice}' passed to function. Exiting now!"
	exit 91
fi
}
