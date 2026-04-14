module Startup (myStartupHook) where

import XMonad
import XMonad.Util.SpawnOnce

import Screens (fixWorkspaceAssignment)

myStartupHook :: X ()
myStartupHook = do
    fixWorkspaceAssignment
    spawnOnce "dotfiles/autostart.sh &"
