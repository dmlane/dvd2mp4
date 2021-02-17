#!/usr/bin/env bash

if [ "$os" == "Darwin" ] ; then
    NAS_BASE=/System/Volumes/Data
else
    NAS_BASE=/Diskstation
fi
INPUT_FOLDER=~/work/DVD/HQ_480p30_Surround

if [ "$os" == "Darwin" ] ; then
    drive=/dev/disk2
    NAS_BASE=/System/Volumes/Data
else
    drive=/dev/sr0
    NAS_BASE=/Diskstation
fi

META_DIR=$NAS_BASE/Unix/Videos/DVD.metadata

MP4_DIR=$NAS_BASE/Unix/Videos/Import
SPLIT_FOLDER=~/work/Videos/Split
extra_path=~/dev/mp4proc
test -d $extra_path || fail "$extra_path is missing"
export PATH=$PATH:$extra_path

function fail {
	printf "\n"
	echo "$*"
	echo "     aborting ??????????"
	exit 2
}


ffmpeg=$(command -v ffmpeg)
[ $? -eq 0 ] || fail "Cannot find ffmeg on path"

function FFMPEG {
	echo $ffmpeg $@
	$ffmpeg "$@"
}

function compare_videos {
	local hash1=$(ffmpeg -v error -i $1 -map 0:v -c copy -f md5 -)
	local hash2=$(ffmpeg -v error -i $2 -map 0:v -c copy -f md5 -)
	[ "$hash1" == "$hash2" ] && return 0
	fail "Hashes differed for $1 and $2"

}

function recently_modified {
	local now=$(date +%s)
	local filetime=$(stat $1 -c %Y)
	local timediff=$(expr $now - $filetime)
	[ $timediff -gt $2 ] && return 1
	return 0
}
function add_metadata {
	local metafile=/tmp/metadata.reorg
	local tempfile=$(dirname $1)/meta_added.mp4
	local interfile=$(dirname $2)/meta_added.mp4
	[ -f $tempfile ] && rm $tempfile

	cat >$metafile<<EOF
;FFMETADATA1
major_brand=isom
minor_version=512
compatible_brands=isomiso2avc1mp41
title=$title
episode_sort=$episode
show=$program
season_number=$series
media_type=10
encoder=Lavf58.20.100	
EOF
	printf "Adding metadata for $1 "
	FFMPEG -v error -i $1 -y -i $metafile -map_metadata 1 -c:v copy -c:a copy $tempfile
	[ $? -eq 0 ] || fail "Adding metadata for $1 failed"	
	printf "OK\n    Checking results "
	compare_videos $1 $tempfile
	printf "OK\n"
	mv -v $tempfile $interfile ||\
		fail "Failed to move $tempfile to $interfile"
	mv -v $interfile $2 ||\
		fail "Failed to move $interfile to $2"
}

# Portable way to get real path .......
readlinkf(){ perl -MCwd -e 'print Cwd::abs_path shift' "$1";}

for prefix in $(find $INPUT_FOLDER -name "*part*.mp4" -printf "%P \n"|sed 's/\-part.*$//'|sort -u)
do
	metafile=${META_DIR}/${prefix}.meta
	if [ ! -f $metafile ] ; then
	 	echo "$metafile not found"
	 	continue
	fi
	program=""
	series=""
	episode=""
	. $metafile
	if [[ $program && $series && $episode ]] ; then
		:
	else
		echo "$metafile missing some items"
		continue
	fi
	OUTPUT_FOLDER=$NAS_BASE/Unix/Videos/Processed/$program
	test -d $OUTPUT_FOLDER || mkdir $OUTPUT_FOLDER

	((episode--))
	for tnr in $res
	do
		((episode++))
	
		fn=$(printf "%s-part-%2.2d.mp4" ${label} $tnr)
		infile=$INPUT_FOLDER/$fn
		recently_modified $infile 3600 && continue

	
		title=$(printf "%s_S%2.2dE%2.2d" $program $series $episode)
		outfile=${title}.mp4

		[ -L $INPUT_FOLDER/$outfile ] && rm -f $INPUT_FOLDER/$outfile
		test -f $OUTPUT_FOLDER/$outfile && continue
		test -s $infile || fail "Expected to find $infile"
		
		echo $fn ..... $outfile
		add_metadata  $INPUT_FOLDER/$fn  $OUTPUT_FOLDER/$outfile

		rm $INPUT_FOLDER/$fn
	done
done