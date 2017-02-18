#!/bin/bash -x


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
Start streamlight.sh in one of three GUI driven ways

Usage: 
   $PROGNAME [options]

Options:
   --help        Show this output
   --icon        Use via an icon in the taskbar
   --once        Use via the standard menu entry

Summary:
   When the option --icon is given, an icon will be created in the taskbar.
   A right click on this icon will use the video address highlighted at
   that time.  The icon will remain in the taskbar.
   
   When the option --once is given, the currently highlighted video address
   is used, then the application is closed.
   
   When no option is given you will be prompted to select a mode.
   
Configuration:
   None
   
Environment:
   The script works in a GUI (X) environment. 
   
Requires:
   streamlight.sh
   bash, yad

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

# Location of log file
LOG=$HOME/.streamlight.log



# ----------------------------------------------
# Ask whether run once mode or taskbar icon mode
# ----------------------------------------------

# When no mode has been requested
if [[ "$1" = "" ]]; then
   
   # Question and guidance to display
   MESSAGE="\nWhich one?                                                              \
              \n                                                                      \
              \n1. Place an icon in the taskbar                                       \
              \n    Use the highlighted video address at the time the icon is clicked \
              \n                                                                      \
              \n2. Run once                                                           \
              \n    Use the currently highlighted video address                       \
              \n                                                                      \
              \n"


   # Display options to obtain the desired mode of operation
   yad --center                                 \
       --width=550                              \
       --height=0                               \
       --buttons-layout=center                  \
       --button="Icon":0                        \
       --button="Run Once":3                    \
       --button="gtk-cancel":1                  \
       --title="$WINDOW_TITLE"                  \
       --image="$ICONS/questionmark_yellow.png" \
       --text="$MESSAGE"      

   # Capture which button was selected
   EXIT_STATUS=$?

   # Check whether user cancelled or closed the window and if so exit
   [[ "$EXIT_STATUS" = "1" ]] || [[ "$EXIT_STATUS" = "252" ]] && exit 1
 
   # Capture which action was requested by the button press
   ACTION=$EXIT_STATUS
   
   
   # Set the operational mode to match the requested action
   case $ACTION in
      0)  # Icon mode was selected
          MODE='--icon'
          ;;
      3)  # Run once mode was selected
          MODE='--once'
          ;;
      *)  # Otherwise
          exit 1        
          ;;
   esac
fi




# -------------
# Run once mode
# -------------

# When run once mode has been requested
if [[ "$1" = "--once" ]] || [[ "$MODE" = "--once" ]]; then

   # Pass control to the main script, simultaneously continue to the following command
   streamlight.sh &
   
   # Quit the script
   exit 0
fi 



# -----------------
# Taskbar icon mode
# -----------------

# When icon mode has been requested
if [[ "$1" = "--icon" ]] || [[ "$MODE" = "--icon" ]]; then
      
   # Guidance to display when hovering cursor over the icon in the taskbar
   TOOLTIP="Stream or download a video from a supported service"
   

   # Entries to display in the menu upon right click of the icon in the taskbar
   RIGHT_CLICK_MENU="Supported Services!streamlight.sh --plugins"

   RIGHT_CLICK_MENU="$RIGHT_CLICK_MENU|View Log!yad --center                     \
                                                    --width=750                  \
                                                    --height=350                 \
                                                    --buttons-layout=center      \
                                                    --button="gtk-cancel"        \
                                                    --title=$WINDOW_TITLE        \
                                                    --image=$ICONS/info_blue.png \
                                                    --text-info                  \
                                                    --margins=3                  \
                                                    --filename=$LOG"

   RIGHT_CLICK_MENU="$RIGHT_CLICK_MENU|Quit!quit"
       

   # Add an icon in the taskbar notification area
   yad --notification                              \
       --no-middle                                 \
       --image=$ICONS/streamlight-gui-launcher.png \
       --command="streamlight.sh"                  \
       --text="$TOOLTIP"                           \
       --menu="$RIGHT_CLICK_MENU"                  &


   # Quit the script
   exit 0
fi



# ---
# End
# ---

# Quit the script
exit 0
