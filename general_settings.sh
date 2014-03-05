#!/bin/bash
# Bash script that creates a Debian or Emdebian rootfs or even a complete SATA/USB/SD drive/card for a embedded device
# Should run on current Debian or Ubuntu versions
# Author: Ingmar Klein (ingmar.klein@hs-augsburg.de)
# Additional part of the main script 'build_emdebian_debian_system.sh', that contains all the general settings

# This program (including documentation) is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License version 3 (GPLv3; http://www.gnu.org/licenses/gpl-3.0.html )
# for more details.

##################
### IMPORTANT: ###
##################

# The settings that you put into this file will exactly define the output of the scripts.
# So, please take your time and look through all the settings thoroughly, before running the scripts.
# Reading the file 'README.md' is also highly recommended!


#########################
##### MACHINE NAME: #####
#########################

machine_id="pogoplug_v3"

#########################
#########################


###################################
##### GENERAL BUILD SETTINGS: #####
###################################

build_target="emdebian" # possible settings are either 'debian' or 'emdebian'
build_target_version="wheezy" # The version of debian/emdebian that you want to build (ATM wheezy is the stable version)
target_mirror_url="http://ftp.uk.debian.org/emdebian/grip" # mirror address for debian or emdebian
target_repositories="main" # what repos to use in the sources.list (for example 'main contrib non-free' for Debian)

host_os="Debian" # Debian or Ubuntu (YOU NEED TO EDIT THIS!)

output_dir_base="/home/${LOG_NAME}/${machine_id}_${build_target}_build" # where the script is going to put its output files (YOU NEED TO CHECK THIS!; default is the home-directory of the currently logged in user) 
current_date=`date +%s` # current date for use on all files that should get a consistent timestamp
########## A necessary check for output_dir #############
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
##########################################################

root_password="root" # password for the Debian or Emdebian root user
username="tester"  # Name of the normal user for the target system
user_password="tester" # password for the user of the target system

# ATTENTION: Your kernel has to support the filesystem-type that you specify here. Otherwise the Pogoplug won't boot.
# ALSO, please check the Uboot Environment Variable 'bootargs' !!!
# The part 'rootfstype=' has to reflect the filesystem that your created USB drive uses!
# AND your specified (and flashed!) kernel has to have support for that file system (compiled in, NOT as module!!!)


### These settings are for experienced users ###

std_locale="en_US.UTF-8" # initial language setting for console (alternatively for example 'en_US.UTF-8')'

locale_list="en_US.UTF-8 de_DE.UTF-8" # list of locales to enable during configuration

tar_format="bz2" # bz2(=bzip2) or gz(=gzip)

qemu_mnt_dir="${output_dir}/mnt_debootstrap" # directory where the qemu filesystem will be mounted

base_sys_cache_tarball="${build_target}_${build_target_version}_minbase.tgz" # cache file created by debootstrap, if caching is enabled

### Check these very carefully, if you experience errors while running 'check_n_install_prerequisites'
apt_prerequisites_debian="emdebian-archive-keyring debootstrap binfmt-support qemu-user-static qemu-kvm qemu-system-arm parted e2fsprogs" # packages needed for the build process on debian
apt_prerequisites_ubuntu="debian-archive-keyring emdebian-archive-keyring debootstrap binfmt-support qemu-user-static qemu-system-arm qemu-kvm parted e2fsprogs" # packages needed for the build process on ubuntu


####################################
##### SPECIFIC BUILD SETTINGS: #####
####################################

clean_tmp_files="no" # delete the temporary files, when the build process is done?

create_disk="no" # create a bootable USB thumb drive after building the rootfs?

use_cache="yes" # use or don't use caching for the apt and debootstrap processes (caching can speed things up, but it can also lead to problems)


####################################
##### "INSTALL ONLY" SETTINGS: #####
####################################

default_rootfs_package="" # filename of the default rootfs-archive for the '--install' call parameter

###########################################################
###########################################################
if [ ! -z "${machine_id}" -a -d ./machines/${machine_id} -a -f ./machines/${machine_id}/machine_settings.sh -a -f ./machines/${machine_id}/machine_functions.sh ]
then
	source ./machines/${machine_id}/machine_settings.sh # Including settings through the additional machine specific settings file
	source ./machines/${machine_id}/machine_functions.sh # Including functions through the additional machine specific functions file
else
	echo "ERROR! Some or all machine files NOT found!
Please check the 'machine_id' variable! Available machines are 
'`eval ls \`pwd\`/machines/`'
Exiting now!"
	regular_cleanup
	exit 1
fi
###########################################################
###########################################################
