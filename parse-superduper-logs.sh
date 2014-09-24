#!/bin/zsh -f
# Purpose: Check SuperDuper!'s logs and send a push notification to show me what happened with them.
#
# NOTE: You WILL have to change a few settings to make this work for you. See comments below.
#
# From:	Tj Luo.ma
# Mail:	luomat at gmail dot com
# Web: 	http://RhymesWithDiploma.com
# Date:	2014-05-10

NAME="$0:t:r"

if ((! $+commands[po.sh] ))
then
		# note: if po.sh is a function or alias, it will come back not found
	echo "$NAME: po.sh is required but not found in $PATH"
	echo "	Get it from here https://github.com/tjluoma/po.sh"
	echo "	and configure it appropriately."

	exit 1
fi


zmodload zsh/datetime

	# this gives us a quick timestamp whenever we want and alternative to `date`
function timestamp { strftime "%Y-%m-%d--%H.%M.%S" "$EPOCHSECONDS" }

	# This is the time this script itself ran
TIME=$(strftime "%Y-%m-%d--%H.%M.%S" "$EPOCHSECONDS")

	# Get the short hostname of this computer
HOST=`hostname -s`

	# Lowercase it
HOST="$HOST:l"

	# This is where I store logs
	# You will almost certainly want to change the "Sites/logs.luo.ma"
	# part to something more meaningful to your setup
LOG="$HOME/Dropbox/Sites/logs.luo.ma/$HOST/$NAME/$TIME.txt"

	# This is an URL that I can click to view the whole log
	# if the push notification does not show it all.
	#
	# Again, you will need to change this to whatever fits your setup
URL_LOG="http://logs.luo.ma/$HOST/$NAME/$TIME.txt"

	# if the log dir does not exist, create it
[[ -d "$LOG:h" ]] || mkdir -p "$LOG:h"

	# if the log does not exist, create it
[[ -e "$LOG" ]]   || touch "$LOG"

	# This lets us easily output the same info the stdout as well as to a log file
function log { echo "$NAME [`timestamp`]: $@" | tee -a "$LOG" }

	# This is the same thing as `log` except that when we call this we want to stop the script
	# after we log the entry
function die
{
	log "$@"
	exit 1
}


find "$HOME/Library/Application Support/SuperDuper!" -iname \*.sdlog -print |\
while read line
do
	# This loop will repeat for each log found, which means that the first
	# time you run it, you will get a lot of results. You may want to
	# go to ~//Library/Application Support/SuperDuper!/ and clean out
	# some of the old logs first

		# initialize a variable
	PROBLEMS='no'

		# just the filename of the log without the dirname or extension
	SHORT="$line:t:r"

		# This is the plain text output we will use instead of the RTF log
		# SuperDuper creates by default
	TEXT=`echo "$LOG:h/$SHORT.txt" | tr ':' '.'`

	if [ ! -e "$TEXT" ]
	then

			# Convert the RTF log to plain text
		textutil -output "$TEXT" -format rtf -cat txt "$line" && \
			echo "$NAME: Created $TEXT"

			# When did the log start?
		START_TIME=`fgrep ' | Info | Started on' "$TEXT" | colrm 1 34`

			# When did the log end?
		END_TIME=`tail -1 "$TEXT" | colrm 1 2 | colrm 12`

			# Where there any errors or warnings?
		WARNINGS_OR_ERRORS=`fgrep -v '| Info |' "$TEXT"`

			# Check the variable we just created
		if [[ "$WARNINGS_OR_ERRORS" == "" ]]
		then
			WARNINGS_OR_ERRORS="No Errors or Warnings"
		else
			WARNINGS_OR_ERRORS=`echo "The following errors or warnings occurred:\n ${WARNINGS_OR_ERRORS}\n\n"`
			PROBLEMS='yes'
		fi

			# We look for the expected "all clear" message, and if we don't see it, we
			# assume something went wrong
		LAST_MESSAGE=`tail -1 "$TEXT" | colrm 1 23`

		[[ "$LAST_MESSAGE" != "Copy complete." ]] && PROBLEMS='yes'

			# Grab each 'PHASE' line from the text log
		PHASES=`fgrep 'PHASE: ' "$TEXT" | sed 's#^| ##g ; s# | Info##g' | sed G`

			# If there were problems, we send a different message than if not
		if [ "$PROBLEMS" = "yes" ]
		then
				# Send a push message that problems were encountered
			po.sh "SuperDuper encountered problems: see \"$TEXT\" for details"

				# Move the log file to the desktop so we can easily review it later
				# and so we won't parse it again
			mv "$line" "$HOME/Desktop/"
		else
				# If we get here, there were no problems found, as far as we can tell
			COPIED=`egrep 'Copied .*items totaling' "$TEXT" | sed 's#.*Copied#Copied#g' | tr -s ' '  ' '`

				# Send a push notification with a summary of the information from the log
			po.sh "SuperDuper: $WARNINGS_OR_ERRORS.\n\nStarted on $START_TIME and finished at $END_TIME.\n\n$PHASES\n\n$COPIED \n\nSee \"$URL_LOG\" for full log.\n"

				# Move the original log file to the trash
				# where it can be either retrieved later (if needed) or permanently deleted
			mv "$line" "$HOME/.Trash/"
		fi
	fi
done


exit
#
#EOF
