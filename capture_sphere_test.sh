#!/bin/bash

# Snaps THETA Z1 pictures
# uploads them and deletes the
# images on the camera to free up memory
# needs to be called using crontab for a time lapse
# implementation

# if not arguments
#if [ "$*" == "" ]; then
#    echo "No arguments provided"
#    echo "use: -u true / false (upload)"
#    echo "use: -n true / false (night mode)"
#   	echo "use: -s xxx.xxx.xxx.xxx (ip address / domain name)"
#    exit 1
#fi

 #query arguments
#while getopts ":h?u:n:s:" opt; do
#    case "$opt" in
#    h|\?)
#   		echo "No arguments provided"
#    	echo "use: -u true / false (upload)"
#    	echo "use: -s XXX.XXX.XXX.XXX (ip address / domain name)"
#    	exit 0
#        ;;
#    u)  
#    	upload=$OPTARG
#    	;;
#    s)  
#    	server=$OPTARG
#    	;;
#    :)
#    	echo "Option -$OPTARG requires an argument." >&2
#    	exit 1
#    	;;
#    esac
#done

# set paths explicitly
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"

# set working directory
# in which to save the data
cd /var/tmp/

# make sure to unmount the camera
# basically in text mode it should not
# auto mount (as far as I know)

# cameraname
camera="virtualforest"
datetime=` date +%Y_%m_%d_%H%M%S`

# check if the camera is connected
# if not exit cleanly
status=`ptpcam --show-property=0x5001 | grep "ERROR" | wc -l`

if [ "$status" = "1" ];
then
	echo ""
	echo "Your camera is not active"
	echo "-----------------------------------------------------------"
	echo "activating your camera"
	echo ""
	echo ""
	
	# activate the camera
	boot=`ptpcam --set-property=0xD80E --val=0x00 | grep "succeeded" | wc -l`
	
	if [ "$boot" == 1 ];
	then
         echo "booting the device... (waiting 10s)"
	 sleep 10
	else
         exit 0
	fi
fi

# check the battery status
battery=`ptpcam --show-property=0x5001 | grep "to:" | awk '{print $6}'`

# output battery status to file
echo $battery >> battery_status.txt

if [ "$battery" -lt 20 ];
then
	echo "low battery"
	exit 0
fi

# set the timeout to indefinite
# as well as the sleep delay
# this prevents timed shutdowns
ptpcam --set-property=0xd803 --val=0 # sleep delay
ptpcam --set-property=0xd802 --val=0 # set auto power off
ptpcam --set-property=0x502c --val=0 # set shutter sound to min 0 or max 100

# list all files on the device
handle=`ptpcam -L | grep 0x | awk '{print $1}' | sed 's/://g'`

# clear all files on the device before capturing
# any new data
for i in $handle;do
	ptpcam --delete-object=$i
done


# loop over 2 exposure settings
exposures="0 -2000"
	
ptpcam --set-property=0x500E --val=0x8003 # ISO priority
ptpcam --set-property=0x5005 --val=0x8002 # set WB to cloudy
ptpcam --set-property=0x500F --val=100 # set ISO
	
for exp in $exposures;do
	# Change settings of exposure compensation
	ptpcam --set-property=0x5010 --val=$exp # set compensation
		
	# snap picture
	# and wait for it to complete (max 60s)
	ptpcam -c
	sleep 60
	
	# list last file
	handle=`ptpcam -L | grep 0x | awk '{print $1}' | sed 's/://g'`
	
	# grab the last file
	# wait a bit otherwise the next
	# commands are too fast
	ptpcam --get-file=$handle
	sleep 10

	# grab filename of the last downloaded file
	filename=`ls -t *.JPG | head -1`

	# create filename based upon time / date
	newfilename=`echo $camera\-exp$exp\_$datetime.jpg`

	# rename the last file created
	mv $filename $newfilename

	# remove file
	ptpcam --delete-object=$handle
done

rsync --remove-source-files -avzh /var/tmp/virtualforest-exp* ndevert@147.100.179.81:/home/ndevert/ricoh_test/virtualforest/



# upload new data to an image server
#if [[ "$upload" == "TRUE" || "$upload" == "T" ]] \
#|| [[ "$upload" == "t" || "$upload" == true ]]
#then
	# puts images in the 'data' folder of an anonymous FTP server
	#lftp ftp://anonymous:anonymous@${server} -e "mirror --verbose --reverse --Remove-source-files ./ ./files/ ;quit"
#fi

