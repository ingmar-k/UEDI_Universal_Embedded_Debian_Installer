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


##########################################
######### SETTING FOR DEBUG MODE #########
##########################################
#
DEBUG="0" # Set to '1' to see all commands, while the script is running. Set to '0' to disable that output.1
#
##########################################

############################################################
################# Check for debugging mode #################
######### And activate it, if set in settings file #########
############################################################
if [ "${DEBUG}" = "1" ]
then
	set -xv # set verbose mode and show executed commands 
fi
############################################################


##################################
######### MACHINE NAME: ##########
## SET YOUR TARGET MACHINE HERE ##
##################################
###
machine_id="plx-ox820"
###
##################################
##################################

###########################################################
####### NOW INCLUDING ALL NECESSARY MACHINE FILES #########
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


###################################
##### GENERAL BUILD SETTINGS: #####
###################################

host_os="Debian" # Debian or Ubuntu (YOU NEED TO EDIT THIS!) The system you are running THIS script on!

root_password="root" # password for the Debian or Emdebian root user
username="tester"  # Name of the normal user for the target system
user_password="tester" # password for the user of the target system


### These settings are for experienced users ###

time_zone="Europe/Berlin" # timezone setting for package tzdata
std_locale="en_US.UTF-8" # initial language setting for console (alternatively for example 'en_US.UTF-8')'

locale_list="en_US.UTF-8 de_DE.UTF-8" # list of locales to enable during configuration

tar_format="bz2" # bz2(=bzip2), gz(=gzip) or xz(=xz)

qemu_mnt_dir="${output_dir}/mnt_debootstrap" # directory where the qemu filesystem will be mounted

base_sys_cache_tarball="${machine_id}_${build_target}_${build_target_version}_minbase.tgz" # cache file created by debootstrap, if caching is enabled
add_pack_tarball_basename="additional_packages_${machine_id}_${build_target}_${build_target_version}" # basename for the creation of additional packages cache tarballs

### Check these very carefully, if you experience errors while running 'check_n_install_prerequisites'
apt_prerequisites_debian="libncurses5-dev emdebian-archive-keyring debootstrap binfmt-support qemu-user-static qemu-system parted" # packages needed for the build process on debian
apt_prerequisites_ubuntu="libncurses5-dev debian-archive-keyring emdebian-archive-keyring debootstrap binfmt-support qemu-user-static qemu-system parted" # packages needed for the build process on ubuntu


### GENERAL NETWORK SETTINGS ###
hostname="${machine_id}-${build_target}" # Name that the Emdebian system uses to identify itself on the network
nameserver_addr="192.168.2.1" # "141.82.48.1" (YOU NEED TO CHECK THIS!!!)


####################################
##### SPECIFIC BUILD SETTINGS: #####
####################################

clean_tmp_files="yes" # delete the temporary files, when the build process is done?

create_disk="yes" # create a bootable USB thumb drive after building the rootfs?

use_cache="yes" # use or don't use caching for the apt and debootstrap processes (caching can speed things up, but it can also lead to problems)
