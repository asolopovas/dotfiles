module Startup (startupHook) where

import XMonad hiding (startupHook)
import XMonad.Util.SpawnOnce (spawnOnce)

startupHook :: X ()
startupHook = spawnOnce "dotfiles/autostart.sh &"
