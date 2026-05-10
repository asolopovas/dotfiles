module Events (handleEventHook) where

import Data.Monoid (All (..))
import XMonad hiding (handleEventHook)
import XMonad.Hooks.WindowSwallowing (swallowEventHook)

handleEventHook :: Event -> X All
handleEventHook ev =
    swallowEventHook (className =? "Alacritty") (pure True) ev
        `catchX` pure (All True)
