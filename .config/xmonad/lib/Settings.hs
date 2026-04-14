module Settings where

import XMonad

myNormalBorderColor, myFocusedBorderColor :: String
myNormalBorderColor  = "#dddddd"
myFocusedBorderColor = "#fff323"

myTerminal, myBrowser, myFilebrowser :: String
myTerminal    = "alacritty"
myBrowser     = "$BROWSER"
myFilebrowser = "thunar"

myModMask :: KeyMask
myModMask = mod4Mask

myWorkspaces :: [String]
myWorkspaces = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]

myBorderWidth :: Dimension
myBorderWidth = 1

myFocusFollowsMouse :: Bool
myFocusFollowsMouse = False

myClickJustFocuses :: Bool
myClickJustFocuses = False
