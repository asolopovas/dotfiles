module Events (handleEventHook) where

import Data.Monoid (All (..))
import XMonad hiding (handleEventHook)
import XMonad.Hooks.WindowSwallowing (swallowEventHook)

handleEventHook :: Event -> X All
handleEventHook ev =
    swallowEventHook terminalWindow swallowableWindow ev
        `catchX` pure (All True)

terminalWindow :: Query Bool
terminalWindow = className =? "Alacritty"

swallowableWindow :: Query Bool
swallowableWindow = do
    cls <- className
    name <- appName
    pure (cls /= "Polybar" && cls /= "polybar" && name /= "polybar")
