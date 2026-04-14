module Events (myHandleEventHook) where

import XMonad
import XMonad.Hooks.WindowSwallowing
import Data.Monoid (All(..))

-- Wrap swallowEventHook to suppress Enum.toEnum{Word8} and
-- getWindowAttributes errors from dead windows
winSwallowHook :: Event -> X All
winSwallowHook ev =
    swallowEventHook (className =? "Alacritty") (return True) ev
        `catchX` return (All True)

myHandleEventHook :: Event -> X All
myHandleEventHook = winSwallowHook
