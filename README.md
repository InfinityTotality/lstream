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

Functions
---------
These functions are exclusive and only one can be used per call. If multiple are
specified, the script will exit after the first one is enountered and run. Any
argument immediately following a function will be treated as the query.

-p  
  Print the stream url which would normally be passed to livestreamer.

-l  
  List the available stream qualities for the selected stream.

-h  
  Print this help.

Options
-------
-c  
  Run the player without the cache options specified in ~/.lstreamrc.

-q quality  
  Use the specified quality for the stream. (use -l for a list of available qualities)

-v / -vv / -vvv  
  Verbosity. Run with specified level of extra debug output.

-a  
  Ignore saved streams and search for the query normally.

-o player  
  Player specification. Will use the following single argument as the player string.

-e  
  Will use the query as the exact stream name, i.e. twitch.tv/\<query\>

-s entry  
  Save the stream url under the name supplied in the following argument.
  This option may be used immediately before the search query, in which case 
  the entry may be omitted, and the stream will be saved under the query instead.
