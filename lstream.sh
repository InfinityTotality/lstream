#!/bin/bash

# API stream list seems to only support returning 100 at a time, and this seems sufficient for popular streams
twitch_limit=100
debuglevel=0
player="mpv"
cacheopts="-cache 8192 -cache-min 4"

print_help () {
	callname=`basename "$0"`
	echo "Usage: 
	$callname [options] [function] <query>

	Functions:
	These functions are exclusive and only one can be used per call. If multiple are
	specified, the script will exit after the first one is enountered and run. Any
	argument immediately following a function will be treated as the query.
	
	-p
	  Print the stream url which would normally be passed to livestreamer.

	-l
	  List the available stream qualities for the selected stream.

	-h
	  Print this help.

	Options:
	Combining options in a single argument (golfing) is not currently supported.

	-c
	  Run the player and options specified in the nocache entry in .lstreamrc.

	-q quality
	  Use the specified quality for the stream. (use -l for a list of available qualities)
	
	-v / -vv / -vvv
	  Verbosity. Run with specified level of extra debug output.

	-a
	  Ignore saved streams and searches for the query normally.

	-o player
	  Player specification. Will use the following single argument as the player string.

	-e
	  Will use the query as the exact stream name, i.e. twitch.tv/<query>

	-s entry
	  Save the stream url under the name supplied in the following argument.
	  This option may be used immediately before the search query, in which case 
	  the entry may be omitted, and the stream will be saved under the query instead."
}

# function to print debug messages if script is run with specified debug level (-v/vv/vvv)
debug () {
	# save exit status of previous command
	exit=$?
	if [ "$1" -gt $debuglevel ]
	then
		return
	fi
	level="$1"
	shift
	# print empty line if debug level is reached but no debug message
	if [ -z "$1" ]
	then
		echo
	# support reading from stdin with argument -
	elif [ "$1" = - ]
	then
		sed "s|^|[$exit]($level): |" | cat -
	else
		echo "[$exit]($level): $@"
	fi
}

# do the work of procuring stream url given the query
find_stream () {
	twitch_results=0

	# search list of saved stream urls if nocache is not specified (by -a or -s)
	if [ ! $nocache ]
	then
		local cached=`grep "^$1 " ~/.streamlist`
	fi
	# if a match is found, save as stream and return
	if [ ! -z "$cached" ]
	then
		stream=`echo "$cached" | awk '{print $2}'`
		return 0
	fi

	debug 1 "query: $1"

	debug 1 "twitch limit: $twitch_limit"

	# fetch json stream list from REST API
	local twitch_raw=`curl -s https://api.twitch.tv/kraken/streams?limit=$twitch_limit`
	#debug 3 "twitch raw:"
	#debug 3 "$twitch_raw"
	
	# parse json into list of stream names and descriptions
	local twitch_list=`echo "$twitch_raw" | jshon -e streams -a -e channel -e name -u -p -e status | paste -s -d '\t\n'`
	debug 3 "twitch list:"
	debug 3 "$twitch_list"

	# search parsed list for query with grep and process if any matches
	if twitch_matches=`echo "$twitch_list" | grep -in "$1"`
	then
		debug 1 "twitch matches:"
		debug 1 "$twitch_matches"
		twitch_results=`echo "$twitch_matches" | wc -l`

		# count beginning with 1 so array indices coincide with user choice entry
		local i=1
		# process each matching line found, putting the stream names and urls into arrays to present to user
		while read line
		do
			debug 1 "current processing line: $line"
			# take json element index from line numbers added by grep above, offset by 1
			let index=$(echo "$line" | cut -d: -f1)-1
			debug 1 "result index: $index"
			# fetch stream display name to present to user and stream url for matches
			twitch_names[$i]=`echo "$twitch_raw" | jshon -e streams -e $index -e channel -e display_name -u`
			twitch_urls[$i]=`echo "$twitch_raw" | jshon -e streams -e $index -e channel -e url -u`
			debug 1 "entry $i name: ${twitch_names[$i]}"
			debug 1 "entry $i url: ${twitch_urls[$i]}"
			let i++
		done <<< "$twitch_matches"
	else
		# set results for twitch to 0 if grep has nonzero exit status
		# to support searching multiple services in the future (and the past, RIP own3d)
		twitch_results=0
		debug 2 "no results, exiting find_stream"
		return 1
	fi

	# if only 1 result, save it as the stream to play
	if [ $twitch_results -eq 1 ]
	then
		stream=${twitch_urls[1]}
		debug 2 "one result, exiting find_stream"
	fi

	debug 2 "exiting find_stream"
}

# present results to user and read selection
print_results () {
	debug 2 "starting print_results"
	local count=1
	debug 1 "twitch results: $twitch_results"
	if [ $twitch_results -gt 0 ]
	then
		echo "Twitch.tv:"
		for i in "${twitch_names[@]}"
		do
			echo "$count. $i"
			let count++
		done
	fi
	echo -n "Enter your selection: "
	read choice
	if [[ ! "$choice" =~ [0-9]+ ]] 
	then
		exit 0
	elif [ $choice -gt $twitch_results ] || [ $choice -lt 1 ]
	then
		exit 1
	else
		stream=${twitch_urls[$choice]}
	fi
}

# handle making sure a stream is found if there is one to be found
get_stream () {
	if find_stream "$1"
	then
		if [ -z "$stream" ]
		then
			print_results
		fi
	else
		echo "No results found"
		exit 1
	fi
}

while [ ! -z "$1" ]
do
	case "$1" in
		-v)
			debuglevel=1
			shift ;;
		-vv)
			debuglevel=2
			shift ;;
		-vvv)
			debuglevel=3
			shift ;;
		-a)
			all=true
			nocache=true
			shift ;;
		-e)
			exact=true
			shift ;;
		-c)
			noplayercache=true
			shift ;;
		-o)
			player="$2"
			noplayercache=true
			shift 2 ;;
		-q)
			quality="$2"
			shift 2 ;;
		-s)
			save=true
			nocache=true
			entry="$2"
		        shift 1
			if [ $# -gt 1 ]
			then
				shift 1
			fi ;;
		-p)
			get_stream "$2"
			echo $stream
			break ;;
		-l)
			get_stream "$2"
			livestreamer $stream
			break ;;
		-h)
			print_help 
			break ;;
		*)
			if [ $exact ]
			then
				stream="http://www.twitch.tv/$1"
			else
				get_stream "$1"
			fi

			if [ $save ]
			then
				if grep -q "^$entry " ~/.streamlist
				then
					sed -i "s|^$entry .*$|$entry $stream|" ~/.streamlist
					echo "Entry exists, updating"
				else
					echo "$entry $stream" >> ~/.streamlist
					echo "Adding entry: $entry $stream"
				fi
			fi

			if [ $noplayercache ]
			then
				livestreamer -p "$player" -v "$stream" ${quality:-best}
			else
				livestreamer -p "$player $cacheopts" -v "$stream" ${quality:-best}
			fi
			break ;;
	esac
done
