module Startup (startupHook) where

import XMonad hiding (startupHook)
import XMonad.Util.SpawnOnce (spawnOnce)

startupHook :: X ()
startupHook = do
    spawn "setxkbmap -layout us,ru -option grp:win_space_toggle -option terminate:ctrl_alt_bksp -option grp_led:scroll"
    spawnOnce "dotfiles/autostart.sh &"
