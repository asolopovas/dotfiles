module Mouse (myMouseBindings) where

import XMonad
import qualified XMonad.StackSet as W
import qualified Data.Map as M

myMouseBindings :: XConfig Layout -> M.Map (KeyMask, Button) (Window -> X ())
myMouseBindings XConfig {XMonad.modMask = modm} = M.fromList
    [
      -- mod-button1: float and move by dragging
      ((modm, button1), \w -> focus w >> mouseMoveWindow w
                                       >> windows W.shiftMaster),
      -- mod-button2: raise the window
      ((modm, button2), \w -> focus w >> windows W.shiftMaster),
      -- mod-button3: float and resize by dragging
      ((modm, button3), \w -> focus w >> mouseResizeWindow w
                                       >> windows W.shiftMaster)
    ]
