import XMonad
import XMonad.Hooks.DynamicLog (dynamicLogWithPP)
import XMonad.Hooks.EwmhDesktops (ewmh, ewmhFullscreen)
import XMonad.Hooks.ManageDocks (docks)
import XMonad.Layout.IndependentScreens (countScreens, withScreens)
import XMonad.Util.EZConfig (additionalKeysP)

import qualified DBus as D
import qualified DBus.Client as D

import Config (UserConfig (..), loadConfigOrDefault)
import qualified Events
import qualified Keys
import qualified Layouts
import LayoutAgnostic (withLayoutAgnosticKeys)
import qualified LogHook
import qualified ManageRules
import qualified Mouse
import qualified Scratchpads
import qualified Startup

main :: IO ()
main = do
    cfg <- loadConfigOrDefault
    nScreens <- countScreens
    dbus <- D.connectSession
    _ <-
        D.requestName
            dbus
            (D.busName_ "org.xmonad.Log")
            [D.nameAllowReplacement, D.nameReplaceExisting, D.nameDoNotQueue]

    let scratchpads = Scratchpads.buildScratchpads (ucScratchpads cfg)

    let baseConfig = ewmhFullscreen
            $ ewmh
            $ docks
            $ def
            { terminal           = ucTerminal cfg
            , focusFollowsMouse  = ucFocusFollowsMouse cfg
            , clickJustFocuses   = ucClickJustFocuses cfg
            , borderWidth        = fromIntegral (ucBorderWidth cfg)
            , modMask            = Keys.parseModMask (ucModMask cfg)
            , workspaces         = withScreens nScreens (ucWorkspaces cfg)
            , normalBorderColor  = ucNormalColor cfg
            , focusedBorderColor = ucFocusedColor cfg
            , keys               = Keys.buildWorkspaceKeys
            , mouseBindings      = Mouse.mouseBindings
            , layoutHook         = Layouts.layoutHook
            , manageHook         = ManageRules.buildManageHook scratchpads
            , handleEventHook    = Events.handleEventHook
            , startupHook        = Startup.startupHook
            , logHook            = dynamicLogWithPP (LogHook.logPP dbus)
            }

    xmonad
        $ withLayoutAgnosticKeys
        $ baseConfig `additionalKeysP` Keys.buildKeys scratchpads (ucKeys cfg)
