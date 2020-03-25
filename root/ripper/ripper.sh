#!/bin/bash

RIPPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
LOG_FILE="/config/rt.log"

# Startup Info
echo "$(date "+%d.%m.%Y %T") : Starting Ripper. Optical Discs will be detected and ripped within 60 seconds."

# Separate Raw Rip and Finished Rip Folders for DVDs and BluRays
# Raw Rips go in the usual folder structure
# Finished Rips are moved to a "finished" folder in it's respective STORAGE folder

TRANSCODE="true"

# Paths
STORAGE_RIPS="/out/rips"
STORAGE_TRANSCODES="/out/transcodes"
DRIVE="/dev/sr0"

BAD_THRESHOLD=5
let BAD_RESPONSE=0

# True is always true, thus loop indefinitely
while true; do
  # delete MakeMKV temp files
  cwd=$(pwd)
  cd /tmp
  rm -r *.tmp
  cd $cwd

  # get disk info through makemkv and pass output to INFO
  INFO=$"$(makemkvcon -r --cache=1 info disc:9999 | grep DRV:0)"
  # check INFO for optical disk
  EMPTY=$(echo $INFO | grep -o 'DRV:0,0,999,0,"')
  OPEN=$(echo $INFO | grep -o 'DRV:0,1,999,0,"')
  LOADING=$(echo $INFO | grep -o 'DRV:0,3,999,0,"')
  BD1=$(echo $INFO | grep -o 'DRV:0,2,999,12,"')
  BD2=$(echo $INFO | grep -o 'DRV:0,2,999,28,"')
  DVD=$(echo $INFO | grep -o 'DRV:0,2,999,1,"')
  CD1=$(echo $INFO | grep -o 'DRV:0,2,999,0,"')
  CD2=$(echo $INFO | grep -o '","","'$DRIVE'"')

  # Check for trouble and respond if found
  EXPECTED="${EMPTY}${OPEN}${LOADING}${BD1}${BD2}${DVD}${CD1}${CD2}"
  if [ "x$EXPECTED" == 'x' ]; then
    echo "$(date "+%d.%m.%Y %T") : Unexpected makemkvcon output: $INFO" >>$LOG_FILE 2>&1
    let BAD_RESPONSE++
  else
    let BAD_RESPONSE=0
  fi
  if (($BAD_RESPONSE >= $BAD_THRESHOLD)); then
    echo "$(date "+%d.%m.%Y %T") : Too many errors, ejecting disk and aborting" >>$LOG_FILE 2>&1
    # Run makemkvcon once more with full output, to potentially aid in debugging
    makemkvcon -r --cache=1 info disc:9999
    eject $DRIVE >>$LOG_FILE 2>&1
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
    DISK_LABEL=$(echo $INFO | grep -o -P '(?<=",").*(?=",")')
    DISK_PATH="$STORAGE_RIPS"/"$DISK_LABEL"
    DISK_NUM=$(echo $INFO | grep $DRIVE | cut -c5)
    mkdir -p "$DISK_PATH"
    ALT_RIP="${RIPPER_DIR}/BLURAYrip.sh"
    if [[ -f $ALT_RIP && -x $ALT_RIP ]]; then
      echo "$(date "+%d.%m.%Y %T") : BluRay detected: Executing $ALT_RIP"
      $ALT_RIP "$DISK_NUM" "$DISK_PATH" >>$LOG_FILE 2>&1
    else
      # MKV
      echo "$(date "+%d.%m.%Y %T") : BluRay detected: Saving MKV"
      makemkvcon --profile=/config/profile.mmcp.xml --decrypt --minlength=15 mkv disc:"$DISK_NUM" all "$DISK_PATH" >>$LOG_FILE 2>&1
    fi
    echo "$(date "+%d.%m.%Y %T") : Finished ripping, begin transcoding"
    echo "batch-transcode-video --debug --crop 1 --diff --input $DISK_PATH/$DISK_LABEL --output $STORAGE_TRANSCODES/$DISK_LABEL -- --no-auto-burn --add-subtitle all" >>$LOG_FILE 2>&1
    batch-transcode-video --debug --crop 1 --diff --input "$DISK_PATH"/"$DISK_LABEL" --output "$STORAGE_TRANSCODES"/"$DISK_LABEL" -- --no-auto-burn --add-subtitle all >>$LOG_FILE 2>&1
    echo "$(date "+%d.%m.%Y %T") : Done! Ejecting Disk"
    eject $DRIVE >>$LOG_FILE 2>&1
    # permissions
    chown -R nobody:users /out && chmod -R g+rw /out
  fi

  if [ "$DVD" = 'DRV:0,2,999,1,"' ]; then
    DISK_LABEL=$(echo $INFO | grep -o -P '(?<=",").*(?=",")')
    DISK_PATH="$STORAGE_RIPS"/"$DISK_LABEL"
    DISK_NUM=$(echo $INFO | grep $DRIVE | cut -c5)
    mkdir -p "$DISK_PATH"
    ALT_RIP="${RIPPER_DIR}/DVDrip.sh"
    if [[ -f $ALT_RIP && -x $ALT_RIP ]]; then
      echo "$(date "+%d.%m.%Y %T") : DVD detected: Executing $ALT_RIP"
      $ALT_RIP "$DISK_NUM" "$DISK_PATH" >>$LOG_FILE 2>&1
    else
      # MKV
      echo "$(date "+%d.%m.%Y %T") : DVD detected: Saving MKV"
      makemkvcon --profile=/config/profile.mmcp.xml --decrypt --minlength=15 mkv disc:"$DISK_NUM" all "$DISK_PATH" >>$LOG_FILE 2>&1
    fi
    echo "$(date "+%d.%m.%Y %T") : Finished ripping, begin transcoding"
    echo "batch-transcode-video --debug --crop 1 --diff --input $DISK_PATH/$DISK_LABEL --output $STORAGE_TRANSCODES/$DISK_LABEL -- --no-auto-burn --add-subtitle all" >>$LOG_FILE 2>&1
    batch-transcode-video --debug --crop 1 --diff --input "$DISK_PATH"/"$DISK_LABEL" --output "$STORAGE_TRANSCODES"/"$DISK_LABEL" -- --no-auto-burn --add-subtitle all >>$LOG_FILE 2>&1
    echo "$(date "+%d.%m.%Y %T") : Done! Ejecting Disk"
    eject $DRIVE >>$LOG_FILE 2>&1
    # permissions
    chown -R nobody:users /out && chmod -R g+rw /out
  fi

  # Wait a minute
  sleep 1m
done
