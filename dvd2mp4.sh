#!/usr/bin/env bash

function fail {
    echo "$*"
    echo "     aborting ??????????"
    exit 2
}


os=$(uname -o)

if [ "$os" == "Darwin" ] ; then
    drive=/dev/disk2
else
    drive=/dev/sr0
fi
preset="HQ 480p30 Surround"
out_dir=~/work/DVD/${preset// /_}
mkdir -p $out_dir || exit 1
tsr=0
skip_rest=0

action=0
LSDVD=/usr/bin/lsdvd
time_field=4

bluray=0
while getopts "1b" c
do
	case $c in
		1)	action=1;;
		b)	LSDVD=~/dev/bluray_info/bluray_info
			time_field=6
			bluray=1;;
	esac
done
shift $((OPTIND-1))
 
 if [ ! -z "$1" ] ; then
	[ -f $1 ] || fail "$1 not found" 
	drive=$1
fi


dvd_info=$($LSDVD $drive 2>/dev/null)
if [ $bluray -eq 1 ] ; then
	label=$(sed -n "s/Disc title: '\([^']*\)'.*/\1/p" <<<$dvd_info)
else
	label=$(sed -n 's/Disc Title: //p' <<<$dvd_info)
fi

metafile=~/work/DVD/ISO/${label// /_}.meta

if [ -s $metafile ] ; then
	. $metafile
else
	titles=$(awk 'BEGIN {
	    MinSecs=600
	    result=""
	}
	/^Title:/{
	    split($'${time_field}',a,":")
	    s=a[3]+(a[2]*60) +(a[1]*3600)
	    if(s>=MinSecs ){
	    sub(/,/,"",$2);
	    printf "%d %s off ",$2,$'${time_field}'
	    }
	}
	' <<<$dvd_info)

	 
	res=$(whiptail  --checklist "Please check required titles" 20 60 15 $titles 3>&1 1>&2 2>&3)
	test $? -ne 0 && fail "No results from whiptail"
	res=${res//\"/}
	cat >$metafile<<EOF
res="$res"
label="$label"
EOF
fi

if [ "$action" == "1" ] ; then
	eject $drive
	exit
fi


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


