import Control.Monad (when)
import Data.Maybe (fromMaybe)
import Data.Monoid (All (..))
import XMonad
import XMonad.Hooks.DynamicLog (dynamicLogWithPP)
import XMonad.Hooks.EwmhDesktops (ewmh, ewmhFullscreen)
import XMonad.Hooks.ManageDocks (docks)
import XMonad.Util.WindowProperties (getProp32)
import XMonad.Util.XUtils (fi)
import XMonad.Layout.IndependentScreens (countScreens)
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
import Safe (silentCatchX)
import qualified Startup

fullscreenBorderEventHook :: Dimension -> Event -> X All
fullscreenBorderEventHook bw ev = fullscreenBorderEventHook' bw ev `silentCatchX` pure (All True)

fullscreenBorderEventHook' :: Dimension -> Event -> X All
fullscreenBorderEventHook' bw (ClientMessageEvent _ _ _ _ win typ (action:dats)) = do
    managed <- isClient win
    wmstate <- getAtom "_NET_WM_STATE"
    fullsc <- getAtom "_NET_WM_STATE_FULLSCREEN"
    wstate <- fromMaybe [] <$> getProp32 wmstate win
    let isFull = fi fullsc `elem` wstate
        remove = 0
        add = 1
        toggle = 2
        enters = action == add || (action == toggle && not isFull)
        leaves = action == remove || (action == toggle && isFull)
    when (managed && typ == wmstate && fi fullsc `elem` dats) $ do
        when enters $ setFullscreenBorder 0 win
        when leaves $ setFullscreenBorder bw win
    pure (All True)
fullscreenBorderEventHook' _ _ = pure (All True)

setFullscreenBorder :: Dimension -> Window -> X ()
setFullscreenBorder bw w =
    withDisplay $ \d -> io $ setWindowBorderWidth d w bw

withScreensByWorkspace :: ScreenId -> [WorkspaceId] -> [WorkspaceId]
withScreensByWorkspace n tags =
    [show (fromIntegral s :: Int) ++ "_" ++ tag | tag <- tags, s <- [0 .. n - 1]]

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
            , workspaces         = withScreensByWorkspace nScreens (ucWorkspaces cfg)
            , normalBorderColor  = ucNormalColor cfg
            , focusedBorderColor = ucFocusedColor cfg
            , keys               = Keys.buildWorkspaceKeys
            , mouseBindings      = Mouse.mouseBindings
            , layoutHook         = Layouts.layoutHook
            , manageHook         = ManageRules.buildManageHook scratchpads
            , handleEventHook    = Events.handleEventHook <> fullscreenBorderEventHook (fromIntegral (ucBorderWidth cfg))
            , startupHook        = Startup.startupHook
            , logHook            = dynamicLogWithPP (LogHook.logPP dbus)
            }

    xmonad
        $ withLayoutAgnosticKeys
        $ baseConfig `additionalKeysP` Keys.buildKeys scratchpads (ucKeys cfg)
