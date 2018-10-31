#!/usr/bin/env zsh

# Set global variables
PROGNAME=$(basename "$0")
VERSION='1.0.0'

##
# Check for a dependancy
#
# @param 1 Command to check
##
dependancy() {
  hash "$1" &>/dev/null || error "$1 must be installed"
}

##
# Print help menu
#
# @param 1 exit code
##
function printHelpAndExit {
cat <<EOF
Usage:     $PROGNAME [options] input-file
Version:   $VERSION
Options: (all optional)
  -f value  Fade duration
  -o value  The output file
  -v        Print version
Example:
  $PROGNAME -f 2 sample.mp4
EOF
exit $1
}

################################################################################

# Check dependacies
dependancy ffmpeg
dependancy ffprobe

# Initialize variables
fade_duration=1

# Get options
while getopts "f:o:hv" opt; do
  case $opt in
    f) fade_duration=$OPTARG;;
    h) printHelpAndExit 0;;
    o) outfile=$OPTARG;;
    v)
      echo "$VERSION"
      exit 0
      ;;
    *) printHelpAndExit 1;;
  esac
done

shift $(( OPTIND - 1 ))

infile="$1"
if [ -z "$outfile" ]; then
  outfile="$2"
fi

if [ -z "$outfile" ]; then
  # Strip off extension and add new extension
  ext="${infile##*.}"
  filepath=$(dirname "$infile")
  outfile="$filepath/$(basename "$infile" ".$ext")-crossfade.mp4"
fi

if [ -z "$infile" ]; then printHelpAndExit 1; fi

video_duration=$(ffprobe -i "$infile" -show_entries format=duration -v quiet -of csv="p=0")
keyframe=$((video_duration-2*fade_duration))

# When the fade duration is more than half the video duration,
# it isn't possible to achieve the fade.
# Update the fade duration to equal half of the video duration,
# so the entire video is crossfaded
if [[ keyframe -lt 0 ]]; then
  fade_duration=$((video_duration/2))
fi

ffmpeg -i "$infile" -filter_complex "
  [0]split[v1][v2];
  [v2]trim=duration=${fade_duration},fade=d=${fade_duration}:alpha=1,
    setpts='PTS+(max(${video_duration}-2*${fade_duration},0)/TB)'[faded];
  [v1]trim=${fade_duration},setpts=PTS-STARTPTS[main];
  [main][faded]overlay" \
  -vcodec libx264 -an -preset veryslow -movflags faststart "$outfile"
