module Actions (actionFromString) where

import XMonad
import qualified XMonad.StackSet as W
import System.Exit (exitSuccess)

import XMonad.Actions.WithAll (killAll)
import XMonad.Actions.CopyWindow (kill1)
import XMonad.Actions.Promote (promote)
import XMonad.Util.NamedScratchpad (namedScratchpadAction, NamedScratchpad)
import XMonad.Layout.ResizableTile (MirrorResize(..))
import XMonad.Layout.MultiToggle.Instances (StdTransformers(MIRROR))
import qualified XMonad.Layout.ToggleLayouts as T (ToggleLayout(Toggle))
import qualified XMonad.Layout.MultiToggle as MT (Toggle(..))

import Floats (toggleFloat)
import Layouts (resetLayout)
import Screens (Direction(..), cycleScreens, shiftAndFollowScreen)

-- Translate a string action from config.json into an X () action.
-- Unrecognized strings become no-ops (with a spawn-warning fallback).
actionFromString :: [NamedScratchpad] -> String -> X ()
actionFromString scratchpads raw =
    case break (== ':') raw of
        ("spawn",      ':':cmd)  -> spawn cmd
        ("exec",       ':':cmd)  -> spawn cmd
        ("scratchpad", ':':name) -> namedScratchpadAction scratchpads name
        ("workspace-view",  ':':ws) -> windows (W.view ws)
        ("workspace-shift", ':':ws) -> windows (W.shift ws)
        ("workspace-greedy",':':ws) -> windows (W.greedyView ws)
        (name, "")               -> namedAction name
        (name, _)                -> namedAction name
  where
    namedAction n = case n of
        "kill"                  -> kill1
        "kill-all"              -> killAll
        "focus-master"          -> windows W.focusMaster
        "focus-down"            -> windows W.focusDown
        "focus-up"              -> windows W.focusUp
        "swap-down"             -> windows W.swapDown
        "swap-up"               -> windows W.swapUp
        "promote"               -> promote
        "toggle-full"           -> sendMessage (T.Toggle "full")
        "toggle-mirror"         -> sendMessage (MT.Toggle MIRROR)
        "expand"                -> sendMessage Expand
        "shrink"                -> sendMessage Shrink
        "mirror-expand"         -> sendMessage MirrorExpand
        "mirror-shrink"         -> sendMessage MirrorShrink
        "reset-layout"          -> resetLayout
        "increment-master"      -> sendMessage (IncMasterN 1)
        "decrement-master"      -> sendMessage (IncMasterN (-1))
        "sink"                  -> withFocused (windows . W.sink)
        "toggle-float"          -> toggleFloat
        "cycle-screen-prev"     -> cycleScreens Prev
        "cycle-screen-next"     -> cycleScreens Next
        "shift-screen-prev"     -> shiftAndFollowScreen Prev
        "shift-screen-next"     -> shiftAndFollowScreen Next
        "exit"                  -> io exitSuccess
        "restart"               -> spawn "xmonad --restart"
        "recompile"             -> spawn "xmonad --recompile && xmonad --restart && notify-send 'Xmonad Recompiled'"
        "reload-config"         -> spawn "xmonad --restart && notify-send 'Xmonad config reloaded'"
        "edit-config"           -> spawn "alacritty -e $(command -v ${EDITOR:-nvim} || echo vi) $HOME/.config/xmonad/config.json"
        "window-rules-menu"     -> spawn "xmonad-window-rules"
        other                   -> spawn ("notify-send 'xmonad: unknown action' " ++ shellQuote other)
    shellQuote s = "'" ++ concatMap esc s ++ "'"
    esc '\'' = "'\\''"
    esc c    = [c]
