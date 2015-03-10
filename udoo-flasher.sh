#!/bin/bash

#  This file is part of project udoo-flasher
#
#  Copyright (C) 2014 Ettore Chimenti <ek5.chimenti@gmail.com>
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Library General Public
#  License as published by the Free Software Foundation; either
#  version 2 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Library General Public License for more details.
#
#  You should have received a copy of the GNU Library General Public License
#  along with this library; see the file COPYING.LIB.  If not, write to
#  the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#  Boston, MA 02110-1301, USA.
#

error() {
  #error($E_TEXT,$E_CODE)

  local E_TEXT=$1
  local E_CODE=$2
  
  [[ -z $E_CODE ]] && E_CODE=1
  [[ -z $E_TEXT ]] || echo $E_TEXT

  exit $E_CODE
}

ok() {
  #ok($OK_TEXT)
  local OK_TEXT=$1
  [[ -z $OK_TEXT ]] && OK_TEXT="Success!!"
  [[ -z $OK_TEXT ]] || echo $OK_TEXT 
  exit 0
}

usage() {
  echo "UDOO Image Flasher"
	echo "Usage: $0 [DISK] [IMAGE|IMAGEDIR] "
	exit 1
}

# if [[ 0 -lt $#  ]]
# then
#   COMMAND=$1
#   shift
#   
#   $COMMAND $@
#   
#   E_CODE=$?
#   case $E_CODE in
#   127) usage ;; 
#     *);;
#   esac
#   
#   exit $E_CODE
# else
#   exec $DIR/udoo-flasher-zenity.sh
#   exit $?
# fi



IMG_PATH="img"

if [ -n "$DISPLAY" ]
then

  ###### GRAPHICAL STYLE

  D=zenity
  
  error(){
    TEXT=$1
    [[ -z $TEXT ]] && TEXT="A fatal error has occoured!"
    $D --title="$TITLE" --error --text="$TEXT"
    exit 1
  }

  alert(){
    TEXT=$1
    [[ -z $TEXT ]] && TEXT="An error has occoured! Warning!"
    $D --title="$TITLE" --warning --text="$TEXT"
    return 0
  }

  question(){
    TEXT=$1
    [[ -z $TEXT ]] && TEXT="An error has occoured!"
    $D --title="$TITLE" --question --text="$TEXT"
    return $?
  }

  ok(){
    TEXT=$1
    [[ -z $TEXT ]] && 	TEXT="Success!"
    (( $QUIET )) || 	$D --title="$TITLE" --info --text="$TEXT"
    return 0
  }

  choosedisk(){
  while [ 1 ] 
  do
    DISK=`for f in $(lsblk -dn -o NAME)  ; do \
      i=/dev/$f
      echo 0 ; \
      echo "$i"; \:
      echo $(lsblk "$i" -nid -o NAME ); \
      echo \"$( lsblk "$i" -nid -o SIZE )\" ; \
      echo \"$( lsblk "$i" -nid -o MODEL )\" ; \
    done | xargs $D \
		    --title="$TITLE" \
		    --width=500 \
		    --height=300 \
		    --list \
		    --radiolist \
        --hide-column=2 \
		    --print-column=2 \
		    --column="        " \
		    --column="DISK" \
        --column="Name" \
        --column="Size" \
        --column="Description" \
		    --text="Choose a disk to flash" \
		    `
		
    (( $? )) && exit 1
    
    [[ $DISK == "" ]] && continue
    
    DISKSIZE=`lsblk "$DISK" -nid -o SIZE`

    question "You picked $DISK ($DISKSIZE), is it correct?"

    (( $? )) && continue
  
    DISK_CHOOSED="$DISK"
    break 
  done
  }
  
  chooseimg(){
    while [ 1 ] 
    do
     #FILENAME=`for i in $IMG_PATH/* ; do echo 0 "$i" ; done | xargs $D \
		 #    --title="$TITLE" \
   
    #better use zenity
    FILENAME=`$D --file-selection \
		      --width=400 \
		      --height=300 \
		    `
		
    (( $? )) && exit 1
    
    [[ $FILENAME == "" ]] && continue
    
    IMGSIZE=$(du -h "$FILENAME" | cut -f 1)

    question "You picked:
$FILENAME ($IMGSIZE)

Do you really want to flash it to $DISK_CHOOSED?"

    (( $? )) && continue
  
    IMG_CHOOSED="$FILENAME"
    break 
  done

  }
  

  flash() {
    #using (pv | dd) | zenity --progress for monitoring

    ( pv -n "$IMG_CHOOSED" | 
        dd of="$DISK_CHOOSED" oflag=sync bs=1M status=none && 
        echo "# Finished" ) 2>&1 | 
      zenity --progress \
    --title="Flasher" \
    --text="Flashing $DISK_CHOOSED..." \
    --percentage=0 \
    --auto-kill
  }

else
  ##### TERMINAL STYLE

  choosedisk(){
    echo "Choose a disk to flash"
    
    unset DISKS
    declare -a DISKS
    i=0  
    lsblk -dn -o NAME,MODEL | while read file  
    do 
      let i++
      DISKS[$i]="$file"
    done
  
    select DISKNAME in $DISKS
    do
      DISK="/dev/$(echo $DISKNAME | awk '{ print $1; }' )"
#      DISKSIZE=`parted "$DISK" -ms p | grep "$DISK" | cut -f 2 -d:`
      DISKSIZE=`lsblk "$DISK" -nid -o SIZE`
      echo "You picked $DISK ($DISKSIZE), it is correct? (y/n)"
      read ANS 
	    if [[ $ANS == "y" ]]
	    then
	      DISK_CHOOSED="$DISK"
	      break
	    else
	      return 1
	    fi
    done
  }

  chooseimg(){
    echo "Choose an image from $IMG_PATH"
    select FILENAME in $IMG_PATH/*;
    do
	    IMGSIZE=$( du -h $FILENAME | cut -f 1  )
	    echo "You picked $FILENAME ($IMGSIZE), you really want to flash it to $DISK_CHOOSED? (y/n)"
	    read ANS 
	    if [[ $ANS == "y" ]]
	    then
	       IMG_CHOOSED="$FILENAME"
	       break
	    else
	      return 1 
	    fi
    done
  }

  flash(){
     pv "$IMG_CHOOSED" | dd of="$DISK_CHOOSED" oflag=sync bs=1M status=none && echo "Finished"  2>&1
  }

fi

### MAIN

if [[ $1 == "" ]]
then 
  choosedisk
  (( $? )) && error 
else 
  DISK_CHOOSED=$1
fi

if [ ! -b "$DISK_CHOOSED" ] 
then
    error "Device $DISK_CHOOSED doesn't exist or is invalid"
fi

shift

if [[ $1 == "" ]]
then 
  chooseimg
  (( $? )) && error
elif [ -d "$1" ]
then
  IMG_PATH="$1"
  chooseimg
  (( $? )) && error
else
   IMG_CHOOSED="$1"
fi

if [ ! -e "$IMG_CHOOSED" ] 
then
    error "Image $IMG_CHOOSED doesn't exist"
fi

#IMGSIZE=$(du $IMG_CHOOSED | cut -f 1 )

flash
