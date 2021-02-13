#!/usr/bin/env bash

if [ "$os" == "Darwin" ] ; then
    NAS_BASE=/System/Volumes/Data
else
    NAS_BASE=/Diskstation
fi
MP4_DIR=$NAS_BASE/Unix/Videos/Import
SPLIT_FOLDER=~/work/Videos/Split
extra_path=~/dev/mp4proc
test -d $extra_path || fail "$extra_path is missing"
export PATH=$PATH:$extra_path

function usage {
    echo "$0 -p <program> -s <series_number> file_names"
    exit 1
}
function fail {
    echo "$*"
    echo "     aborting ??????????"
    exit 2
}

# Portable way to get real path .......
readlinkf(){ perl -MCwd -e 'print Cwd::abs_path shift' "$1";}

while getopts "t:e:s:p:" c
do
    case $c in
        s)  series=$OPTARG;;
        p)  program=$OPTARG;;
    esac
done
shift $((OPTIND-1))

test -z "$program" && fail "You must supply program name (-p)"
test -z "$series" && fail "You must supply series number (-s)"
#---------------------------------------------------------------------
# Check we have access to NAS 
test -d $MP4_DIR    || fail "MP4_DIR $MP4_DIR not found"
PROCDIR=$NAS_BASE/Unix/Videos/Processed/$program
mkdir -p $PROCDIR   || fail "Could not create folder $PROCDIR"

# We want to make sure we never delete this, so link the files here
DVDDIR=$NAS_BASE/Unix/Videos/Keep.me/$program
mkdir -p $DVDDIR   || fail "Could not create folder $DVDDIR"

SAVEDIR=$NAS_BASE/Unix/Videos/DVD.keep_1_week/$program
mkdir -p $SAVEDIR   || fail "Could not create folder $SAVEDIR"

# Sources might come from multiple directories, so sort on basename


episode=0
ffn=""
for fn in "$@"
do
    ffn="${ffn}$(readlinkf $fn)\n"
done
sorted=$(printf $ffn|sed 's?^\(.*/\)\(.*\)?\2 \1?'|sort|sed 's?^\(.*\) \(.*\)$?\2\1?')
episode=0
disk=''
for fn in $sorted
do
    d=${fn##*/}
    d=${d%-part*}
    [ -z "$disk" ] && disk=$d
    if [ "$disk" != "$d" ] ; then
        disk=$d
        printf "\n"
    fi

    ((episode++))
    printf "%2d:%40s\n" $episode $fn
done
printf "\n"
read -r -p "Are you sure? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]] ; then
    :
else
    fail "OK - quitting"
fi

episode=0
for fn in $sorted
do
    echo $fn
    ((episode++))
    outfile=$(printf "%s_S%2.2dE%2.2d.mp4" $program $series $episode)
    dvd_file=$DVDDIR/$outfile 
    vid_file=$PROCDIR/$outfile

    # Check if output already exists
    if [ -f $dvd_file ] ; then
        if [ -f $vid_file ] ; then
            if [ $dvd_file -ef $vid_file ] ; then
                # Output can be overwritten
                rm -f $dvd_file $vid_file
            else
                echo "$vid_file not the same as $dvd_file - saving it"
                mv -v --backup=numbered $vid_file ${vid_file}.backup || \
                    fail "Could not save $vid_file"
                rm -f $dvd_file
            fi
        else
            rm -f $dvd_file
        fi
    fi


    add_metadata.sh -i $fn -p $program -s $series -e $episode $dvd_file
    test $? -ne 0 && fail "Failed to create metadata file"
    
    ln -v $dvd_file $vid_file ||
        fail "Could not create link  $vid_file"
 
done
mv -v "$@" $SAVEDIR/