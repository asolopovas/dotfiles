import XMonad
import XMonad.Hooks.EwmhDesktops (ewmh, ewmhFullscreen)
import XMonad.Hooks.ManageDocks (docks)
import XMonad.Hooks.DynamicLog (dynamicLogWithPP)
import XMonad.Util.EZConfig (additionalKeysP)
import XMonad.Layout.IndependentScreens (countScreens, withScreens)

import qualified DBus as D
import qualified DBus.Client as D

import Settings
import Keys (myKeyb, myKeys)
import Mouse (myMouseBindings)
import Layouts (myLayout)
import ManageRules (myManageHook)
import LogHook (myLogHook)
import Events (myHandleEventHook)
import Startup (myStartupHook)

main :: IO ()
main = do
  nScreens <- countScreens
  dbus     <- D.connectSession
  D.requestName dbus (D.busName_ "org.xmonad.Log")
    [D.nameAllowReplacement, D.nameReplaceExisting, D.nameDoNotQueue]

  xmonad
    $ ewmhFullscreen
    $ ewmh
    $ docks
    $ def {
        terminal           = myTerminal,
        focusFollowsMouse  = myFocusFollowsMouse,
        clickJustFocuses   = myClickJustFocuses,
        borderWidth        = myBorderWidth,
        modMask            = myModMask,
        workspaces         = withScreens nScreens myWorkspaces,
        normalBorderColor  = myNormalBorderColor,
        focusedBorderColor = myFocusedBorderColor,

        keys               = myKeys,
        mouseBindings      = myMouseBindings,

        layoutHook         = myLayout,
        manageHook         = myManageHook,
        handleEventHook    = myHandleEventHook,
        startupHook        = myStartupHook,
        logHook            = dynamicLogWithPP (myLogHook dbus)
    }
    `additionalKeysP` myKeyb
