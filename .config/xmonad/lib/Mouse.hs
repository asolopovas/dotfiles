module Mouse (mouseBindings) where

import qualified Data.Map as M
import XMonad hiding (mouseBindings)
import qualified XMonad.StackSet as W

mouseBindings :: XConfig Layout -> M.Map (KeyMask, Button) (Window -> X ())
mouseBindings XConfig {XMonad.modMask = modm} =
    M.fromList
        [ ((modm, button1), \w -> focus w >> mouseMoveWindow   w >> windows W.shiftMaster)
        , ((modm, button2), \w -> focus w >> windows W.shiftMaster)
        , ((modm, button3), \w -> focus w >> mouseResizeWindow w >> windows W.shiftMaster)
        ]
