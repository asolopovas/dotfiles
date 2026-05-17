module Actions (actionFromString) where

import System.Exit (exitSuccess)
import XMonad
import qualified XMonad.StackSet as W

import Data.Char (toLower)
import XMonad.Actions.Promote (promote)
import XMonad.Actions.WithAll (killAll)
import XMonad.Layout.MultiToggle.Instances (StdTransformers (MIRROR))
import qualified XMonad.Layout.MultiToggle as MT
import XMonad.Layout.ResizableTile (MirrorResize (..))
import qualified XMonad.Layout.ToggleLayouts as T
import XMonad.Util.NamedScratchpad (NamedScratchpad, namedScratchpadAction)

import BrowserToggle (autoRevealBrowserHook, toggleActiveBrowser)
import Floats (cycleFloatSize, toggleFloat)
import Layouts (resetLayout)
import Screens (Direction (..), cycleScreens, shiftAndFollowScreen)
import Util (shellQuote)

actionFromString :: [NamedScratchpad] -> String -> X ()
actionFromString scratchpads raw = case break (== ':') raw of
    ("spawn",            ':' : cmd) -> spawn cmd
    ("exec",             ':' : cmd) -> spawn cmd
    ("scratchpad",       ':' : n)   -> namedScratchpadAction scratchpads n
    ("workspace-view",   ':' : ws)  -> windows (W.view ws)
    ("workspace-shift",  ':' : ws)  -> windows (W.shift ws)
    ("workspace-greedy", ':' : ws)  -> windows (W.greedyView ws)
    (n, _)                          -> namedAction n
  where
    namedAction n = case n of
        "kill"              -> safeKill
        "kill-all"          -> safeKillAll
        "focus-master"      -> windows W.focusMaster >> autoRevealBrowserHook
        "focus-down"        -> windows W.focusDown   >> autoRevealBrowserHook
        "focus-up"          -> windows W.focusUp     >> autoRevealBrowserHook
        "swap-down"         -> windows W.swapDown
        "swap-up"           -> windows W.swapUp
        "promote"           -> promote
        "toggle-full"       -> sendMessage (T.Toggle "full")
        "toggle-mirror"     -> sendMessage (MT.Toggle MIRROR)
        "expand"            -> sendMessage Expand
        "shrink"            -> sendMessage Shrink
        "mirror-expand"     -> sendMessage MirrorExpand
        "mirror-shrink"     -> sendMessage MirrorShrink
        "reset-layout"      -> resetLayout
        "increment-master"  -> sendMessage (IncMasterN 1)
        "decrement-master"  -> sendMessage (IncMasterN (-1))
        "sink"              -> withFocused (windows . W.sink)
        "toggle-float"      -> toggleFloat
        "float-size-up"     -> cycleFloatSize scratchpads 1
        "float-size-down"   -> cycleFloatSize scratchpads (-1)
        "cycle-screen-prev" -> cycleScreens Prev
        "cycle-screen-next" -> cycleScreens Next
        "shift-screen-prev" -> shiftAndFollowScreen Prev
        "shift-screen-next" -> shiftAndFollowScreen Next
        "toggle-browser"    -> toggleActiveBrowser
        "exit"              -> io exitSuccess
        "restart"           -> spawn "xmonad --restart"
        "recompile"         -> spawn "xmonad --recompile && xmonad --restart && notify-send 'Xmonad Recompiled'"
        "reload-config"     -> spawn "xmonad --restart && notify-send 'Xmonad config reloaded'"
        "edit-config"       -> spawn "alacritty -e $(command -v ${EDITOR:-nvim} || echo vi) $HOME/.config/xmonad/config.json"
        "window-rules-menu" -> spawn "fzf-menu xmonad-window-rules"
        other               -> spawn ("notify-send 'xmonad: unknown action' " ++ shellQuote other)

    isProtected w = do
        cls <- runQuery className w
        return (map toLower cls `elem` protectedClasses)

    protectedClasses = ["rustdesk"]

    safeKill = withFocused $ \w -> do
        prot <- isProtected w
        if prot
            then spawn "notify-send 'xmonad' 'kill blocked: protected window (RustDesk)'"
            else kill

    safeKillAll = do
        ws <- gets (W.integrate' . W.stack . W.workspace . W.current . windowset)
        prot <- mapM isProtected ws
        if or prot
            then spawn "notify-send 'xmonad' 'kill-all blocked: protected window (RustDesk) on workspace'"
            else killAll
