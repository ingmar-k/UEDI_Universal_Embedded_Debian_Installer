#!/bin/bash
# Bash script that creates a Debian or Emdebian rootfs or even a complete SATA/USB/SD drive/card for a embedded device
# Should run on current Debian or Ubuntu versions
# Author: Ingmar Klein (ingmar.klein@hs-augsburg.de)

# This program (including documentation) is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License version 3 (GPLv3; http://www.gnu.org/licenses/gpl-3.0.html ) for more details.

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


#####################################
##### MAIN Highlevel Functions: #####
#####################################

### Preparation ###

prep_output()
{
	
if [ "${use_cache}" = "yes" -a ! -d ${output_dir_base}/cache ]
then
	mkdir -p ${output_dir_base}/cache
fi

mkdir -p ${output_dir} # main directory for the build process
if [ "$?" = "0" ]
then
	echo "Output directory '${output_dir}' successfully created."
else
	echo "ERROR: Creating the output directory '${output_dir}' did not seem to work.
'mkdir' returned the error code '$?'. Exiting now!"
	exit 5
fi


mkdir ${output_dir}/tmp # subdirectory for all downloaded or local temporary files
if [ "$?" = "0" ]
then
	echo "Subfolder 'tmp' of output directory '${output_dir}' successfully created."
else
	echo "ERROR: Creating the 'tmp' subfolder '${output_dir}/tmp' did not seem to work.
'mkdir' returned the error code '$?'. Exiting now!"
	exit 6
fi
}

### Rootfs Creation ###
build_rootfs()
{
	check_n_install_prerequisites # see if all needed packages are installed and if the versions are sufficient

	create_n_mount_temp_image_file # create the image file that is then used for the rootfs

	do_debootstrap # run debootstrap (first and second stage)
	
	do_post_debootstrap_config # do some further system configuration

	compress_rootfs # compress the resulting rootfs
}


### USB/SATA/SD drive/card creation ###
create_drive()
{
	partition_n_format_disk # drive/card: make partitions and format
	finalize_disk # copy the bootloader, rootfs and kernel to the drive/card
}




#######################################
##### MAIN lower level functions: #####
#######################################

# Description: Check if the user calling the script has the necessary priviliges
check_priviliges()
{
if [[ $UID -ne 0 ]]
then
	echo "ERROR:
'$0' must be run as root/superuser (su/sudo)!
Please try again with the necessary priviliges!!!"
	exit 10
fi
}


# Description: Function to log and echo messages in terminal at the same time
write_log()
{
	if [ -d ${output_dir} ]
	then
		if [ ! "${1:0:6}" = "ERROR:" ]
		then
			log_destination="${output_dir}/std_log.txt"
		else
			log_destination="${output_dir}/error_log.txt"
		fi		
		echo "`date`:   ${1}
------------------------------------------------------------" >> ${log_destination}
		echo "${1}"
	else
		echo "Output directory '${output_dir}' doesn't exist. Exiting now!"
		exit 11
	fi
}


# Description: Function that checks if the needed internet connectivity is there.
check_connectivity()
{
write_log "Checking internet connectivity, which is mandatory for the next step."
for i in google.com kernel.org debian.org ubuntu.com linuxmint.com
do
	for j in {1..3}
	do
		if [ "${j}" = "1" ]
		then
			ping_error="0"
		fi
		ping -v -c 1 ${i}
		if [ ! "$?" = "0" ]
		then 
			ping_error=`expr ${ping_error} + 1`
		fi
		sleep 2 # wait to give the servers some time
	done
	if [ "${ping_error}" = "0" ]
	then 
		write_log "Pinging '${i}' worked. Internet connectivity seems fine."
		#done=1
		break
	elif [ ! "${ping_error}" = "0" -a ! "${i}" = "linuxmint.com" ]
	then
		write_log "ERROR: Pinging '${i}' did NOT work. Internet connectivity seems bad or you are not connected.
Ping encountered ${ping_error} failed attempts, out of 5.
Retrying now, with a new destination address!"
	else
		write_log "ERROR: All ping attempts failed!
You do not appear to be connected to the internet,or your connection is really bad.
Running the script this way will very likely fail!
Exiting now!"
		exit 97
	fi
done
}


# Description: See if the needed packages are installed and if the versions are sufficient
check_n_install_prerequisites()
{
if [ "${host_os}" = "Debian" ]
then
	if [ ! -z "${machine_debian_prereq}" ]
	then
		apt_prerequisites="${apt_prerequisites_debian} ${machine_debian_prereq}"
	else
		apt_prerequisites=${apt_prerequisites_debian}
	fi
elif [ "${host_os}" = "Ubuntu" ]
then
	if [ ! -z "${machine_ubuntu_prereq}" ]
	then
		apt_prerequisites="${apt_prerequisites_ubuntu} ${machine_ubuntu_prereq}"
	else
		apt_prerequisites=${apt_prerequisites_ubuntu}
	fi
else
	echo "OS-Type '${host_os}' not correct.
Please run 'build_emdebian_debian_system.sh --help' for more information"
	exit 12
fi

if [ "${1}" = "uninstall" ]
then
		echo "Trying to uninnstall the prerequisites, now."
		echo "Be VERY careful not to remove any system packages!
____________________________________________________
		
!!!!! READ THE APT HINTS VERY CAREFULLY, PLEASE !!!!!
____________________________________________________"

		set -- ${apt_prerequisites}
		while [ $# -gt 0 ]
		do
			if [ "${1}" = "parted" ] ### parted is a special case, as a lot of system packages depend on it. It would probably be dangerous to remove it, as it would  also remove essential system packages.
			then
				shift
				continue
			fi
			apt-get remove ${1}
			if [ "$?" = "0" ]
			then
				sleep 3
				echo "
				Package '${1}' successfully uninstalled.
				"
			else
				sleep 3
				echo "
				Package '${1}' could not be uninstalled.
'apt-get remove' returned errror code '$?'.
"
			fi
			echo "DONE!"
			shift
		done
else	
	write_log "Installing some packages, if needed."
	
	set -- ${apt_prerequisites}

	while [ $# -gt 0 ]
	do
		dpkg -l |grep "ii  ${1}" >/dev/null
		if [ "$?" = "0" ]
		then
			write_log "Package '${1}' is already installed. Nothing to be done."
		else
			write_log "Package '${1}' is not installed yet.
Trying to install it now!"
			check_connectivity
			if [ ! "${apt_get_update_done}" = "true" ]
			then
				write_log "Running 'apt-get update' to get the latest package dependencies."
				apt-get update
				if [ "$?" = "0" ]
				then
					write_log "'apt-get update' ran successfully! Continuing..."
					apt_get_update_done="true"
				else
					write_log "ERROR: Running 'apt-get update' returned an error code ( '$?' ). Exiting now."
					exit 13
				fi
			fi
			apt-get install -y ${1}
			if [ "$?" = "0" ]
			then
				write_log "'${1}' installed successfully!"
			else
				write_log "ERROR: Running 'apt-get install' for '${1}' returned an error code ( '$?' )."
				if [ "${host_os}" = "Ubuntu" ] && [ "${1}" = "qemu-system" ]
				then
					write_log "Assuming that you are running this on Ubuntu 10.XX, where the package 'qemu-system' doesn't exist.
If your host system is not Ubuntu 10.XX based, this could lead to errors. Please check!"
				else
					write_log "Exiting now!"
					exit 14
				fi
			fi
		fi
		shift
	done
	
	write_log "Function 'check_n_install_prerequisites' DONE."
fi
}


# Description: Create a image file as root-device for the installation process
create_n_mount_temp_image_file()
{
write_log "Creating the temporary image file for the debootstrap process."
dd if=/dev/zero of=${output_dir}/${output_filename}.img bs=1M count=${work_image_size_MB}
if [ "$?" = "0" ]
then
	write_log "File '${output_dir}/${output_filename}.img' successfully created with a size of ${work_image_size_MB}MB."
else
	write_log "ERROR: Creating the file '${output_dir}/${output_filename}.img' did not seem to work.
'dd' returned the error code '$?'. Exiting now!"
	exit 16
fi

write_log "Formatting the image file with the '${rootfs_filesystem_type}' filesystem."
if [ "${rootfs_filesystem_type}" = "ext4" ]
then
	mkfs.${rootfs_filesystem_type} -E lazy_itable_init=0,lazy_journal_init=0 -F ${output_dir}/${output_filename}.img # disable ext4 lazy_initialization, in order to increase performance!
else
	mkfs.${rootfs_filesystem_type} -F ${output_dir}/${output_filename}.img
fi
if [ "$?" = "0" ]
then
	write_log "'${rootfs_filesystem_type}' filesystem successfully created on '${output_dir}/${output_filename}.img'."
else
	write_log "ERROR: Creating the '${rootfs_filesystem_type}' filesystem on  '${output_dir}/${output_filename}.img' didn not seem to work.
'mkfs.${rootfs_filesystem_type}' returned error code '$?'. Exiting now!"
	exit 17
fi

write_log "Creating the directory to mount the temporary filesystem."
mkdir -p ${qemu_mnt_dir}
if [ "$?" = "0" ]
then
	write_log "Directory '${qemu_mnt_dir}' successfully created."
else
	write_log "ERROR: Trying to create the directory '${qemu_mnt_dir}' did not seem to work.
'mkdir' returned error code '$?'. Exiting now!"
	exit 18
fi

write_log "Now mounting the temporary filesystem."
mount ${output_dir}/${output_filename}.img ${qemu_mnt_dir} -o loop
if [ "$?" = "0" ]
then
	write_log "Filesystem correctly mounted on '${qemu_mnt_dir}'."
else
	write_log "ERROR: Trying to mount the filesystem on '${qemu_mnt_dir}' did not seem to work.
'mount' returned error code '$?'. Exiting now!"
	exit 19
fi

write_log "Function 'create_n_mount_temp_image_file' DONE."
}


# Description: Run the debootstrap steps, like initial download, extraction plus configuration and setup
do_debootstrap()
{
	
check_connectivity

write_log "Running first stage of debootstrap now."

if [ "${build_target}" = "emdebian" ]
then
	em_build_target_version="${build_target_version}-grip"
	if [ -f /usr/share/debootstrap/scripts/${build_target_version} ]
	then
		if [ ! -f /usr/share/debootstrap/scripts/${em_build_target_version} ]
		then
			write_log "Creating a symlink now, in order to make debootstrap work."
			cd /usr/share/debootstrap/scripts/ && ln -s ${build_target_version} ${em_build_target_version}
			if [ "$?" = "0" ]
			then
				write_log "Necessary debootstrap script symlink '/usr/share/debootstrap/scripts/${em_build_target_version}' successfully created!"
			else
				write_log "ERROR: Necessary symlink for the debootstrap scripts could NOT be created!
	'ln -s' returned error code '$?'. Exiting now!"
				regular_cleanup
				exit 93
			fi
		else
			write_log "Debootstrap symlink '/usr/share/debootstrap/scripts/${em_build_target_version}'
already in place. Nothing to do." 
		fi
	else
		write_log "ERROR:
Debootstrap script file '/usr/share/debootstrap/scripts/${build_target_version}'
could NOT be found! Exiting now!

ls -alh /usr/share/debootstrap/scripts/:
`ls -alh /usr/share/debootstrap/scripts/`
"
			regular_cleanup
			exit 94
	fi
	build_target_version=${em_build_target_version} # For running debootstrap itself and the sources.list
fi

if [ "${use_cache}" = "yes" ]
then
	if [ -d "${output_dir_base}/cache/" ]
	then
		if [ -e "${output_dir_base}/cache/${base_sys_cache_tarball}" ]
		then
			write_log "Using emdebian/debian debootstrap tarball '${output_dir_base}/cache/${base_sys_cache_tarball}' from cache."
			debootstrap --foreign --keyring=/usr/share/keyrings/${build_target}-archive-keyring.gpg --unpack-tarball="${output_dir_base}/cache/${base_sys_cache_tarball}" --include=${deb_add_packages} --verbose --arch=${machine_debootstrap_arch} --variant=minbase "${build_target_version}" "${qemu_mnt_dir}/" "${target_mirror_url}"
		else
			write_log "No debian/emdebian debootstrap tarball found in cache. Creating one now!"
			debootstrap --foreign --keyring=/usr/share/keyrings/${build_target}-archive-keyring.gpg --make-tarball="${output_dir_base}/cache/${base_sys_cache_tarball}" --include=${deb_add_packages} --verbose --arch=${machine_debootstrap_arch} --variant=minbase "${build_target_version}" "${output_dir_base}/cache/tmp/" "${target_mirror_url}"
			sleep 3
			debootstrap --foreign --keyring=/usr/share/keyrings/${build_target}-archive-keyring.gpg --unpack-tarball="${output_dir_base}/cache/${base_sys_cache_tarball}" --include=${deb_add_packages} --verbose --arch=${machine_debootstrap_arch} --variant=minbase "${build_target_version}" "${qemu_mnt_dir}/" "${target_mirror_url}"
		fi
	fi
else
	write_log "Not using cache, according to the settings. Thus running debootstrap without creating a tarball."
	debootstrap --keyring=/usr/share/keyrings/${build_target}-archive-keyring.gpg --include=${deb_add_packages} --verbose --arch armel --variant=minbase --foreign "${build_target_version}" "${qemu_mnt_dir}" "${target_mirror_url}"
fi

if [ "$?" = "0" ]
then
	write_log "Debootstrap's first stage ran successfully!"
else
	write_log "ERROR: While trying to run the first part of the debootstrap operations an error occurred.
'debootstrap' returned error code '$?'. Exiting now!"
	regular_cleanup
	exit 95
fi


write_log "Starting the second stage of debootstrap now."
echo "#!/bin/bash
/debootstrap/debootstrap --second-stage 2>>/debootstrap_stg2_errors.txt
cd /root 2>>/debootstrap_stg2_errors.txt

cat <<END > /etc/apt/sources.list 2>>/debootstrap_stg2_errors.txt
deb ${target_mirror_url} ${build_target_version} ${target_repositories}
deb-src ${target_mirror_url} ${build_target_version} ${target_repositories}
END

if [ \"${build_target}\" = \"debian\" ]
then
	if [ \"${build_target_version}\" = \"stable\" ] || [ \"${build_target_version}\" = \"wheezy\" ] || [ \"${build_target_version}\" = \"testing\" ] || [ \"${build_target_version}\" = \"jessie\" ]
	then
		cat <<END >>/etc/apt/sources.list 2>>/debootstrap_stg2_errors.txt
deb ${target_mirror_url} ${build_target_version}-updates ${target_repositories}
deb-src ${target_mirror_url} ${build_target_version}-updates ${target_repositories}
deb http://security.debian.org/ ${build_target_version}/updates ${target_repositories}
deb-src http://security.debian.org/ ${build_target_version}/updates ${target_repositories}
END
	fi
fi

apt-get update

mknod /dev/${console_device} c 4 64	# for the serial console 2>>/debootstrap_stg2_errors.txt

cat <<END > /etc/network/interfaces
auto lo ${interfaces_auto}
iface lo inet loopback
END

if [ ! -z \"${ethernet_interface}\" ]
then
	if [ ! -z \"${machine_mac_address}\" ]
	then
		cat <<END >> /etc/network/interfaces
hwaddress ether ${machine_mac_address}
END
	fi
	if [ \"${ip_type}\" = \"dhcp\" ]
	then
		cat <<END >> /etc/network/interfaces
iface ${ethernet_interface} inet dhcp
END
	elif [ \"${ip_type}\" = \"static\" ]
	then
		cat <<END >> /etc/network/interfaces
iface ${ethernet_interface} inet static
address ${static_ip}
netmask ${netmask}
gateway ${gateway_ip}
END
	fi
fi

if [ ! -z \"${wireless_interface}\" ]
then
	if [ \"${ip_type_wireless}\" = \"dhcp\" ]
	then
		cat <<END >> /etc/network/interfaces
iface ${wireless_interface} inet dhcp
wpa-driver wext
wpa-ssid ${wireless_ssid}
wpa-ap-scan 1
wpa-proto RSN
wpa-pairwise CCMP
wpa-group CCMP
wpa-key-mgmt WPA-PSK
wpa-psk ${wireless_password}
END
	elif [ \"${ip_type_wireless}\" = \"static\" ]
	then
		cat <<END >> /etc/network/interfaces
iface ${wireless_interface} inet static
address ${wireless_static_ip}
netmask ${wireless_netmask}
network ${wireless_static_ip%.*}.0
broadcast ${wireless_static_ip%.*}.255
gateway ${wireless_gateway_ip}
dns-nameservers ${nameserver_addr}
wpa-ssid ${wireless_ssid}
wpa-psk ${wireless_password}
END
	fi
fi

echo ${hostname} > /etc/hostname 2>>/debootstrap_stg2_errors.txt

echo \"127.0.0.1 ${hostname}
127.0.0.1 localhost\" >> /etc/hosts 2>>/debootstrap_stg2_errors.txt
echo \"nameserver ${nameserver_addr}\" > /etc/resolv.conf 2>>/debootstrap_stg2_errors.txt

cat <<END > /etc/rc.local 2>>/debootstrap_stg2_errors.txt
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will exit 0 on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

if [ -f /etc/init.d/compressed_swapspace.sh ]
then
	update-rc.d compressed_swapspace.sh defaults 2>>/debootstrap_stg2_errors.txt
fi

/setup.sh 2>/setup_log.txt && rm /setup.sh

exit 0
END

rm /debootstrap_pt1.sh
exit 0" > ${qemu_mnt_dir}/debootstrap_pt1.sh
chmod +x ${qemu_mnt_dir}/debootstrap_pt1.sh

modprobe binfmt_misc && write_log "'modprobe binfmt_misc' successfully done!" || write_log "ERROR: 'modprobe binfmt_misc' failed!"

cp /usr/bin/qemu-arm-static ${qemu_mnt_dir}/usr/bin && write_log "'cp /usr/bin/qemu-arm-static ${qemu_mnt_dir}/usr/bin' successfully done!" || write_log "ERROR: 'cp /usr/bin/qemu-arm-static ${qemu_mnt_dir}/usr/bin' failed!"

mkdir -p ${qemu_mnt_dir}/dev/pts

write_log "Mounting both /dev/pts and /proc on the temporary filesystem."
mount devpts ${qemu_mnt_dir}/dev/pts -t devpts && write_log "'mount devpts ${qemu_mnt_dir}/dev/pts -t devpts' successfully done!" || write_log "ERROR: 'mount devpts ${qemu_mnt_dir}/dev/pts -t devpts' failed!"
mount -t proc proc ${qemu_mnt_dir}/proc && write_log "'mount -t proc proc ${qemu_mnt_dir}/proc' successfully done!" || write_log "ERROR: 'mount -t proc proc ${qemu_mnt_dir}/proc' failed!"

write_log "Entering chroot environment NOW!"
/usr/sbin/chroot ${qemu_mnt_dir} /bin/bash /debootstrap_pt1.sh 2>${output_dir}/debootstrap_pt1_errors.txt || write_log "ERROR:'/usr/sbin/chroot ${qemu_mnt_dir} /bin/bash /debootstrap_pt1.sh' failed."
if [ "$?" = "0" ]
then
	write_log "First part of chroot operations done successfully!"
else
	write_log "ERROR: While trying to run the first part of the chroot operations an error occurred.
'chroot' returned error code '$?'."
fi

if [ "${use_cache}" = "yes" ]
then
	add_pack_tarball_name="${add_pack_tarball_basename}"
	if [ -z "${additional_desktop_packages}" -a -z "${additional_dev_packages}" -a -z "${additional_wireless_packagese}" ] # case 1: none (0)
	then
		write_log "No additional desktop, development and/or wireless packages were specified."
	elif [ -z "${additional_desktop_packages}" -a -z "${additional_dev_packages}" -a ! -z "${additional_wireless_packages}" ] # case 2: only wifi (1)
	then
		add_pack_tarball_name="${add_pack_tarball_basename}_incl_wifi"
		write_log "Additional wireless packages were specified."
	elif [ -z "${additional_desktop_packages}" -a ! -z "${additional_dev_packages}" -a -z "${additional_wireless_packages}" ] # case 3: only dev (1)
	then
		add_pack_tarball_name="${add_pack_tarball_basename}_incl_dev"
		write_log "Additional development packages were specified."
	elif [ ! -z "${additional_desktop_packages}" -a -z "${additional_dev_packages}" -a -z "${additional_wireless_packages}" ] # case 4: only desktop (1)
	then
		add_pack_tarball_name="${add_pack_tarball_basename}_incl_desktop"
		write_log "Additional desktop packages were specified."
	elif [ ! -z "${additional_desktop_packages}" -a ! -z "${additional_dev_packages}" -a -z "${additional_wireless_packages}" ] # case 5: desktop and dev (2)
	then
		add_pack_tarball_name="${add_pack_tarball_basename}_incl_desktop_dev"
		write_log "Additional desktop and development packages were specified."
	elif [ -z "${additional_desktop_packages}" -a ! -z "${additional_dev_packages}" -a ! -z "${additional_wireless_packages}" ] # case 6: dev and wifi (2)
	then
		add_pack_tarball_name="${add_pack_tarball_basename}_incl_dev_wifi"
		write_log "Additional development and wireless packages were specified."
	elif [ ! -z "${additional_desktop_packages}" -a -z "${additional_dev_packages}" -a ! -z "${additional_wireless_packages}" ] # case 7: desktop and  wifi (2)
	then
		add_pack_tarball_name="${add_pack_tarball_basename}_incl_desktop_wifi"
		write_log "Additional desktop and wireless packages were specified."
	elif [ ! -z "${additional_desktop_packages}" -a ! -z "${additional_dev_packages}" -a ! -z "${additional_wireless_packages}" ] # case 8: all, desktop, dev and wifi (3)
	then
		add_pack_tarball_name="${add_pack_tarball_basename}_incl_desktop_dev_wifi"
		write_log "Additional desktop, development and wireless packages were specified."
	else
		write_log "ERROR: No matching configuration of additional packages found.
Exiting now!"
		regular_cleanup
		exit 96
	fi

	if [ -f ${output_dir_base}/cache/${add_pack_tarball_name}.tar.${tar_format} ]
	then
		write_log "Extracting additional packages archive '${add_pack_tarball_name}.tar.${tar_format}' from cache. now."
		tar_all extract "${output_dir_base}/cache/${add_pack_tarball_name}.tar.${tar_format}" "${qemu_mnt_dir}/var/cache/apt/" 
	elif [ ! -f ${output_dir_base}/cache/${add_pack_tarball_name}.tar.${tar_format} ]
	then
		write_log "No compressed archive '${add_pack_tarball_name}.tar.${tar_format}' found in the cache directory.
Creating it now!"
		add_pack_create="yes"
	fi

fi

echo "#!/bin/bash
export LANG=C 2>>/debootstrap_stg2_errors.txt

apt-key update
apt-get -d -y --force-yes install ${additional_packages} 2>>/debootstrap_stg2_errors.txt

if [ ! -z \"${additional_desktop_packages}\" ]
then
	apt-get -d -y --force-yes install ${additional_desktop_packages} 2>>/debootstrap_stg2_errors.txt
fi

if [ ! -z \"${additional_dev_packages}\" ]
then
	apt-get -d -y --force-yes install ${additional_dev_packages} 2>>/debootstrap_stg2_errors.txt
fi

if [ ! -z \"${additional_wireless_packages}\" ]
then
	apt-get -d -y --force-yes install ${additional_wireless_packages} 2>>/debootstrap_stg2_errors.txt
fi
if [ -f /etc/locale.gen ]
then
	for k in ${locale_list}; do sed -i 's/# '\${k}'/'\${k}'/g' /etc/locale.gen; done;
	locale-gen 2>>/debootstrap_stg2_errors.txt
else
	echo 'ERROR! /etc/locale.gen not found!'
	echo 'ERROR! /etc/locale.gen not found!' >>/debootstrap_stg2_errors.txt
fi

export LANG=${std_locale} 2>>/debootstrap_stg2_errors.txt	# language settings
export LC_ALL=${std_locale} 2>>/debootstrap_stg2_errors.txt
export LANGUAGE=${std_locale} 2>>/debootstrap_stg2_errors.txt

cat <<END > /etc/fstab 2>>/debootstrap_stg2_errors.txt
# /etc/fstab: static file system information.
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
/dev/root	/	${rootfs_filesystem_type}	defaults	0	1
END

if [ ! -z \"${swap_partition}\" ]
then
	cat <<END >> /etc/fstab 2>>/debootstrap_stg2_errors.txt
${swap_partition}	none	swap	defaults,pri=10	0	0
END
fi

cat <<END >> /etc/fstab 2>>/debootstrap_stg2_errors.txt
none		/tmp	tmpfs	defaults	0	0
none		/var/spool	tmpfs	defaults,noatime,mode=1777	0	0
none		/var/tmp	tmpfs	defaults	0	0
none		/var/log	tmpfs	defaults,noatime,mode=0755	0	0
END

sed -i 's/^\([1-6]:.* tty[1-6]\)/#\1/' /etc/inittab 2>>/debootstrap_stg2_errors.txt
echo '#T0:2345:respawn:/sbin/getty -L ${console_device} ${console_baudrate} vt100' >> /etc/inittab 2>>/debootstrap_stg2_errors.txt	# insert (temporarily commented!) entry for serial console

echo \"${time_zone}\" > /etc/timezone
dpkg-reconfigure --frontend noninteractive tzdata

rm /debootstrap_pt2.sh
exit 0" > ${qemu_mnt_dir}/debootstrap_pt2.sh
chmod +x ${qemu_mnt_dir}/debootstrap_pt2.sh

write_log "Mounting both /dev/pts and /proc on the temporary filesystem."
mount devpts ${qemu_mnt_dir}/dev/pts -t devpts
mount -t proc proc ${qemu_mnt_dir}/proc

write_log "Entering chroot environment NOW!"
/usr/sbin/chroot "${qemu_mnt_dir}" /bin/bash /debootstrap_pt2.sh 2>${output_dir}/debootstrap_pt2_errors.txt

if [ "$?" = "0" ]
then
	write_log "Second part of chroot operations done successfully!"
else
	write_log "ERROR: While trying to run the second part of the chroot operations an error occurred.
'chroot' returned error code '$?'."
fi

if [ "${add_pack_create}" = "yes" ]
then
	write_log "Compressing additional packages, in order to save them in the cache directory."
	cd ${qemu_mnt_dir}/var/cache/apt/
	tar_all compress "${output_dir_base}/cache/${add_pack_tarball_name}.tar.${tar_format}" .
	write_log "Successfully created compressed cache archive of additional packages."
	cd ${output_dir}
fi

sleep 5
umount_img sys
write_log "Just exited chroot environment."
write_log "Base debootstrap steps 1&2 are DONE!"
}


# Description: Do some further configuration of the system, after debootstrap has finished
do_post_debootstrap_config()
{

write_log "Now starting the post-debootstrap configuration steps."
mkdir -p ${output_dir}/qemu-kernel

if [ "${use_cache}" = "yes" ]
then
	if [ -e ${output_dir_base}/cache/${std_kernel_pkg##*/} ]
	then
		write_log "Found standard kernel package in cache. Just linking it locally now."
		ln -s ${output_dir_base}/cache/${std_kernel_pkg##*/} ${output_dir}/tmp/${std_kernel_pkg##*/}
	else
		write_log "Standard kernel package NOT found in cache. Getting it now and copying it to cache."
		get_n_check_file "${std_kernel_pkg}" "standard_kernel" "${output_dir}/tmp"
		cp ${output_dir}/tmp/${std_kernel_pkg##*/} ${output_dir_base}/cache/
	fi
	if [ -e ${output_dir_base}/cache/${qemu_kernel_pkg##*/} ]
	then
		write_log "Found qemu kernel package in cache. Just linking it locally now."
		ln -s ${output_dir_base}/cache/${qemu_kernel_pkg##*/} ${output_dir}/tmp/${qemu_kernel_pkg##*/}
	else
		write_log "Qemu kernel package NOT found in cache. Getting it now and copying it to cache."
		get_n_check_file "${qemu_kernel_pkg}" "qemu_kernel" "${output_dir}/tmp"
		cp ${output_dir}/tmp/${qemu_kernel_pkg##*/} ${output_dir_base}/cache/
	fi
else	
	get_n_check_file "${std_kernel_pkg}" "standard_kernel" "${output_dir}/tmp"
	get_n_check_file "${qemu_kernel_pkg}" "qemu_kernel" "${output_dir}/tmp"
fi

	tar_all extract "${output_dir}/tmp/${qemu_kernel_pkg##*/}" "${output_dir}/qemu-kernel"
	sleep 1
	tar_all extract "${output_dir}/tmp/${std_kernel_pkg##*/}" "${qemu_mnt_dir}"
	sleep 1
	
		
if [ -d ${output_dir}/qemu-kernel/lib/ ]
then
	cp -ar ${output_dir}/qemu-kernel/lib/ ${qemu_mnt_dir}  # copy the qemu kernel modules into the rootfs
fi
sync
chown root:root ${output_dir}/mnt_debootstrap/lib/modules/ -R

if [ "${external_bootloader}" = "yes" ]
then
	if [ "${use_cache}" = "yes" ]
	then
		#tar_all extract "${output_dir}/tmp/${bootloader_package##*/}" "${output_dir}/tmp"
		sleep 1
		if [ -e ${output_dir_base}/cache/${bootloader_package##*/} ]
		then
			write_log "Found external bootloader package in cache. Just linking it locally now."
			ln -s ${output_dir_base}/cache/${bootloader_package##*/} ${output_dir}/tmp/${bootloader_package##*/}
		else
			write_log "External bootloader package NOT found in cache. Getting it now and copying it to cache."
			get_n_check_file "${bootloader_package}" "external bootloader package" "${output_dir}/tmp"
			cp ${output_dir}/tmp/${bootloader_package##*/} ${output_dir_base}/cache/
		fi
	else
		get_n_check_file "${bootloader_package}" "external bootloader package" "${output_dir}/tmp"
	fi
	tar_all extract "${output_dir}/tmp/${bootloader_package##*/}" "${output_dir}/tmp"
	tar_all extract "${output_dir}/tmp/${std_kernel_pkg##*/}" "${output_dir}/tmp"
fi

if [ ! -z "${module_load_list}" ]
then
	for i in ${module_load_list}
	do
		cat<<END>>${output_dir}/mnt_debootstrap/etc/modules 2>>/post_debootstrap_config_errors.txt
${i} 
END
	done
fi

if [ "${use_compressed_swapspace}" = "yes" ]
then
	if [ "${compressed_swapspace_module_name}" = "ramzswap" ]
	then
		echo "#!/bin/bash

### BEGIN INIT INFO
# Provides: ramzswap
# Required-Start:
# Required-Stop:
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: ramzswap, compressed swapspace in RAM
# Description: ramzswap provides a compressed swapspace in RAM, that can increase performance in memory limited systems (today it is mostly superceeded by 'zram')
### END INIT INFO

# Include lsb init-functions
. /lib/lsb/init-functions

start() {

	modprobe ${compressed_swapspace_module_name} ${compressed_swapspace_nr_option_name}=${compressed_swapspace_blkdev_count} disksize_kb=`expr ${compressed_swapspace_size_MB} \* 1024`
	sleep 1
	for n in {1..${compressed_swapspace_blkdev_count}}
	do
		z=\`expr \${n} - 1\`
		mkswap -L ramzswap_\${z} /dev/ramzswap\${z}
		sleep 1
		swapon -p ${compressed_swapspace_priority} /dev/ramzswap\${z}
	done
}

stop() {
	for n in {1..${compressed_swapspace_blkdev_count}}
	do
		z=\`expr \${n} - 1\`
		swapoff /dev/ramzswap\${z}
		sleep 1
	done
}

case \"\$1\" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        sleep 2
        start
        ;;
    *)
        echo \"Usage: \$0 {start|stop|restart}\"
        RETVAL=1
esac" > ${output_dir}/mnt_debootstrap/etc/init.d/compressed_swapspace.sh
	elif [ "${compressed_swapspace_module_name}" = "zram" ]
	then
		echo "#!/bin/bash

### BEGIN INIT INFO
# Provides: zram
# Required-Start:
# Required-Stop:
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: zram, compressed swapspace in RAM
# Description: zram provides a compressed swapspace in RAM, that can increase performance in memory limited systems
### END INIT INFO

# Include lsb init-functions
. /lib/lsb/init-functions

start() {
	modprobe ${compressed_swapspace_module_name} ${compressed_swapspace_nr_option_name}=${compressed_swapspace_blkdev_count}
	sleep 1
	for n in {1..${compressed_swapspace_blkdev_count}}
	do
		z=\`expr \${n} - 1\`
		echo `expr ${compressed_swapspace_size_MB} \* 1024 \* 1024` > /sys/block/zram\${z}/disksize
		sleep 1
		mkswap -L zram_\${z} /dev/zram\${z}
		sleep 1
		swapon -p ${compressed_swapspace_priority} /dev/zram\${z}
	done
}

stop() {
	for n in {1..${compressed_swapspace_blkdev_count}}
	do
		z=\`expr \${n} - 1\`
		swapoff /dev/zram\${z}
		sleep 1
	done
}

case \"\$1\" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        sleep 2
        start
        ;;
    *)
        echo \"Usage: \$0 {start|stop|restart}\"
        RETVAL=1
esac
" > ${output_dir}/mnt_debootstrap/etc/init.d/compressed_swapspace.sh
	else
		write_log "ERROR: Variable 'use_compressed_swapspace' was set to 'yes, however
NO VALID SETTING for 'compressed_swapspace_module_name' was found!
Valid settings are either 'ramzswap', or 'zram'. You used a setting of '${compressed_swapspace_module_name}'."
	fi
else
	write_log "Not using compressed swapspace.
Setting for variable 'use_compressed_swapspace' was '${use_compressed_swapspace}'."
fi
chmod +x ${output_dir}/mnt_debootstrap/etc/init.d/compressed_swapspace.sh

echo "#!/bin/bash
echo \"Creating a swapfile now, with a size of '`expr ${qemu_mem_size} \/ 2` MB'.\"
dd if=/dev/zero of=/swapfile bs=1M count=`expr ${qemu_mem_size} \/ 2`   ### swapfile, the same size as the qemu memory setting
mkswap /swapfile
chown root:root /swapfile
chmod 0600 /swapfile
swapon -p 10 /swapfile

if [ -e /dev/zram0 ]
then
	echo `expr ${qemu_mem_size} \/ 8 \* 6 \* 1024 \* 1024` > /sys/block/zram0/disksize
	mkswap -L \"zram_swap\" /dev/zram0
	sleep 1
	swapon -p 32767 /dev/zram0
else
	echo -e \"\nNot using zram!\n\"
fi

swapon -s
sleep 5

apt-get -y --force-yes install ${additional_packages} 2>>/post_debootstrap_errors.txt

if [ ! -z \"${additional_desktop_packages}\" ]
then
	apt-get -y --force-yes install ${additional_desktop_packages} 2>>/debootstrap_stg2_errors.txt
fi

if [ ! -z \"${additional_dev_packages}\" ]
then
	apt-get -y --force-yes install ${additional_dev_packages} 2>>/debootstrap_stg2_errors.txt
fi

if [ ! -z \"${additional_wireless_packages}\" ]
then
	apt-get -y --force-yes install ${additional_wireless_packages} 2>>/debootstrap_stg2_errors.txt
fi
apt-get clean	# installed the already downloaded packages

if [ \"${use_compressed_swapspace}\" = \"yes\" ]
then
	if [ ! -z \"${vm_swappiness}\" ]
	then
		echo vm.swappiness=${vm_swappiness} >> /etc/sysctl.conf
	fi
fi

if [ ! -z `grep setup.sh /etc/rc.local` ] # write a clean 'rc.local for the qemu-process'
then
	cat <<END > /etc/rc.local 2>>/post_debootstrap_errors.txt
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will exit 0 on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

exit 0
END
fi

cat <<END > /etc/default/rcS 2>>/debootstrap_stg2_errors.txt
#
# /etc/default/rcS
#
# Default settings for the scripts in /etc/rcS.d/
#
# For information about these variables see the rcS(5) manual page.
#
# This file belongs to the \"initscripts\" package.

# delete files in /tmp during boot older than x days.
# '0' means always, -1 or 'infinite' disables the feature
#TMPTIME=0

# spawn sulogin during boot, continue normal boot if not used in 30 seconds
#SULOGIN=no

# do not allow users to log in until the boot has completed
#DELAYLOGIN=no

# be more verbose during the boot process
#VERBOSE=no

# automatically repair filesystems with inconsistencies during boot
#FSCKFIX=noTMPTIME=0
SULOGIN=no
DELAYLOGIN=no
VERBOSE=no
FSCKFIX=yes

END

cat <<END > /etc/default/tmpfs 2>>/debootstrap_stg2_errors.txt
# Configuration for tmpfs filesystems mounted in early boot, before
# filesystems from /etc/fstab are mounted.  For information about
# these variables see the tmpfs(5) manual page.

# /run is always mounted as a tmpfs on systems which support tmpfs
# mounts.

# mount /run/lock as a tmpfs (separately from /run).  Defaults to yes;
# set to no to disable (/run/lock will then be part of the /run tmpfs,
# if available).
#RAMLOCK=yes

# mount /run/shm as a tmpfs (separately from /run).  Defaults to yes;
# set to no to disable (/run/shm will then be part of the /run tmpfs,
# if available).
#RAMSHM=yes

# mount /tmp as a tmpfs.  Defaults to no; set to yes to enable (/tmp
# will be part of the root filesystem if disabled).  /tmp may also be
# configured to be a separate mount in /etc/fstab.
#RAMTMP=no

# Size limits.  Please see tmpfs(5) for details on how to configure
# tmpfs size limits.
#TMPFS_SIZE=20%VM
#RUN_SIZE=10%
#LOCK_SIZE=5242880 # 5MiB
#SHM_SIZE=
#TMP_SIZE=

# Mount tmpfs on /tmp if there is less than the limit size (in kiB) on
# the root filesystem (overriding RAMTMP).
#TMP_OVERFLOW_LIMIT=1024

RAMTMP=yes
END

ldconfig

echo -e \"${root_password}\n${root_password}\n\" | passwd root 2>>/post_debootstrap_errors.txt
passwd -u root 2>>/post_debootstrap_errors.txt
passwd -x -1 root 2>>/post_debootstrap_errors.txt
passwd -w -1 root 2>>/post_debootstrap_errors.txt

echo -e \"${user_password}\n${user_password}\n\n\n\n\n\n\n\" | adduser ${username} 2>>/post_debootstrap_errors.txt

sed -i 's<#T0:2345:respawn:/sbin/getty<T0:2345:respawn:/sbin/getty<g' /etc/inittab
dpkg -l >/installed_packages.txt
df -ah > /disk_usage.txt


reboot 2>>/post_debootstrap_errors.txt
exit 0" > ${output_dir}/mnt_debootstrap/setup.sh
chmod +x ${output_dir}/mnt_debootstrap/setup.sh

sleep 1

if [ ! -z "${extra_files}" ]
then
	set -- ${extra_files}
	while [ $# -gt 0 ]
	do
		extra_files_name=${1##*/}
		if [ "${use_cache}" = "yes" ]
		then
			if [ -e ${output_dir_base}/cache/${extra_files_name} ]
			then
				write_log "Found extra file '${extra_files_name}' in cache. Just linking it locally now."
				ln -s ${output_dir_base}/cache/${extra_files_name} ${output_dir}/tmp/${extra_files_name}
			else
				write_log "Extra file '${extra_files_name}' NOT found in cache. Getting it now and copying it to cache."
				get_n_check_file "${1}" "${extra_files_name}" "${output_dir}/tmp"
				cp ${output_dir}/tmp/${extra_files_name} ${output_dir_base}/cache/
			fi
		else
			get_n_check_file "${1}" "${extra_files_name}" "${output_dir}/tmp"
		fi
		
		tar_all extract "${output_dir}/tmp/${extra_files_name}" "${output_dir}/mnt_debootstrap/"
		if [ "$?" = "0" ]
		then
			write_log "Successfully extracted '${extra_files_name}' into the created rootfs."
		else
			write_log "ERROR: While trying to extract '${extra_files_name}' into the created rootfs an error occurred!
Function 'tar_all extract' rerurned error code '$?'."
		fi
		shift
	done
else
	write_log "Variable 'extra_files' appears to be empty. No additional files extracted into the completed rootfs."
fi

### run machine specific configuration
do_post_debootstrap_config_machine

umount_img all
if [ "$?" = "0" ]
then
	write_log "Filesystem image file successfully unmounted. Ready to continue."
else
	write_log "ERROR: While trying to unmount the filesystem image an error occured.
Function 'umount_img all' returned error code '$?'. Exiting now!"
	exit 50
fi

sleep 5

mount |grep "${output_dir}/mnt_debootstrap" > /dev/null
if [ ! "$?" = "0" ]
then
	write_log "Starting the qemu environment now!"
	qemu-system-${qemu_arch} -M ${qemu_machine_type} -cpu ${qemu_cpu_type} ${qemu_extra_options} -no-reboot -kernel ${output_dir}/qemu-kernel/zImage ${qemu_hdd_mount} -m ${qemu_mem_size} -append "${qemu_kernel_cmdline}" 2>qemu_error_log.txt
	if [ "$?" = "0" ]
	then
		write_log "'qemu-system-${qemu_arch}' seems to have closed cleanly. DONE!"
	else
		write_log "ERROR: 'qemu-system-${qemu_arch}' returned error code '$?'.
Exiting now!"
		regular_cleanup
		exit 51
	fi
else
	write_log "ERROR: Filesystem is still mounted. Can't run qemu!
'qemu-system-arm' returned error code '$?'. Exiting now!"
	regular_cleanup
	exit 52
fi

write_log "Additional chroot system configuration successfully finished!"

}


# Description: Compress the resulting rootfs
compress_rootfs()
{
write_log "Compressing the rootfs now!"

mount |grep ${output_dir}/${output_filename}.img 2>/dev/null
if [ ! "$?" = "0" ]
then 
	write_log "Running 'fsck' on the temporary rootfs, now.
Please be patient! This could take some time (depending on the image size)."
	fsck.${rootfs_filesystem_type} -fy ${output_dir}/${output_filename}.img
	if [ "$?" = "0" ]
	then
		write_log "Temporary filesystem checked out, OK!"
	else
		fsck.${rootfs_filesystem_type} -fy ${output_dir}/${output_filename}.img # run it again, to be sure!!!
		if [ "$?" = "0" ]
		then
			write_log "Temporary filesystem checked out, OK (second try)!"
		else
			write_log "ERROR: State of Temporary filesystem is NOT OK!
'fsck.${rootfs_filesystem_type}' returned error code '$?'. Exiting now."
			regular_cleanup
			exit 24
		fi
	fi
else
	write_log "ERROR: Image file still mounted.
'mount' returned error code '$?'. Exiting now!"
	regular_cleanup
	exit 25
fi

mount ${output_dir}/${output_filename}.img ${qemu_mnt_dir} -o loop
if [ "$?" = "0" ]
then
	cd ${qemu_mnt_dir}
	if [ "${tar_format}" = "bz2" -o "${tar_format}" = "gz" -o "${tar_format}" = "xz" ]
	then
		if [ -f ${qemu_mnt_dir}/usr/bin/qemu-user-static ]
		then
			rm ${qemu_mnt_dir}/usr/bin/qemu-user-static
		fi
		write_log "Successfully mounted the created filesystem.
Now compressing it into a single archive file '${output_dir}/${output_filename}.tar.${tar_format}'.
Please be patient! This could take some time (depending on the image size)."
		tar_all compress "${output_dir}/${output_filename}.tar.${tar_format}" . && write_log "Compression finished without errors. Archive file ready!"
	else
		write_log "Incorrect setting '${tar_format}' for the variable 'tar_format' in the general_settings.sh.
Please check! Only valid entries are 'bz2' or 'gz'. Could not compress the Rootfs!"
	fi

	cd ${output_dir}
	sleep 5
else
	write_log "ERROR: Image file could not be remounted correctly.
'mount' returned error code '$?'- Exiting now!"
	regular_cleanup
	exit 26
fi

umount ${qemu_mnt_dir}
sleep 10
mount | grep ${qemu_mnt_dir} > /dev/null
if [ ! "$?" = "0" ] && [ "${clean_tmp_files}" = "yes" ]
then
	rm -r ${qemu_mnt_dir}
	rm -r ${output_dir}/qemu-kernel
	rm ${output_dir}/${output_filename}.img
elif [ "$?" = "0" ] && [ "${clean_tmp_files}" = "yes" ]
then
	write_log "Directory '${qemu_mnt_dir}' is still mounted, so it can't be removed. Exiting now!"
	regular_cleanup
	exit 27
elif [ "$?" = "0" ] && [ "${clean_tmp_files}" = "no" ]
then
	write_log "Directory '${qemu_mnt_dir}' is still mounted, please check. Exiting now!"
	regular_cleanup
	exit 28
fi

write_log "Rootfs successfully DONE!"
}


#############################
##### HELPER Functions: #####
#############################


# Description: Helper funtion for all tar-related tasks
tar_all()
{
if [ "$1" = "compress" ]
then
	if [ -d "${2%/*}"  ]
	then
		if [ -d "${3}" -o -f "${3}" ]
		then
			if [ "${2:(-8)}" = ".tar.bz2" ] || [ "${2:(-5)}" = ".tbz2" ]
			then
				tar -cpjvf "${2}" "${3}"
			elif [ "${2:(-7)}" = ".tar.gz" ] || [ "${2:(-4)}" = ".tgz" ]
			then
				tar -cpzvf "${2}" "${3}"
			elif [ "${2:(-7)}" = ".tar.xz" ] || [ "${2:(-4)}" = ".txz" ]
			then
				tar -cpJvf "${2}" "${3}"
			else
				write_log "ERROR: Created files can only be of type '.tar.gz', '.tgz', '.tbz2', or '.tar.bz2'!
	Used call parameters were:
	1: '${1}'
	2: '${2}'
	3: '${3}'
	Exiting now!"
				regular_cleanup
				exit 37
			fi
		else
			write_log "ERROR: Illegal argument '3' (what to compress).
Used call parameters were:
1: '${1}'
2: '${2}'
3: '${3}'
Exiting now!"
			regular_cleanup
			exit 38
		fi
	else
		write_log "ERROR: Illegal argument '2' (what archive to create).
Used call parameters were:
1: '${1}'
2: '${2}'
3: '${3}'
Exiting now!"
		regular_cleanup
		exit 39
	fi
elif [ "$1" = "extract" ]
then
	if [ -f "${2}"  ]
	then
		if [ -d "${3}" ]
		then
			if [ "${2:(-8)}" = ".tar.bz2" ] || [ "${2:(-5)}" = ".tbz2" ]
			then
				tar -xpjvf "${2}" -C "${3}"
			elif [ "${2:(-7)}" = ".tar.gz" ] || [ "${2:(-4)}" = ".tgz" ]
			then
				tar -xpzvf "${2}" -C "${3}"
			elif [ "${2:(-7)}" = ".tar.xz" ] || [ "${2:(-4)}" = ".txz" ]
			then
				tar -xpJvf "${2}" -C "${3}"
			else
				write_log "ERROR: Can only extract files of type '.tar.gz', '.tar.bz2', or 'tar.xz'!
	'${2}' doesn't seem to fit that requirement.
	Used call parameters were:
	1: '${1}'
	2: '${2}'
	3: '${3}'
	Exiting now!"
				regular_cleanup
				exit 40
			fi
		else
			write_log "ERROR: Illegal arguments '3' (where to extract to).
Used call parameters were:
1: '${1}'
2: '${2}'
3: '${3}'
Exiting now!"
			regular_cleanup
		exit 41
		fi
	else
		write_log "ERROR: Illegal arguments '2' (what archive to extract).
Used call parameters were:
1: '${1}'
2: '${2}'
3: '${3}'
Exiting now!"
		regular_cleanup
		exit 42
	fi
else
	write_log "ERROR: The first parameter needs to be either 'compress' or 'extract', and NOT '${1}'.
Used call parameters were:
1: '${1}'
2: '${2}'
3: '${3}'
Exiting now!"
	regular_cleanup
	exit 43
fi
}


# Description: Helper function to completely or partially unmount the image file when and where needed
umount_img()
{
cd ${output_dir}
if [ "${1}" = "sys" ] || [ "${1}" = "all" ]
then
	write_log "Function 'umount_img' called with parameter '$1'."
	mount | grep "${qemu_mnt_dir}" >/dev/null
	if [ "$?" = "0"  ]
	then
		write_log "Virtual Image still mounted. Trying to umount now!"
		sleep 2
		write_log "Trying to unmount the 'proc' filesystem."
		umount ${qemu_mnt_dir}/proc 2>/dev/null
		echo "Return value was '$?'."
		sleep 10
		write_log "Trying to unmount the 'pts' filesystem."
		umount ${qemu_mnt_dir}/dev/pts 2>/dev/null
		echo "Return value was '$?'."
		sleep 10
		write_log "Trying to unmount the 'sys' filesystem."
		umount ${qemu_mnt_dir}/sys 2>/dev/null
		echo "Return value was '$?'."
		sleep 5
		if [ "${1}" = "all" ]
		then
			write_log "Trying to unmount the 'qemu_rootfs' filesystem."
			umount ${qemu_mnt_dir}/ 2>/dev/null
			echo "Return value was '$?'."
			sleep 2
		fi
		if [ "${1}" = "sys" ]
		then
			mount | egrep '(${qemu_mnt_dir}/sys|${qemu_mnt_dir}/proc|${qemu_mnt_dir}/dev/pts)' >/dev/null
		else
			mount | egrep '(${qemu_mnt_dir}/sys|${qemu_mnt_dir}/proc|${qemu_mnt_dir}/dev/pts|${qemu_mnt_dir})' >/dev/null
		fi
	
		if [ "$?" = "0"  ]
		then
			if [ "${1}" = "sys" ]
			then
				write_log "ERROR: Something went wrong. All subdirectories of '${output_dir}' should have been unmounted, but are not."
			else
				write_log "ERROR: Something went wrong. The complete '${qemu_mnt_dir}' directory, including subdirectories should have been unmounted, but is not."
			fi
		else
			write_log "Virtual image successfully unmounted."
		fi
	else
		write_log "No virtual image seems to be mounted. So, no need to umount.
Exiting function."
	fi
else
	write_log "ERROR: Wrong parameter. Only 'sys' and 'all' allowed when calling 'umount_img'.
Used call parameter was '${1}', however. Exiting now!"
	exit 97
fi
cd ${output_dir}
}


# Description: Helper function to search and replace strings (also works on strings containing special characters!) in files
sed_search_n_replace()
{
if [ ! -z "${1}" ] && [ ! -z "${3}" ] && [ -e "${3}" ]
then
	original=${1}
	replacement=${2}
	file=${3}

	escaped_original=$(printf %s "${original}" | sed -e 's![.\[^$*/]!\\&!g')

	escaped_replacement=$(printf %s "${replacement}" | sed -e 's![\&]!\\&!g')

	sed -i -e "s~${escaped_original}~${escaped_replacement}~g" ${file}
else
	write_log "ERROR: Trying to call the function 'sed_search_n_replace' with (a) wrong/faulty parameter(s). The following was used:
Param1=original='${1}'
Param2=replacement='${2}'
Param3=file='${3}'"
fi
sleep 1
grep -F "${replacement}" "${file}" > /dev/null

if [ "$?" = "0" ]
then
	write_log "String '${original}' was successfully replaced in file '${file}'."
else
	write_log "ERROR: String '${original}' could not be replaced in file '${file}'!"
fi

}


# Description: Helper function to get (download via wget or git, or link locally) and check any file needed for the build process
get_n_check_file()
{
file_path=${1%/*}
file_name=${1##*/}
short_description=${2}
output_path=${3}

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ]
then
	write_log "ERROR: Function get_n_check_file needs 3 parameters.
Parameter 1 is file_path/file_name, parameter 2 is short_description and parameter 3 is output-path.
Faulty parameters passed were:
file_path/file_name='${1}'
short_descripton='${2}'
output_path='${3}'.
One or more of these appear to be empty! Exiting now!" 
	regular_cleanup
	exit 42
fi

if [ "${file_path:0:7}" = "http://" ] || [ "${file_path:0:8}" = "https://" ] || [ "${file_path:0:6}" = "ftp://" ] || [ "${file_path:0:6}" = "git://" ] || [ "${file_path:0:3}" = "-b " ] 
then
	if [ "${use_cache}" = "yes" ]
	then
		if [ ! -f ${output_dir_base}/cache/${file_name} ]
		then
			check_connectivity
		fi
	fi
	if [ -d ${output_path} ]
	then
		cd ${output_path}
		if [ "${1:(-4):4}" = ".git" ]
		then
			write_log "Trying to clone repository ${short_description} from address '${1}', now."
			success=0
			for i in {1..10}
			do
				if [ "$i" = "1" ]
				then
					git clone ${1}
				else
					if [ -d ./${file_name%.git} ]
					then
						rm -rf ./${file_name%.git}
					fi
					git clone ${1}
				fi
				if [ "$?" = "0" ]
				then
					success=1
					break
				fi
			done
			if [ "$success" = "1" ]
			then
				write_log "'${short_description}' repository successfully cloned from address '${1}'."
			else
				write_log "ERROR: Repository '${1}' could not be cloned.
Exiting now!"
				regular_cleanup
				exit 42
			fi
		else
			write_log "Trying to download ${short_description} from address '${file_path}/${file_name}', now."
			wget -q --spider ${file_path}/${file_name}
			if [ "$?" = "0" ]
			then
				wget -t 3 ${file_path}/${file_name}
				if [ "$?" = "0" ]
				then
					write_log "'${short_description}' successfully downloaded from address '${file_path}/${file_name}'."
				else
					write_log "ERROR: File '${file_path}/${file_name}' could not be downloaded.
'wget' returned error code '$?'. Exiting now!"
					regular_cleanup
					exit 43
				fi
			else
				write_log "ERROR: '${file_path}/${file_name}' does not seem to be a valid internet address. Please check!
'wget' returned error code '$?'. Exiting now!"
				regular_cleanup
				exit 44
			fi
		fi
	else
		write_log "ERROR: Output directory '${output_path}' does not seem to exist. Please check!
Exiting now!"
			regular_cleanup
			exit 45
	fi
else
	write_log "Looking for the ${short_description} locally (offline)."	
	if [ -d ${file_path} ]
	then
		if [ -e ${file_path}/${file_name} ]
		then
			write_log "File is a local file '${file_path}/${file_name}', so it stays where it is."
			ln -s ${file_path}/${file_name} ${output_path}/${file_name}
		else
			write_log "ERROR: File '${file_name}' does not seem to be a valid file in existing directory '${file_path}'.Exiting now!"
			regular_cleanup
			exit 47
		fi
	else
		write_log "ERROR: Folder '${file_path}' does not seem to exist as a local directory. Exiting now!"
		regular_cleanup
		exit 48
	fi
fi
cd ${output_dir}
}


# Description: Helper function to clean up in case of an interrupt
int_cleanup() # special treatment for script abort through interrupt ('ctrl-c'  keypress, etc.)
{
	write_log "Build process interrupted. Now trying to clean up!"
	umount_img all 2>/dev/null
	rm -r ${qemu_mnt_dir} 2>/dev/null
	if [ "${clean_tmp_files}" = "yes" ]
	then
		rm -r ${output_dir}/tmp 2>/dev/null
	fi
	rm -r ${output_dir}/drive 2>/dev/null
	rm -r ${output_dir}/qemu-kernel 2>/dev/null
	write_log "Exiting script now!"
	exit 99
}

# Description: Helper function to clean up in case of an error
regular_cleanup() # cleanup for all other error situations
{
	umount_img all 2>/dev/null
	rm -r ${qemu_mnt_dir} 2>/dev/null
	if [ "${clean_tmp_files}" = "yes" ]
	then
		rm -r ${output_dir}/tmp 2>/dev/null
	fi
	rm -r ${output_dir}/drive 2>/dev/null
	rm -r ${output_dir}/qemu-kernel 2>/dev/null
}
