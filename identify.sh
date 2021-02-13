#!/usr/bin/env bash

tmpfile=/tmp/dvd2mp4
function fail {
    echo "$*"
    echo "     aborting ??????????"
    rm ${tmpfile}* 2>/dev/null
    exit 2
}
#----------------------
# HandBrake settings


os=$(uname -o)
preset="HQ 480p30 Surround"
out_dir=~/work/DVD/${preset// /_}
mkdir -p $out_dir || exit 1

if [ "$os" == "Darwin" ] ; then
    drive=/dev/disk2
    NAS_BASE=/System/Volumes/Data
else
    drive=/dev/sr0
    NAS_BASE=/Diskstation
fi

META_DIR=$NAS_BASE/Unix/Videos/DVD.metadata
mkdir $META_DIR 2>/dev/null

action=0
while getopts "1p:s:e:" c
do
	case $c in
		1)	action=1;;
		p)	program=$OPTARG;;
		s) 	series=$OPTARG;;
		e)	episode=$OPTARG;;
	esac
done
shift $((OPTIND-1))

function get_disk_name {
	local dn=""
	local msg="Waiting for disk ."
	while :
	do
		dn=$(mount |sed -n -e "s?^$drive *[^ ]* \([^ ]*\) .*\$?\1?p"|sed 's/ /_/g')
		test -z "$dn" ||break
		1>&2 printf "$msg"
		msg="."
		sleep 5
	done

	echo ${dn##*/}
}
function get_titles {
	HandBrakeCLI -i $drive -t 0 --min-duration 600 --scan --json >${tmpfile}.hb 2>/dev/null||\
		fail "Could not get titles from $drive"	
	# Repair crappy format
	awk '{
    if(/^JSON Title Set/){ 
    	sub(/^.*{/,"{");

    	wanted=1 
    }
    if(wanted == 0) next
    print
	}
' ${tmpfile}.hb >${tmpfile}.json
	local res=$(jq -r  '.TitleList[] | "\(.Index) \(.Duration.Hours):\(.Duration.Minutes):\(.Duration.Seconds) off"'\
		${tmpfile}.json|\
		sed 's/[0-9]\{1,\}/0000000&/g;s/0*\([0-9]\{2,\}\)/\1/g')
			
	echo "$res"
}
function link_file { 
	[ -z "$program" ] && return
	[ -z "$series"  ] && return
	[ -z "$episode" ] && return
	local outfile=$1/$(printf "%s_S%2.2dE%2.2d_nometa.mp4" $program $series $episode)
	test -L $outfile && rm -f $outfile
	ln -s $1/$2 $outfile
	((episode++))
	return
}


disk=$(get_disk_name)

metafile=${META_DIR}/${disk}.meta

if [ ! -s $metafile ] ; then
	params=$(get_titles)
	wanted=$(whiptail --checklist "$disk:" 20 40 10 $params 3>&1 1>&2 2>&3)
	test -z "$wanted" && exit
	wanted=${wanted//\"/} 
	cat >$metafile<<EOF
label="$disk"
res="$wanted"
program=$program
series=$series
episode=$episode
EOF
	#((episode+=$(wc -w <<<$res)))
fi

if [ "$action" == "1" ] ; then
	echo "."
	cat $metafile
	eject $drive
	exit
fi

. $metafile
#---------
section=0
all_fn=""
for tnr in $res
do
	((section++))
	ofn=$(printf "%s-part-%2.2d.mp4" ${label} $tnr)
	all_fn="$all_fn $ofn"
	test -s $out_dir/$ofn && continue
	touch $out_dir/$ofn
	HandBrakeCLI -i $drive -t $tnr --preset "$preset" --optimize \
		--audio-lang-list eng --output $out_dir/temporary.mp4
	if [ $? -eq 0 ] ; then
		mv $out_dir/temporary.mp4 $out_dir/$ofn
		link_file $out_dir $ofn
	else
		rm $out_dir/$ofn
	fi
done

cd $out_dir
for fn in $(ls ${label}-part-*.mp4)
do
	[[ $all_fn == *$fn* ]] || rm -i $fn
done

eject $drive
