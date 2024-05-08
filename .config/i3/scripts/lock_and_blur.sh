#!/usr/bin/env bash

# suspend message display: dunst
/usr/bin/pkill -u "$USER" -USR1 /usr/bin/dunst
/usr/bin/pkill -u "$USER" -USR1 /usr/bin/picom

## Lock the screen 
# set the icon and a temporary location for the screenshot to be stored
icon="$HOME/.config/i3/scripts/lock-icon-light.png"
tmpbg='/tmp/screen.png'

# take a screenshot
/usr/bin/scrot "$tmpbg"

# blur the screenshot by resizing and scaling back up
/usr/bin/convert "$tmpbg" -filter Gaussian -thumbnail 20% -sample 500% "$tmpbg"

# overlay the icon onto the screenshot
/usr/bin/convert "$tmpbg" "$icon" -gravity center -composite "$tmpbg"

# lock the screen with the blurred screenshot
# -n is required for not forking
/usr/bin/i3lock -ni "$tmpbg"

rm $tmpbg

# resume message display when unlocked
/usr/bin/pkill -u "$USER" -USR2 /usr/bin/dunst
/usr/bin/pkill -u "$USER" -USR2 /usr/bin/picom -cbCf

exit 0
