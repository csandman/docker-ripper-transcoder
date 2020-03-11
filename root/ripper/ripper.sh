#!/bin/bash

RIPPER_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
LOGFILE="/config/Ripper.log"

# Startup Info
echo "$(date "+%d.%m.%Y %T") : Starting Ripper. Optical Discs will be detected and ripped within 60 seconds."

# Separate Raw Rip and Finished Rip Folders for DVDs and BluRays
# Raw Rips go in the usual folder structure
# Finished Rips are moved to a "finished" folder in it's respective STORAGE folder
SEPARATERAWFINISH="true"

TRANSCODE="true"

# Paths
STORAGE_DVD="/out/Ripper/DVD"
STORAGE_BD="/out/Ripper/BluRay"
DRIVE="/dev/sr0"

BAD_THRESHOLD=5
let BAD_RESPONSE=0

# True is always true, thus loop indefinitely
while true
do
# delete MakeMKV temp files
cwd=$(pwd)
cd /tmp
rm -r *.tmp
cd $cwd

# get disk info through makemkv and pass output to INFO
INFO=$"`makemkvcon -r --cache=1 info disc:9999 | grep DRV:0`"
# check INFO for optical disk
EMPTY=`echo $INFO | grep -o 'DRV:0,0,999,0,"'`
OPEN=`echo $INFO | grep -o 'DRV:0,1,999,0,"'`
LOADING=`echo $INFO | grep -o 'DRV:0,3,999,0,"'`
BD1=`echo $INFO | grep -o 'DRV:0,2,999,12,"'`
BD2=`echo $INFO | grep -o 'DRV:0,2,999,28,"'`
DVD=`echo $INFO | grep -o 'DRV:0,2,999,1,"'`
CD1=`echo $INFO | grep -o 'DRV:0,2,999,0,"'`
CD2=`echo $INFO | grep -o '","","'$DRIVE'"'`

# Check for trouble and respond if found
EXPECTED="${EMPTY}${OPEN}${LOADING}${BD1}${BD2}${DVD}${CD1}${CD2}"
if [ "x$EXPECTED" == 'x' ]; then
 echo "$(date "+%d.%m.%Y %T") : Unexpected makemkvcon output: $INFO"
 let BAD_RESPONSE++
else
 let BAD_RESPONSE=0
fi
if (( $BAD_RESPONSE >= $BAD_THRESHOLD )); then
 echo "$(date "+%d.%m.%Y %T") : Too many errors, ejecting disk and aborting"
 # Run makemkvcon once more with full output, to potentially aid in debugging
 makemkvcon -r --cache=1 info disc:9999
 eject $DRIVE >> $LOGFILE 2>&1
 exit 1
fi

# if [ $EMPTY = 'DRV:0,0,999,0,"' ]; then
#  echo "$(date "+%d.%m.%Y %T") : No Disc"; &>/dev/null
# fi
if [ "$OPEN" = 'DRV:0,1,999,0,"' ]; then
 echo "$(date "+%d.%m.%Y %T") : Disk tray open"
fi
if [ "$LOADING" = 'DRV:0,3,999,0,"' ]; then
 echo "$(date "+%d.%m.%Y %T") : Disc still loading"
fi

if [ "$BD1" = 'DRV:0,2,999,12,"' ] || [ "$BD2" = 'DRV:0,2,999,28,"' ]; then
 DISKLABEL=`echo $INFO | grep -o -P '(?<=",").*(?=",")'`
 BDPATH="$STORAGE_BD"/"$DISKLABEL"
 BLURAYNUM=`echo $INFO | grep $DRIVE | cut -c5`
 mkdir -p "$BDPATH"
 ALT_RIP="${RIPPER_DIR}/BLURAYrip.sh"
 if [[ -f $ALT_RIP && -x $ALT_RIP ]]; then
    echo "$(date "+%d.%m.%Y %T") : BluRay detected: Executing $ALT_RIP"
    $ALT_RIP "$BLURAYNUM" "$BDPATH" "$LOGFILE"
 else
    # BluRay/MKV
    echo "$(date "+%d.%m.%Y %T") : BluRay detected: Saving MKV"
    makemkvcon --profile=/config/flac.mmcp.xml -r --decrypt --minlength=15 mkv disc:"$BLURAYNUM" all "$BDPATH" >> $LOGFILE 2>&1
 fi
 if [ "$SEPARATERAWFINISH" = 'true' ]; then
    BDFINISH="$STORAGE_BD"/finished/
    mv -v "$BDPATH" "$BDFINISH"
 fi
 if [ "$TRANSCODE" = 'true' ]; then
    BDTRANSCODE="$STORAGE_BD"/transcode/
    batch-transcode-video --crop 1 --diff --quiet --input "$BDFINISH" --output "$BDTRANSCODE" -- --no-auto-burn --add-subtitle all >> $LOGFILE 2>&1
 fi
 echo "$(date "+%d.%m.%Y %T") : Done! Ejecting Disk"
 eject $DRIVE >> $LOGFILE 2>&1
 # permissions
 chown -R nobody:users "$STORAGE_BD" && chmod -R g+rw "$STORAGE_BD"
fi

if [ "$DVD" = 'DRV:0,2,999,1,"' ]; then
 DISKLABEL=`echo $INFO | grep -o -P '(?<=",").*(?=",")'` 
 DVDPATH="$STORAGE_DVD"/"$DISKLABEL"
 DVDNUM=`echo $INFO | grep $DRIVE | cut -c5`
 mkdir -p "$DVDPATH"
 ALT_RIP="${RIPPER_DIR}/DVDrip.sh"
 if [[ -f $ALT_RIP && -x $ALT_RIP ]]; then
    echo "$(date "+%d.%m.%Y %T") : DVD detected: Executing $ALT_RIP"
    $ALT_RIP "$DVDNUM" "$DVDPATH" "$LOGFILE"
 else
    # DVD/MKV
    echo "$(date "+%d.%m.%Y %T") : DVD detected: Saving MKV"
    makemkvcon --profile=/config/flac.mmcp.xml -r --decrypt --minlength=15 mkv disc:"$DVDNUM" all "$DVDPATH" >> $LOGFILE 2>&1
 fi
 if [ "$SEPARATERAWFINISH" = 'true' ]; then
    DVDFINISH="$STORAGE_DVD"/finished/
    mv -v "$DVDPATH" "$DVDFINISH" 
 fi
 if [ "$TRANSCODE" = 'true' ]; then
    DVDTRANSCODE="$STORAGE_DVD"/transcode/
    batch-transcode-video --crop 1 --diff --quiet --input "$DVDFINISH" --output "$DVDTRANSCODE" -- --no-auto-burn --add-subtitle all >> $LOGFILE 2>&1
 fi
 echo "$(date "+%d.%m.%Y %T") : Done! Ejecting Disk"
 eject $DRIVE >> $LOGFILE 2>&1
 # permissions
 chown -R nobody:users "$STORAGE_DVD" && chmod -R g+rw "$STORAGE_DVD"
fi

# Wait a minute
sleep 1m
done
