#!/usr/bin/env bash


# Get a list of titles we want
source_disk=/dev/sr0

LAST_IFS=$IFS
IFS=$'\n'
NR=0
wanted_titles=""
preset="Fast 480p30"
preset="HQ 480p30 Surround"
out_dir=~/work/DVD/${preset// /_}
mkdir -p $out_dir i|| exit 1
#2>/dev/null 
for rec in $(lsdvd)
do
	((NR++))
	if [ $NR == 1 ] ; then
		disk_title=$(sed 's/^.*: //'<<<$rec)
		continue
	fi
	if [ $NR == 2 ] ; then
		total_cells=10#$(sed 's/^.*Cells: \([0-9][0-9]*\),.*$/\1/'<<<$rec)
		continue
	fi
	cells=10#$(sed 's/^.*Cells: \([0-9][0-9]*\),.*$/\1/'<<<$rec)
	tnr=$(sed 's/^Title: \([0-9][0-9]*\),.*$/\1/'<<<$rec)
	[[ $total_cells -gt 0 ]] && wanted_titles="$wanted_titles $tnr"
	total_cells=$((total_cells-cells))
done
IFS=$LAST_IFS
echo " Disk title = '$disk_title'"
echo "     Wanted - '$wanted_titles'"

set -xv
section=0
for tnr in $wanted_titles
do
	((tnr+=0))
	((section++))
	ofn="${disk_title}-part-$section.mp4"
	HandBrakeCLI -i /dev/sr0 -t $tnr --preset "$preset" --optimize \
		--audio-lang-list eng --output $out_dir/$ofn
done