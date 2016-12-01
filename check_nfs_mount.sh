#!/bin/bash

#
# Copyright 2016 Thibaut MADELAINE and contributors. All rights
# reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 
#  1. Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHORS ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

usage() {
    echo "usage: $1"
    echo "Check if the NFS shared folders are mounted."
		echo ""
    echo "parameters:"
    echo "  -h     Print this help"
    echo ""
} 

main() {
    while getopts "h" opt; do
        case $opt in
            h  ) usage `basename $0`; exit 0;;
            \? ) echo "Unknown option: -$OPTARG" >&2; usage `basename $0`; exit 1;;
        esac
    done

		# get the NFS server IP address and server forlder path from fstab
		if [ ! -f /etc/fstab ] ; then
				echo "Impossible to read /etc/fstab"
				exit 1;
		fi
		MOUNT_POINTS=$(grep -v  '^#' /etc/fstab | awk '{if ($3=="nfs"){print $1" "$2}}' | awk -F':' '{print $1" "$2}' )
		# echo $MOUNT_POINTS

		if [ -z "${MOUNT_POINTS}" ] ; then
				# no nfs mount points
				echo "no nfs mount points to check"
				exit 0
		fi
		
		while read -r line; do
			IFS=' ' read nfs_server distant_nfs local_nfs <<< "$line"
			# echo "$nfs_server : $distant_nfs -> $local_nfs"

			# check that the local directory exists
			if [ ! -d $local_nfs ]; then
				echo "`date`: $local_nfs directory does not exists for mountpoint $nfs_server:$distant_nfs!"
				continue
			fi

			# check network connection
			ping -c 1 $nfs_server &> /dev/null
			if [ $? -ne 0 ]; then
				echo "`date`: ping failed, $nfs_server host is not reachable!"
				continue
			fi

			# check server NFS service
			rpcinfo -u $nfs_server nfs 3  &> /dev/null
			if [ $? -ne 0 ]; then
				echo "`date`: NFS service on $nfs_server is down!"
				continue
			fi
			
			# check if the directory is exported
			SHARED_FOLDERS=$(showmount -e $nfs_server | tail -n+2 | awk '{print $1}')
			# echo $SHARED_FOLDERS
			folder_found=0
			for shared_folder in $SHARED_FOLDERS ; do
				if [ ${shared_folder%/} = ${distant_nfs%/} ] ; then
					folder_found=1
				fi
			done
			if [ $folder_found -eq 0 ] ; then
				echo "`date`: folder $local_nfs is not shared by $nfs_server!"
				continue
			fi

			# check if the local folder is mounted
			MOUNT_TYPE=$(df -P -T $local_nfs | tail -n +2 | awk '{print $2}')
			# echo "$local_nfs => $MOUNT_TYPE"
			if [ "$MOUNT_TYPE" != "nfs" -a "$MOUNT_TYPE" != "nfs4" ] ; then
				echo "remount nfs share: $local_nfs"
				mount $local_nfs
			else
				echo "$local_nfs is mounted"
			fi
				
		done <<< "$MOUNT_POINTS"
		
		exit 0
}

main $*
