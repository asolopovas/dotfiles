#!/bin/sh
# xinitrc runs automatically when you run startx.

[ -f ~/.xprofile ] && . ~/.xprofile

exec xmonad
