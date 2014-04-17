#!/bin/bash
# Bash script that creates a Debian or Emdebian rootfs or even a complete SATA/USB/SD drive/card for a embedded device
# Should run on current Debian or Ubuntu versions
# Author: Ingmar Klein (ingmar.klein@hs-augsburg.de)
# Additional part of the main script 'build_emdebian_debian_system.sh', that contains all the general settings

# This program (including documentation) is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License version 3 (GPLv3; http://www.gnu.org/licenses/gpl-3.0.html )
# for more details.

############################################################################
############################################################################
############################################################################
###       _    _ _          _                            _    _  ___     ### 
###      / \  | | |_      _(_)_ __  _ __   ___ _ __     / \  / |/ _ \    ### 
###     / _ \ | | \ \ /\ / / | '_ \| '_ \ / _ \ '__|   / _ \ | | | | |   ###
###    / ___ \| | |\ V  V /| | | | | | | |  __/ |     / ___ \| | |_| |   ###
###   /_/   \_\_|_| \_/\_/ |_|_| |_|_| |_|\___|_|    /_/   \_\_|\___/    ###
###                                                                      ###
############################################################################
############################################################################
############################################################################



##################
### IMPORTANT: ###
##################

# The settings that you put into this file will exactly define the output of the scripts.
# So, please take your time and look through all the settings thoroughly, before running the scripts.
# Reading the file 'README.md' is also highly recommended!


#########################################
##### Allwinner A10 BUILD SETTINGS: #####
#########################################

### These settings MUST be checked/edited ###

console_device="ttyS0" # Device used for the serial console (usually 'ttyS0')
console_baudrate="115200" # Baudrate to use for the serial console (often '115200')

machine_debian_prereq="" # Here you can specify any machine specific prerequisites for a Debian host system. Can be left empty.
machine_ubuntu_prereq="" # Here you can specify any machine specific prerequisites for a Ubuntu host system. Can be left empty.

machine_debootstrap_arch="armhf" # Architecture setting for debootstrap. For example 'armel' for ARMv5 and 'armhf' for ARMv7.
deb_add_packages="apt-utils,dialog,locales,udev,dictionaries-common,aspell" # packages to directly include in the first debootstrap stage
additional_packages="rsyslog u-boot-tools file manpages man-db module-init-tools isc-dhcp-client netbase ifupdown iproute iputils-ping net-tools wget vim nano hdparm rsync bzip2 p7zip unrar unzip zip p7zip-full screen less usbutils psmisc strace info ethtool python whois time ruby procps perl parted ftp gettext firmware-linux-free firmware-linux-nonfree rcconf lrzsz libpam-modules util-linux mtd-utils mesa-utils libopenvg1-mesa libegl1-mesa-drivers libegl1-mesa libgles2-mesa ntp ntpdate iotop powertop task-lxde-desktop pcmanfm icedove filezilla atool xarchiver git subversion build-essential autoconf automake make libtool xorg-dev xutils-dev libdrm-dev libxcb-dri2-0-dev libglew-dev" # List of packages (each seperated by a single space) that get added to the rootfs
additional_wireless_packages="firmware-realtek wireless-tools iw wpasupplicant" # packages for wireless lan; mostly for the Pogoplug V3 Pro

module_load_list="ump mali drm mali_drm" # names of modules (for example wireless, leds ...) that should be automatically loaded through /etc/modules (list them, seperated by a single blank space)

ethernet_interface="eth0" # (IMPORTANT!!!) What ethernet interface exists on your device? (for example 'eth0' for standard ethernet)
interfaces_auto="eth0" # (IMPORTANT!!!) what network interfaces to bring up automatically on each boot (except for lo, which will be included automatically); if you don't list the needed interfaces here, you will have to enable them manually, after booting
wireless_interface="wlan0" # (IMPORTANT!!!) What wireless interface exists on your device? (for example 'wlan0' for standard wireless)

rootfs_filesystem_type="ext4" # what filesystem type should the created rootfs be?
# ATTENTION: Your kernel has to support the filesystem-type that you specify here. Otherwise the Pogoplug won't boot.
# ALSO, please check the Uboot Environment Variable 'bootargs' !!!
# The part 'rootfstype=' has to reflect the filesystem that your created USB drive uses!
# AND your specified (and flashed!) kernel has to have support for that file system (compiled in, NOT as module!!!)
#swap_partition="/dev/mmcblk0p3" # Specify the name of the swap device (for example '/dev/sda2', is the second partition of a USB device is used as swap. CAN BE LEFT EMPTY, although this is not recommended!
swap_partition="LABEL=mmc_swap"

### These settings are for experienced users ###

extra_files="" # some extra archives (list seperated by a single blank space!) that get extracted into the rootfs, when done (for example original led control program and original arch linux kernel modules)

qemu_kernel_pkg="/home/celemine1gig/Allwinner/A10/QEMU/kernels/linux-3.4.87-qemu-cortex-a8-1.1.tar.xz" # qemu kernel file name

std_kernel_pkg="/home/celemine1gig/Allwinner/A10/BA_10_TV_BOX/kernels/stage-3.4-sunxi/3.4.86-a10-tvbox-mali-r3p2-01rel2-1.0-dirty.tar.xz" # std kernel file name

work_image_size_MB="6144" # size of the temporary image file, in which the installation process is carried out


##########################
##### QEMU SETTINGS: #####
##########################

qemu_console_device="ttyAMA0"

qemu_arch="arm" # What base architecture do you need qemu to emulate? For example 'arm'.

qemu_machine_type="realview-pb-a8" # What specific, supported machine should qemu emulate?

qemu_cpu_type="cortex-a8" # What specific cpu-type should be emulated?

qemu_mem_size="512" # How much RAM to hand to the qemu cirtual system?

qemu_extra_options="-rtc base=localtime,clock=host -serial stdio -curses" # Here you can specify extra machine specific options for qemu. You can also leave it empty.

qemu_hdd_mount="-drive file=${output_dir}/${output_filename}.img,if=sd,cache=unsafe,aio=native,discard=ignore" # How to use the rootfs image in qemu? For example as IDE disk '-hda xxx.img'.

qemu_kernel_cmdline="console=${qemu_console_device} root=/dev/mmcblk0 rw rootfstype=${rootfs_filesystem_type} rootwait mem=512M" # What commandline to pass to the qemu-kernel, when running the virtual qemu system?




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



#######################################
#####  ARM MALI GRAPHICS RELATED  #####
#######################################

### ARM Mali400 graphics driver settings ###
mali_module_version="r3p2" # Version of the mali module, included in the used kernel (could be r3p0, r3p2 ...)

# Git repositories needed for full functionality
libdri2_git="git://github.com/robclark/libdri2.git"
sunxi_mali_git="git://github.com/linux-sunxi/sunxi-mali.git"
sunxi_mali_proprietary_git="git://github.com/linux-sunxi/sunxi-mali-proprietary.git"
libump_git="https://github.com/linux-sunxi/libump.git"
xf86_video_fbturbo_git="https://github.com/ssvb/xf86-video-fbturbo.git"
libcedarx_git="git://github.com/willswang/libcedarx.git"
libvdpau_sunxi_git="https://github.com/linux-sunxi/libvdpau-sunxi.git"


# Names of the corresponding cache tarballs
libdri2_git_tarball="libdri2.tar.xz"
sunxi_mali_git_tarball="sunxi-mali.tar.xz" # tarball name for sunxi_mali cache
sunxi_mali_proprietary_git_tarball="sunxi-mali-proprietary.tar.xz" # tarball name for mali-proprietary cache
xf86_video_fbturbo_git_tarball="xf86-video-fbturbo.tar.xz"
libump_git_tarball="libump.tar.xz"
libcedarx_git_tarball="libcedarx.tar.xz" # tarball name for libcedarx cache
libvdpau_sunxi_git_tarball="libvdpau-sunxi.tar.xz"




####################################
##### SPECIFIC BUILD SETTINGS: #####
####################################

### Partition setting ###
# Comment: size of the rooot partition doesn't get set directly, but is computed through the following formula:
# root partition = size_of_usb_drive - (size_boot_partition + size_swap_partition + size_wear_leveling_spare)
size_swap_partition="512"   # size of the swap partition, in MB (MegaByte)
size_wear_leveling_spare="512" ## size of spare space to leave for advanced usb thumb drive flash wear leveling, in MB (MegaByte); leave empty for normal hdds
size_alignment="1" ## size of spare space before the root partitionto starts (in MegaByte); also leave empty for normal hdds



##########################
##### BOOT SETTINGS: #####
##########################

# set the following option to 'yes', if you want to create a rootfs on a SATA drive, sd card or anything similar, that needs an external bootloader, in order to boot from it.
external_bootloader="yes" 
# However, if you want to boot from a memory device that the internal bootloader already supports, then be sure to set the option ABOVE to 'no' !!!
bootloader_package="/home/celemine1gig/Allwinner/A10/BA_10_TV_BOX/u-boot/u-boot-ba_10_tv_box.tar.xz" # Archive that contains all necessary bootlaoder files
bootloader_script_bin="/home/celemine1gig/Allwinner/A10/BA_10_TV_BOX/script_bin/script.bin" # File 'script.bin', which contains the low level configuration of the specfic A10 machine (generated through the '.fex'-file)


####################################
##### "INSTALL ONLY" SETTINGS: #####
####################################

default_rootfs_package="" # filename of the default rootfs-archive for the '--install' call parameter


