#!/bin/bash
#
# rename-photos.sh
#
# PhotosPath="/media/4GBSD/DCIM/101CANON"
# SortPath="/home/angus/.imagesort"
# LibraryPath="/home/angus/Photos"
# CameraPath="/media/4GBSD"

function usage {
	echo
	echo "Recursively rename .jpg files from one tree and into another."
	echo ""
	echo "Usage: rename-photos source-dir dest-dir <prefix> <suffix>"
	echo "       prefix and suffix are filenaming options."
	echo
}

function min_parms {
	echo "**************************************************************"
	echo "You did not enter both the source and destination directories,"
	echo "Try again."
	echo "**************************************************************"
	echo
	exit $FAILURE
}

usage

[ $# -ge 2 ] || min_parms

PhotosPath="$1"				# Source path of new photos
SortPath="~/.imagesort"			# Default sort path
LibraryPath="$2"			# Destination path of renamed photos
CharFromName=4

if [ $# -ge 3 ]; then
	prefix="$3"
	echo "Your Prefix is: " $prefix
else
	prefix=""
	echo "There is no prefix."
fi

if [ $# -ge 4 ]; then
	suffix="$4"
	echo "Your suffix is: " $suffix
else
	suffix=""
	echo "There is no suffix."
fi

############
# Test to see if $PhotosPath exists, if not prompt for new path / exit.
test -d $PhotosPath || read -p "$PhotosPath does not exist, close to exit or type new path:" PhotosPath
test -d $PhotosPath || "read -p '$PhotosPath is invalid. Press enter to close' && exit"

test -d $SortPath || mkdir $SortPath

echo "Your source directory is:       $PhotosPath"
echo "Your destination directory is:  $LibraryPath"
read -p "Press any key to continue or Ctl-c to exit."

############
# Copy files from $PhotosPath to $SortPath
rsync -va $PhotosPath/* $SortPath/

############
# rename all image files in $SortPath
# FolderDateDD-HHMMSS.ext
# jhead  -autorot -ft -nf%y%m%d-%H%M%S $SortPath/*
cd $SortPath
ls
find $SortPath -type f -iname '*.jpg' \
 -exec jhead -ft -nf$LibraryPath/%Y/%m/%d/$prefix%Y-%m-%d-%H:%M:%S$suffix '{}' \;


###########
# Sort files into folders using $CharFromName letters of the file name
#
#ls $SortPath | while read file; do
 # extract first $CharFromName characters from filename
# FolderDate=${file:0:$CharFromName}
 # create directory if it does not exist
# test -d $LibraryPath/$FolderDate || mkdir $LibraryPath/$FolderDate
 # move the current file to the destination dir
# mv -v $SortPath/$file $LibraryPath/$FolderDate/$file
#done

##########
# move sorted files into photo library
# mv -v $SortPath/* $LibraryPath/

##########
# Umount the card
# umount $CameraPath

##########
# End notification
echo
echo "Photos  from: $PhotosPath"
echo "End location: $LibraryPath"
echo
