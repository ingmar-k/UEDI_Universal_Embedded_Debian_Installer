#!/bin/bash
# Bash script that creates a Debian or Emdebian rootfs or even a complete SATA/USB/SD drive/card for a embedded device
# Should run on current Debian or Ubuntu versions
# Author: Ingmar Klein (ingmar.klein@hs-augsburg.de)
# Additional part of the main script 'build_emdebian_debian_system.sh', that contains all the general settings

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


##################
### IMPORTANT: ###
##################

# The settings that you put into this file will exactly define the output of the scripts.
# So, please take your time and look through all the settings thoroughly, before running the scripts.
# Reading the file 'README.md' is also highly recommended!


#######################################
##### NXP LPC313x BUILD SETTINGS: #####
#######################################

build_target="debian" # possible settings are either 'debian' or 'emdebian'. The system you want to BUILD as output of this script.
build_target_version="testing" # The version of debian/emdebian that you want to build (ATM wheezy is the stable version)
target_mirror_url="http://ftp.de.debian.org/debian/" # mirror address for debian or emdebian
target_repositories="main contrib non-free" # what repos to use in the sources.list (for example 'main contrib non-free' for Debian)

current_date=`date +%s` # current date for use on all files that should get a consistent timestamp
output_filename="${build_target}_rootfs_${machine_id}_${current_date}" # base name of the output file (compressed rootfs)
output_dir_base="/home/${LOG_NAME}/${machine_id}_${build_target}_build" # where the script is going to put its output files (YOU NEED TO CHECK THIS!; default is the home-directory of the currently logged in user) 
########## Necessary check and setting output_dir #############
echo ${output_dir_base} |grep '//' >/dev/null
if [ "$?" = "0" ]
then
	echo "ERROR! Please check the script variable 'output_dir_base' in the 'general_settings.sh' file.
It seems like there was a empty variable (LOG_NAME???), which led to a wrong path description. Exiting now."
	exit 95
fi
if [ "${output_dir_base:(-1):1}" = "/" ]
then
	output_dir="${output_dir_base}build_${current_date}" # Subdirectory for each build-run, ending with the unified Unix-Timestamp (seconds passed since Jan 01 1970)
else
	output_dir="${output_dir_base}/build_${current_date}" # Subdirectory for each build-run, ending with the unified Unix-Timestamp (seconds passed since Jan 01 1970)
fi
##################################################################


### These settings MUST be checked/edited ###
console_device="ttyS0" # Device used for the serial console (usually 'ttyS0')
console_baudrate="115200" # Baudrate to use for the serial console (often '115200')

machine_debian_prereq="" # Here you can specify any machine specific prerequisites for a Debian host system. Can be left empty.
machine_ubuntu_prereq="" # Here you can specify any machine specific prerequisites for a Ubuntu host system. Can be left empty.

machine_debootstrap_arch="armel" # Architecture setting for debootstrap. For example 'armel' for ARMv5 and 'armhf' for ARMv7.
deb_add_packages="apt-utils,dialog,locales,emdebian-archive-keyring,debian-archive-keyring" # packages to directly include in the first debootstrap stage
additional_packages="mtd-utils udev ntp netbase module-init-tools isc-dhcp-client nano bzip2 unzip zip screen less usbutils psmisc procps ifupdown iputils-ping wget net-tools ssh hdparm" # List of packages (each seperated by a single space) that get added to the rootfs
additional_wireless_packages="wireless-tools wpasupplicant" # packages for wireless lan; mostly for the Pogoplug V3 Pro

module_load_list="" # names of modules (for example wireless, leds ...) that should be automatically loaded through /etc/modules (list them, seperated by a single blank space)

ethernet_interface="eth0" # (IMPORTANT!!!) What ethernet interface exists on your device? (for example 'eth0' for standard ethernet)
interfaces_auto="eth0" # (IMPORTANT!!!) what network interfaces to bring up automatically on each boot (except for lo, which will be included automatically); if you don't list the needed interfaces here, you will have to enable them manually, after booting
wireless_interface="" # (IMPORTANT!!!) What wireless interface exists on your device? (for example 'wlan0' for standard wireless)

rootfs_filesystem_type="ext4" # what filesystem type should the created rootfs be?
# ATTENTION: Your kernel has to support the filesystem-type that you specify here. Otherwise the Pogoplug won't boot.
# ALSO, please check the Uboot Environment Variable 'bootargs' !!!
# The part 'rootfstype=' has to reflect the filesystem that your created USB drive uses!
# AND your specified (and flashed!) kernel has to have support for that file system (compiled in, NOT as module!!!)
swap_partition="/dev/sda2" # Specify the name of the swap device (for example '/dev/sda2', is the second partition of a USB device is used as swap. CAN BE LEFT EMPTY, although this is not recommended!

### These settings are for experienced users ###

extra_files="" # some extra archives (list seperated by a single blank space!) that get extracted into the rootfs, when done (for example original led control program and original arch linux kernel modules)

qemu_kernel_pkg="http://www.hs-augsburg.de/~ingmar_k/Pogoplug_V3/kernels/3.13.4-qemu-ppv3-1.0.tar.bz2" # qemu kernel file name

std_kernel_pkg="/home/celemine1gig/kirkwood/ls-wvl/kernels/3.15.5-1/kirkwood-ls-wvl-1.0-1407263706.tar.xz" # std kernel file name

work_image_size_MB="1024" # size of the temporary image file, in which the installation process is carried out


##########################
##### QEMU SETTINGS: #####
##########################

qemu_arch="arm" # What base architecture do you need qemu to emulate? For example 'arm'.

qemu_machine_type="versatilepb" # What specific, supported machine should qemu emulate?

qemu_cpu_type="arm926" # What specific cpu-type should be emulated?

qemu_mem_size="256" # How much RAM to hand to the qemu cirtual system?

qemu_extra_options="" # Here you can specify extra machine specific options for qemu. You can also leave it empty.

qemu_hdd_mount="-hda ${output_dir}/${output_filename}.img" # How to use the rootfs image in qemu? For example as IDE disk '-hda xxx.img'.

qemu_kernel_cmdline="root=/dev/sda rootfstype=${rootfs_filesystem_type} mem=256M rw" # What commandline to pass to the qemu-kernel, when running the virtual qemu system?




###################################
##### NETWORK BUILD SETTINGS: #####
###################################

### ETHERNET ###

ip_type="dhcp" # set this either to 'dhcp' (default) or to 'static'

static_ip="192.168.2.100" # you only need to set this, if ip-type is NOT set to 'dhcp', but to 'static'

netmask="255.255.255.0" # you only need to set this, if ip-type is NOT set to 'dhcp', but to 'static'

gateway_ip="192.168.2.1" # you only need to set this, if ip-type is NOT set to 'dhcp', but to 'static'


### WIRELESS ###

ip_type_wireless="dhcp" # set this either to 'dhcp' (default) or to 'static'

wireless_ssid="MySSID" # set this to your wireless SSID

wireless_password="Password_Swordfish" # set this to your wireless password

wireless_static_ip="192.168.2.100" # you only need to set this, if ip-type is NOT set to 'dhcp', but to 'static'

wireless_netmask="255.255.255.0" # you only need to set this, if ip-type is NOT set to 'dhcp', but to 'static'

wireless_gateway_ip="192.168.2.1" # you only need to set this, if ip-type is NOT set to 'dhcp', but to 'static'

Country_Region="1" # wireless region setting for rt3090

Country_Region_A_Band="1" # wireless region band setting for rt3090

Country_Code="DE" # wireless country code setting for rt3090

Wireless_Mode="5" # wireless mode setting for rt3090


### Partition setting ###
# Comment: size of the rooot partition doesn't get set directly, but is computed through the following formula:
# root partition = size_of_usb_drive - (size_boot_partition + size_swap_partition + size_wear_leveling_spare)
size_swap_partition="512"   # size of the swap partition, in MB (MegaByte)
size_wear_leveling_spare="256" ## size of spare space to leave for advanced usb thumb drive flash wear leveling, in MB (MegaByte); leave empty for normal hdds
size_alignment="1" ## size of spare space before the root partitionto starts (in MegaByte); also leave empty for normal hdds


### Settings for compressed SWAP space in RAM ### 
use_compressed_swapspace="yes" # Do you want to use a compressed SWAP space in RAM (can potentionally improve performance)?
compressed_swapspace_module_name="zram" # Name of the kernel module for compressed swapspace in RAM (could either be called 'ramzswap' or 'zram', depending on your kernel)
compressed_swapspace_nr_option_name="num_devices" # Depending on kernel version, this option can have slight differences (used to be 'num_devices', then zram_num_devices' and then 'num_devices' again.
compressed_swapspace_blkdev_count="1" # Number of swap devices to create. Should be equal to the number of CPU cores.
compressed_swapspace_priority="32767" # Priority for swap usage. The higher the priority (32767 being the biggest possible number), the more likely the swap gets used first.
compressed_swapspace_size_MB="256" # size of the ramzswap/zram device in MegaByte (MB !!!), per CPU-core (so per default 2 swap devices will be created)
vm_swappiness="" # (empty string makes the script ignore this setting and uses the debian default). Setting for general kernel RAM swappiness: Default in Linux mostly is 60. Higher number makes the kernel swap faster.


####################################
##### SPECIFIC BUILD SETTINGS: #####
####################################


####################################
##### "INSTALL ONLY" SETTINGS: #####
####################################

default_rootfs_package="" # filename of the default rootfs-archive for the '--install' call parameter
