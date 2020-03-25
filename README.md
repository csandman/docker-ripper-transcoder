# docker-ripper-transcoder

This container will detect DVDs and BluRays by their type and rip them
automatically using MakeMKV and then transcode them using transcode-video.

## Tools and Ideas

This docker container is based on many different tools combined to make the
ideal ripping and transcoding machine

- [docker-ripper](https://github.com/rix1337/docker-ripper) - an initial tool
  to automatically rip movie files with make mkv
  - [MakeMKV Profiles](https://gist.github.com/csandman/5638a54730869cf4addf3df43f7fc845) -
    Use FLAC profile for initial rip
  - Download all video tracks (probably with 30 second cutoff OR the
    shortest extra length from dvdcompare)
- [video_transcoding](https://github.com/donmelton/video_transcoding) - A
  library of tools to transcode videos to a reasonable format using handbrake
  - [docker](https://hub.docker.com/r/ntodd/video-transcoding/) - A docker
    container containing the video transcoding library
  - [batch-transcode-video](https://github.com/nwronski/batch-transcode-video) -
    A nodejs application for batch transcoding the movie and all extras

## Setup

#### Docker run

```
docker run -d \
  --name="Ripper" \
  -v /path/to/config/:/config:rw \
  -v /path/to/rips/:/out:rw \
  --device=/dev/sr0:/dev/sr0 \
  rix1337/docker-ripper
```

#### Docker compose

```
version: '3.4'
services:
  ripper-transcoder:
    container_name: ripper-transcoder
    image: csandman/docker-ripper-transcoder
    volumes:
      - /appdata/ripper-transcoder/:/config:rw
      - /media/rips/:/out:rw
    devices:
      - /dev/sr0:/dev/sr0
```

## Tools and Ideas

- [docker-ripper](https://github.com/rix1337/docker-ripper) - an initial tool
  to automatically rip movie files with make mkv
  - [MakeMKV Profiles](https://gist.github.com/csandman/5638a54730869cf4addf3df43f7fc845) -
    Use FLAC profile for initial rip
  - Download all video tracks (probably with 30 second cutoff OR the
    shortest extra length from dvdcompare)
- [http://www.dvdcompare.net/index.php](dvdcompare.net) - Build a web scraper
  to parse the track lengths of each extra
  - Use something like mediainfo to get track length of each file in
    extracted extras
  - Perhaps use metadata from the bluray disk to determine the
    language/country for dvd compare
- [Automatic Ripping Machine](https://github.com/automatic-ripping-machine/automatic-ripping-machine) -
  Has some interesting tools for identifying the name and language of a movie
- [video_transcoding](https://github.com/donmelton/video_transcoding) - A
  library of tools to transcode videos to a reasonable format using handbrake
  - [docker](https://hub.docker.com/r/ntodd/video-transcoding/) - A docker
    container containing the video transcoding library
  - [batch-transcode-video](https://github.com/nwronski/batch-transcode-video) -
    A nodejs application for batch transcoding the movie and all extras
- https://github.com/lasley/node-makemkv
- https://www.reddit.com/r/DataHoarder/comments/9s6sln/if_the_words_tigole_featurettes_and_plex_mean/

## Next Steps

- Hit the [tvdb api](https://developers.themoviedb.org/3/search/search-movies) to find proper movie title and year
- Rename folder to Movie Title (year)
- Identify main movie file and rename to the same
- Move all other tracks to a subfolder called 'Featurettes'
- Identify extras based on their timestamps from dvdcompare.net
  - Search for the movie using results from tvdb and parse all extras lengths
  - match extras and rename files for all tracks searching the page in order

# Output

| Disc Type | Output | Tools used |
| --------- | ------ | ---------- |
| DVD       | MKV    | MakeMKV    |
| BluRay    | MKV    | MakeMKV    |

**To properly detect optical disk types in a docker environment this script
relies on makemkvcon output.**

MakeMKV is free while in Beta, but requires a valid license key. Ripper tries to
fetch the latest free beta key on launch. Without a purchased license key Ripper
may stop running at any time.

To add your purchased license key to MakeMKV/Ripper add it to the
`enter-your-key-then-rename-to.settings.conf` at `app_Key = "`**[ENTER KEY
HERE]**`"` and rename the file to settings.conf.

# FAQ

### How do I set ripper to do something else?

_Ripper will place a bash-file
([ripper.sh](https://github.com/rix1337/docker-ripper/blob/master/root/ripper/ripper.sh))
automatically at /config that is responsible for detecting and ripping disks.
You are completely free to modify it on your local docker host. No modifications
to this main image are required for minor edits to that file._

_Additionally, you have the option of creating medium-specific override scripts
in that same directory location:_

| Medium    | Script Name    | Purpose                                                                   |
| --------- | -------------- | ------------------------------------------------------------------------- |
| BluRay    | `BLURAYrip.sh` | Overrides BluRay ripping commands in `ripper.sh` with script operation    |
| DVD       | `DVDrip.sh`    | Overrides DVD ripping commands in `ripper.sh` with script operation       |
| Audio CD  | `CDrip.sh`     | Overrides audio CD ripping commands in `ripper.sh` with script operation  |
| Data-Disk | `DATArip.sh`   | Overrides data disk ripping commands in `ripper.sh` with script operation |

_Note that these optional scripts must be of the specified name, have executable
permissions set, and be in the same directory as `ripper.sh` to be executed._

### I want another output format that requires another piece of software!

_You need to fork this image and build it yourself on docker hub. A good
starting point is the
[Dockerfile](https://github.com/rix1337/docker-ripper/blob/master/Dockerfile#L30)
that includes setup instructions for the used ripping software. If your solution
works better than the current one, I will happily review your pull request._

### MakeMKV needs an update!

_Make sure you have pulled the latest image. The image should be updated
automatically as soon as MakeMKV is updated. This has not worked reliably in the
past. Just
[open a new issue](https://github.com/rix1337/docker-ripper/issues/new) and I
will trigger the build._

### Am I allowed to use this in a commercial setting?

_Yes, see
[LICENSE.md](https://github.com/rix1337/docker-ripper/blob/master/LICENSE.md)._
**If this project is helpful to your organization please sponsor me on
[Github Sponsors](https://github.com/sponsors/rix1337)!**

### Do you offer support?

_If plausible
[open a new issue](https://github.com/rix1337/docker-ripper/issues/new). I am
not responsible if anything breaks. For more information see
[LICENSE.md](https://github.com/rix1337/docker-ripper/blob/master/LICENSE.md)_

# Credits

- [Idea based on Discbox by kingeek](http://kinggeek.co.uk/projects/item/61-discbox-linux-bash-script-to-automatically-rip-cds-dvds-and-blue-ray-with-multiple-optical-drives-and-no-user-intervention)

  Kingeek uses proper tools (like udev) to detect disk types. This is
  impossible in docker right now. Hence, most of the work is done by MakeMKV
  (see above).

- [MakeMKV Setup by tobbenb](https://github.com/tobbenb/docker-containers)

- [MakeMKV key/version fetcher by metalight](http://blog.metalight.dk/2016/03/makemkv-wrapper-with-auto-updater.html)

## Custom Version

- Combine the functionality of docker-ripper and transcode video
  1. Automatically rip Blurays and DVDs, all tracks
  2. Transcode video files using Don Melton's transcode-video tool
  3. Pull extras names and length's from http://www.dvdcompare.net/index.php
  - Perhaps using some basic form of web scraper
  4. Name video files using this information in the following structure
  - /\<output-path\>/\<movie-name\>/
    - /\<featurettes\>/
    - /\<unidentified\>/
