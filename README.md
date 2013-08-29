lstream
=======

A twitch.tv wrapper for livestreamer written in bash. Supports searching the
names and descriptions of the top 100 streams on twitch as well as saving streams
under arbitrary names. Automatically selects best quality if none is specified.
Will play via mpv by default if -o is not used. A custom player and cache setting
and default quality may be specified in ~/.lstreamrc.

Depends on:  
- livestreamer
- jshon
- curl
- sed
- grep
- cut
- paste

Usage
-----
lstream.sh [options] [function] \<query\>
lstream.sh [options] -s \<query\>

Functions
---------
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

Options
-------
-a
Ignore saved streams and search for the query normally

-c
Run the player without the cache options specified in ~/.lstreamrc

-e
Will use the query as the exact stream name, i.e. twitch.tv/<query>

-o player
Player specification. Will use the following single argument as the player string.

-q quality
Use the specified quality for the stream. (use -l for a list of available qualities)

-s entry
Save the stream url under the name supplied in the following argument.
The query may be omitted when using this option, in which case \"entry\"
will be used instead

-v / -vv / -vvv
Run with specified level of extra debug output
