#!/bin/sh

# API stream list seems to only support returning 100 at a time, and this seems sufficient for popular streams
twitch_limit=100
save=false
exact=false
nocache=false
noplayercache=false
debuglevel=0
configfile="$HOME/.lstreamrc"

# set defaults for config options in case they are omitted from config
player="mpv"
cacheopts="-cache 8192 -cache-min 4"
quality=best
streamlist="$HOME/.streamlist"

write_config () {
    echo '# configuration options
# player to use for streams. command line arguments may be included here
player="mpv"

# command line options which will (or will not) be passed to the player
# depending on whether or not -c was used
cacheopts="-cache 8192 -cache-min 4"

# default quality for streams. twitch currently provides the following qualities (case sensitive):
# High, Low, Medium, Source, mobile_high, mobile_low, mobile_medium
# best and worst are aliases for the best and worst qualities, usually mobile_high and mobile_low
# use the -l option for a current list for any given stream
quality=best

# location of the saved stream list
streamlist="$HOME/.streamlist"' > "$configfile"
}

print_help () {
    callname=`basename "$0"`
    echo "    Usage: 
    $callname [options] [function] <query>
    $callname [options] -s <query>

    Functions:
    These functions are exclusive and only one can be used per call. If multiple are
    specified, the script will exit after the first one is enountered and run. Any
    argument immediately following a function will be treated as the query.
    
        -d entry
          Delete stream saved under name \"entry\"

        -h
          Print this help

        -l
          List the available stream qualities for the selected stream

        -p
          Print the stream url which would normally be passed to livestreamer

    Options:

        -a
          Ignore saved streams and search for the query normally

        -c
          Run the player without the cache options specified in ~/.lstreamrc

        -e
          Will use the query as the exact stream name, i.e. twitch.tv/<query>

        -o player
          Player specification. Will use the following single argument as the player string

        -q quality
          Use the specified quality for the stream. (use -l for a list of available qualities)
        
        -s entry
          Save the stream url under the name supplied in the following argument.
          The query may be omitted when using this option, in which case \"entry\"
          will be used instead

        -v / -vv / -vvv
          Run with specified level of extra debug output"
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
    # print empty line if debug level is reached (or no debug level) but no debug message
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

# do the work of procuring stream url(s) given the query
find_stream () {
    twitch_results=0

    # search list of saved stream urls if nocache is not specified (by -a or -s)
    if ! $nocache
    then
        debug 1 "searching stream list for query"
        local cached
        # if a match is found, save as stream and return
        if cached=`grep "^$1|" "$streamlist"`
        then
            debug 1 "saved stream found"
            stream=`echo "$cached" | cut -d'|' -f2`
            return 0
        fi
        debug 1 "no saved streams found, searching twitch"
    fi

    debug 1 "query: $1"
    debug 1 "twitch limit: $twitch_limit"

    # fetch json stream list from REST API
    local twitch_raw=`curl -s https://api.twitch.tv/kraken/streams?limit=$twitch_limit`
    debug 2 "twitch raw fetched"
    #debug 3 "twitch raw:"
    #debug 3 "$twitch_raw"
    
    # parse json into list of stream names and descriptions
    local twitch_list=`echo "$twitch_raw" | jshon -e streams -a -e channel -e name -u -p -e status | paste -s -d '\t\n'`
    debug 2 "twitch raw parsed"
    debug 3 "twitch list:"
    debug 3 "$twitch_list"

    local twitch_matches
    # search parsed list for query with grep, adding line numbers to results, and process if any matches
    if twitch_matches=`echo "$twitch_list" | grep -in "$1"`
    then
        debug 2 "twitch matches:"
        debug 2 "$twitch_matches"
        twitch_results=`echo "$twitch_matches" | wc -l`

        # count beginning with 1 so array indices coincide with user choice entry
        local i=1
        # process each matching line found, putting the stream names and urls into arrays to present to user
        while read line
        do
            debug 2 "current processing line: $line"
            local index
            # take json element index from line numbers added by grep above, offset by 1
            let index=$(echo "$line" | cut -d: -f1)-1
            debug 2 "result index: $index"
            # fetch stream display name to present to user and stream url for matches
            twitch_names[$i]=`echo "$twitch_raw" | jshon -e streams -e $index -e channel -e display_name -u`
            twitch_urls[$i]=`echo "$twitch_raw" | jshon -e streams -e $index -e channel -e url -u`
            debug 1 "result $i name: ${twitch_names[$i]}"
            debug 1 "result $i url: ${twitch_urls[$i]}"
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
        debug 2 "one result found, saving as stream"
    fi

    debug 2 "exiting find_stream"
    return 0
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
    debug 2 "choice: $choice"
    # make sure choice is 1 or more digits, exit otherwise
    if [[ ! "$choice" =~ ^[0-9]+$ ]] 
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
    # if find stream returns success, one or more streams was found
    if find_stream "$1"
    then
        # if stream is not set yet, more than 1 result was found
        if [ -z "$stream" ]
        then
            print_results
        fi
    else
        echo "No results found"
        exit 1
    fi
}

if [ -e "$configfile" ]
then
    . "$configfile"
else
    write_config
fi

while getopts 'acd:eh:l:o:p:q:s:v' OPTION
do
    case "$OPTION" in
        # options
        a)
            nocache=true ;;
        c)
            noplayercache=true ;;
        e)
            exact=true ;;
        o)
            player="$OPTARG"
            noplayercache=true ;;
        q)
            quality="$OPTARG" ;;
        s)
            save=true
            nocache=true
            entry="$OPTARG" ;;
        v)
            let debuglevel++ ;;
        # functions
        d)
            if grep -q "^$OPTARG|.*" "$streamlist"
            then
                sed -i "/^$OPTARG|.*/d" "$streamlist"
                echo "Entry deleted"
                exit 0
            else
                echo "No entry \"$OPTARG\" found"
                exit 1
            fi ;;
        h)
            print_help 
            exit 0 ;;
        l)
            get_stream "$OPTARG"
            livestreamer "$stream"
            exit ;;
        p)
            get_stream "$OPTARG"
            echo "$stream"
            exit 0 ;;
        ?)
            print_help
            exit 2 ;;
    esac
done

debug 2 "options parsed"

shift $((OPTIND - 1))
# use the argument to -s in case query is omitted
if [ $# -lt 1 ]
then
    # if no more arguments and no entry to use as query, print help and exit 
    if [ -z "$entry" ]
    then
        print_help
        exit 1
    else
        query="$entry"
    fi
else
    query="$1"
fi

# handle query
if $exact
then
    stream="http://www.twitch.tv/$query"
else
    get_stream "$query"
fi

# add entry to stream list if -s is specified
if $save
then
    # check if entry exists and replace if so
    if grep -q "^$entry|" "$streamlist"
    then
        sed -i "s|^$entry\|.*$|$entry\|$stream|" "$streamlist"
        echo "Entry exists, updating"
    # add new entry otherwise
    else
        echo "$entry|$stream" >> "$streamlist"
        echo "Adding entry: $entry $stream"
    fi
fi

# append cache options if -c is not used
$noplayercache || player+=" $cacheopts"

livestreamer -p "$player" -v "$stream" "$quality"
