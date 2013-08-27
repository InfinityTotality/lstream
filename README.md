lstream
=======

A wrapper for livestreamer on twitch.tv. Supports pseudo searching by fetching the
names and descriptions of the top 100 streams on twitch and searching the full text.
Also supports saving streams under arbitrary names.


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
