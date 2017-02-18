#!/bin/bash


# Capture the name of the script including file extension
PROGNAME=${0##*/}

# Set the version number
PROGVERSION=1.0



# --------------------
# Help and Information
# --------------------

# When requested show information about script
if [[ "$1" = '-h' ]] || [[ "$1" = '--help' ]]; then

# Display the following block
cat << end-of-messageblock

$PROGNAME version $PROGVERSION
Play or download videos from supported services.

Usage: 
   $PROGNAME [options]

Options:
   --help        Show this output
   --plugins     Show a list of loaded plugins of supported services

Summary:
   Video streams are handled via Livestreamer which automatically loads
   a plugin for each of the supported service providers.  The video can
   be saved to a file or directly played in MPV video player.
   
   In an external application, or command line, highlight the address of
   a video offered by a service provider.  The address might come from
   any application, for example:
   * Web browser
   * Email
   * Wordprocessor
   * PDF reader
   * Command line
   Any application in which the address can be highlighted is suitable.
   
   Start the script.  When prompted select one of the resolutions
   (on screen sizes) in which the video is available, then select whether
   to play the stream or download it.  The video is automatically played
   or saved using the chosen resolution.
   
Configuration:
   None
   
Environment:
   The script works in a GUI (X) environment. 
   
Requires:
   awk, bash, date, grep, livestreamer, mpv, tee, xclip, yad

See also:
   $livestreamer-gui-launcher.sh

end-of-messageblock
   exit 0
fi



# ---------------
# Static settings
# ---------------

# Title in the titlebar of YAD windows
WINDOW_TITLE="Streamlight"

# Location of icons
ICONS=/usr/share/pixmaps

# Name of the of this script excluding path and file extension
SCRIPT_NAME_EXC_EXTENSION=$(echo ${0%.*} | awk -F '/' '$0=$NF')

# Location of log file
LOG=$HOME/.$SCRIPT_NAME_EXC_EXTENSION.log



# -------------------------------
# Livestreamer supported services
# -------------------------------

# When show plugins mode has been requested
if [[ "$1" = "--plugins" ]]; then
      
   # Capture a list of the loaded livestreamer plugins
   LIVESTREAMER_PLUGINS=( $(livestreamer --plugins) )
   
   # Remove unwanted elements from the list 
   # Note: these are the first two words 'Loaded' and 'plugins:' used as the list header
   unset LIVESTREAMER_PLUGINS[0]
   unset LIVESTREAMER_PLUGINS[1]
   
   # Remove the trailing comma from each plugin name in the list
   LIVESTREAMER_PLUGINS=( "${LIVESTREAMER_PLUGINS[@]//,}" )
   
   
   # Guidance to display
   MESSAGE="\nLivestreamer plugins are loaded for these services \
            \n"

   # Display the list
   printf '%s\n' "${LIVESTREAMER_PLUGINS[@]}" \
   | yad --center                             \
         --width=300                          \
         --height=550                         \
         --buttons-layout="center"            \
         --button="gtk-cancel":1              \
         --title="$WINDOW_TITLE"              \
         --image="$ICONS/info_blue.png"       \
         --text-info                          \
         --margins=3                          \
         --text "$MESSAGE"

   # Quit the script
   exit 0
fi



# ----------------------------------
# Validate the highlighted selection
# ----------------------------------

# Capture the highligted address
VIDEO_ADDRESS=$(xclip -out)

# Capture the protocol type of the video address
PROTOCOL_TYPE=$(expr match "$VIDEO_ADDRESS" '^\(http\|https\)://')



# -------------------------------------------------------
# Handle missing video address or invalid stream protocol
# -------------------------------------------------------

if [[ -z $VIDEO_ADDRESS ]] || [[ -z $PROTOCOL_TYPE ]]; then

   # Message to display in error window
   ERROR_MESSAGE="\nA video address was not highlighted or uses an invalid protocol     \
                  \n                                                                    \
                  \nHighlighted:   $VIDEO_ADDRESS                                       \
                  \n                                                                    \
                  \nHighlight the full address of the video stream                      \
                  \nThe protocol used at the start of the address must be http or https \
                  \n                                                                    \
                  \nExiting..."

   # Display error message
      yad --center                        \
          --width=700                     \
          --height=0                      \
          --buttons-layout=center         \
          --button="gtk-cancel"           \
          --title="$WINDOW_TITLE"         \
          --image="$ICONS/cross_red.png"  \
          --text="$ERROR_MESSAGE"
 
   # Quit the script
   exit 1  
fi



# -----------------------
# Extract url information
# -----------------------

# Overwrite the log with a section header
echo "Attempting to obtain information about the video" > $LOG

# Query the url for information and append it to the log
URL_ANSWER=$(livestreamer $VIDEO_ADDRESS | tee --append $LOG)



# ------ ---------------------------
# Verify the address can be streamed
# ----------------------------------

# Capture any error messages returned by livestreamer when querying the url
ERROR_MESSAGE=$(echo "$URL_ANSWER" | grep --ignore-case '^error:')

# When a service is not supported by a plugin 
[[ -n $(echo "$ERROR_MESSAGE" | grep 'No plugin') ]]  && \
MESSAGE="No plugin can handle URL"

# When a stream is not present
[[ -n $(echo "$ERROR_MESSAGE" | grep 'No streams') ]] && \
MESSAGE="No streams found on URL"

# When any other error is reported
[[ -n $(echo "$ERROR_MESSAGE" | grep --invert-match --extended-regexp 'No plugin|No streams') ]] && \
MESSAGE="Livestreamer reported an error.  See log for details"


# When an error message is present
if [[ -n $ERROR_MESSAGE ]]; then

    # Prepend a blank line to the message
    MESSAGE="\n$MESSAGE"
    
    # Display the message
    yad --center                       \
        --width=500                    \
        --height=0                     \
        --buttons-layout=center        \
        --button="gtk-cancel"          \
        --title="$WINDOW_TITLE"        \
        --image="$ICONS/cross_red.png" \
        --text="$MESSAGE"                

   # Quit the script
   exit 1
fi



# ----------------------------------------
# Resolution in which to handle the stream
# ----------------------------------------

# Capture a list of the sizes in which the stream is available
STREAM_SIZES=( $(echo "$URL_ANSWER" | grep 'Available streams') )

# Remove unwanted elements from the list 
# Note: these are the first two words "Available" and "streams:" used as the list header
unset STREAM_SIZES[0]
unset STREAM_SIZES[1]

# Remove unwanted characters from the list
# Note: these are commas terminating each size, and brackets around the words best and worst
STREAM_SIZES=( ${STREAM_SIZES[@]//[,()]} )

# Remove unwanted strings from the list
# Note: these are permutations of "audio_anything" returned by youtube
STREAM_SIZES=( ${STREAM_SIZES[@]//audio_*} )

# Sort the list into ascending order, numerically at the head, alphabetically at the foot
STREAM_SIZES_SORTED=( $(for ELEMENT in ${STREAM_SIZES[@]}; do echo $ELEMENT; done | sort) )


# Question and guidance to display
MESSAGE="\nWhich One?                            \
         \nHighlight your selection and press OK \
         \n"


# Display the list of available sizes
while [[ "$RESOLUTION" = "" ]]
do
   RESOLUTION="$(yad --center                                  \
                     --width=100                               \
                     --height=450                              \
                     --buttons-layout=center                   \
                     --button=gtk-ok                           \
                     --button=gtk-cancel                       \
                     --title="$WINDOW_TITLE"                   \
                     --text="$MESSAGE"                         \
                     --image="$ICONS"/questionmark_yellow.png  \
                     --column="Available Resolution"           \
                     --no-click                                \
                     --separator=""                            \
                     --list "${STREAM_SIZES_SORTED[@]}"        \
                )"                

   # Capture which action was requested
   ACTION=$?

   # Check whether user cancelled or closed the window and if so exit
   [[ $ACTION = 1 ]] || [[ $ACTION = 252 ]] && exit 1
done



# ---------------------------
# Play or download the stream
# ---------------------------

# Question and guidance to display
MESSAGE="\nWhich one?                         \
           \n                                 \
           \n1. Play the stream               \
           \n                                 \
           \n2. Download the stream to a file \
           \n                                 \
           \n"


# Display options to obtain the desired action to perform
yad --center                                 \
    --width=0                                \
    --height=0                               \
    --timeout-indicator="bottom"             \
    --timeout="5"                            \
    --buttons-layout=center                  \
    --button="Play":0                        \
    --button="Download":3                    \
    --button="gtk-cancel":1                  \
    --title="$WINDOW_TITLE"                  \
    --image="$ICONS/questionmark_yellow.png" \
    --text="$MESSAGE"      

# Capture which button was selected
EXIT_STATUS=$?

# Check whether user cancelled or closed the window and if so exit
[[ $EXIT_STATUS = 1 ]] || [[ $EXIT_STATUS = 252 ]] && exit 1


# When play was selected by button press or timeout
if [[ $EXIT_STATUS = 0 ]] || [[ $EXIT_STATUS = 70 ]];then

   # Append a section header to the log
   echo "Attempting to play the video" >> $LOG

   # Play the stream
   livestreamer --player="mpv --really-quiet         \
                              --vo=xv,x11            \
                              --cache=auto           \
                              --cache-default=25000  \
                              --framedrop=vo"        \
                --player-no-close                    \
                $VIDEO_ADDRESS                       \
                $RESOLUTION                          \
   | tee --append $LOG

   # When download was selected by button press
   else
   
   # Capture the current date and time to use in the file name
   FILE_TIME=$(date +%F-%H-%M-%S)

   # Concatenate the identity, resolution, and time into a file name
   FILE=$XDG_DOWNLOAD_DIR/watch-$RESOLUTION-$FILE_TIME.mp4
   

   # Append a section header to the log
   echo "Attempting to download the video" >> $LOG
   

   # Guidance to display
    MESSAGE="\nSaving to file \
             \n$FILE          \
             \n"

    # Download the video, log the progress, and display the guidance message in a progress window
    livestreamer --output                \
                 $FILE                   \
                 $VIDEO_ADDRESS          \
                 $RESOLUTION             \
    | tee --append                       \
          $LOG                           \
    | yad --center                       \
          --width=700                    \
          --height=0                     \
          --buttons-layout=center        \
          --button="gtk-cancel"          \
          --title="$WINDOW_TITLE"        \
          --image="$ICONS/info_blue.png" \
          --text="$MESSAGE"              \
          --progress                     \
          --pulsate                      \
          --auto-close 
fi



# Quit the script
exit 0




