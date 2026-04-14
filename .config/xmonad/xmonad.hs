import XMonad
import XMonad.Hooks.EwmhDesktops (ewmh, ewmhFullscreen)
import XMonad.Hooks.ManageDocks (docks)
import XMonad.Hooks.DynamicLog (dynamicLogWithPP)
import XMonad.Util.EZConfig (additionalKeysP)
import XMonad.Layout.IndependentScreens (countScreens, withScreens)

import qualified DBus as D
import qualified DBus.Client as D

import Config         (UserConfig(..), loadConfigOrDefault)
import Keys           (buildKeys, buildWorkspaceKeys, parseModMask)
import Scratchpads    (buildScratchpads)
import Mouse          (myMouseBindings)
import Layouts        (myLayout)
import ManageRules    (buildManageHook)
import LogHook        (myLogHook)
import Events         (myHandleEventHook)
import Startup        (myStartupHook)

main :: IO ()
main = do
  cfg      <- loadConfigOrDefault
  nScreens <- countScreens
  dbus     <- D.connectSession
  D.requestName dbus (D.busName_ "org.xmonad.Log")
    [D.nameAllowReplacement, D.nameReplaceExisting, D.nameDoNotQueue]

  let scratchpads = buildScratchpads (ucScratchpads cfg)

  xmonad
    $ ewmhFullscreen
    $ ewmh
    $ docks
    $ def
        { terminal           = ucTerminal cfg
        , focusFollowsMouse  = ucFocusFollowsMouse cfg
        , clickJustFocuses   = ucClickJustFocuses cfg
        , borderWidth        = fromIntegral (ucBorderWidth cfg)
        , modMask            = parseModMask (ucModMask cfg)
        , workspaces         = withScreens nScreens (ucWorkspaces cfg)
        , normalBorderColor  = ucNormalColor cfg
        , focusedBorderColor = ucFocusedColor cfg

        , keys               = buildWorkspaceKeys
        , mouseBindings      = myMouseBindings

        , layoutHook         = myLayout
        , manageHook         = buildManageHook scratchpads
        , handleEventHook    = myHandleEventHook
        , startupHook        = myStartupHook
        , logHook            = dynamicLogWithPP (myLogHook dbus)
        }
    `additionalKeysP` buildKeys scratchpads (ucKeys cfg)
