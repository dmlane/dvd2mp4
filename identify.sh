#!/usr/bin/env bash

episode=1

while :
do
	~/dev/dvd2mp4/dvd2mp4.sh -p $1 -s $2 -e $episode -1
	test $? -eq 0 || break
	episode=$(cat /tmp/episode)
	echo episode now $episode
done
