#!/usr/bin/env bash

function fail {
    echo "$*"
    echo "     aborting ??????????"
    exit 2
}
program=$1
case $program in
	GilmoreGirls) series_lengths="21 22 22 22 22 22 22";;
	Smallville) series_lengths="21 23 22 22 22 22 20 22 21 22";;
	*) fail "Program '$program' not known";;
esac

if [ "$os" == "Darwin" ] ; then
    NAS_BASE=/System/Volumes/Data
else
    NAS_BASE=/Diskstation
fi
KEEP_FOLDER=$NAS_BASE/Unix/Videos/Keep.me/$program
PROCESSED_FOLDER=$NAS_BASE/Unix/Videos/Processed/$program

series=1
for max_episode in $series_lengths
do
	echo "Checking $program season $series for $max_episode episodes ......."
	for ((episode=1;episode<=$max_episode;episode++))
	do
		fn=$(printf "%s_S%2.2dE%2.2d.mp4" $program $series $episode)
		missing="$fn missing in "
		for loc in $KEEP_FOLDER $PROCESSED_FOLDER
		do
			if [ ! -f $loc/$fn ] ; then
				printf "%s\n    %s" "$missing" $loc
				missing=""
			fi
		done
		test -z "$missing" && printf "\n"
	done
	((series++))
done

