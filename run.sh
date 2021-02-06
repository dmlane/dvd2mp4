#!/usr/bin/env bash

os=$(uname -o)

if [ "$os" == "Darwin" ] ; then
    drive=/dev/disk2
else
    drive=/dev/sr0
fi

LIMIT=600
title=""
while getopts "t:e:s:p:" c
do
	case $c in
		t)	titles="$title $OPTARG";;
		e)	episode=$OPTARG;;
		s)	series=$OPTARG;;
		p)	program=$OPTARG;;
	esac
done
# Get a list of titles we want

LAST_IFS=$IFS
IFS=$'\n'
NR=0
wanted_titles=""
preset="Fast 480p30"
preset="HQ 480p30 Surround"
out_dir=~/work/DVD/${preset// /_}
mkdir -p $out_dir i|| exit 1
#2>/dev/null 
tsr=0
skip_rest=0

for rec in $(lsdvd $drive 2>/dev/null)
do
	((NR++))
	if [ $NR == 1 ] ; then
		disk_title=$(sed 's/^.*: //'<<<$rec)
		continue
	fi
	[[ $rec =~ ^Title: ]] || continue

	title=0x10$(sed -E -e 's/^Title: ([0-9]*),.*$/\1/' <<< $rec)

	length=$(sed -E -e 's/^.*Length: (.*) Chapters.*$/01-Jan-1970 \1 UTC/' <<< $rec)
	length=$(date --date="$length" +"%s")
	if [ $length -lt $LIMIT ] ; then
		skip_rest=1
		continue
	fi
	[ $skip_rest -ne 0 ] && continue
	((tsr++))
	title_length[$tsr]=$length
	title_number[$tsr]=$((title+0))
done
total=0
for ((n=2;n<=$tsr;n++))
do
	((total+=${title_length[$n]}))
	wanted_titles="$wanted_titles ${title_number[$n]}"
done
if [ $total -ne ${title_length[1]} ] ; then
	wanted_titles="${title_number[1]} $wanted_titles "
fi
IFS=$LAST_IFS
echo " Disk title = '$disk_title'"
echo "     Wanted - '$wanted_titles'"

section=0
for tnr in $wanted_titles
do
	((section++))
	ofn="${disk_title}-part-$section.mp4"
	test -s $out_dir/$ofn && continue
	touch $out_dir/$ofn
	HandBrakeCLI -i $drive -t $tnr --preset "$preset" --optimize \
		--audio-lang-list eng --output $out_dir/temporary.mp4
	if [ $? -eq 0 ] ; then
		mv $out_dir/temporary.mp4 $out_dir/$ofn
	else
		rm $out_dir/$ofn
	fi
done
eject $drive
