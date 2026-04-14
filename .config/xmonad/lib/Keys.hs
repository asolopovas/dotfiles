module Keys (buildKeys, buildWorkspaceKeys, parseModMask) where

import XMonad
import qualified XMonad.StackSet as W
import qualified Data.Map as M
import XMonad.Util.NamedScratchpad (NamedScratchpad)
import XMonad.Layout.IndependentScreens (workspaces', onCurrentScreen)

import Actions (actionFromString)
import Screens (Direction(..), cycleScreens, shiftAndFollowScreen)

parseModMask :: String -> KeyMask
parseModMask "mod1"  = mod1Mask
parseModMask "mod2"  = mod2Mask
parseModMask "mod3"  = mod3Mask
parseModMask "mod4"  = mod4Mask
parseModMask "mod5"  = mod5Mask
parseModMask "alt"   = mod1Mask
parseModMask "super" = mod4Mask
parseModMask _       = mod4Mask

-- User keybindings from config.json, to be merged with `additionalKeysP`.
buildKeys :: [NamedScratchpad] -> M.Map String String -> [(String, X ())]
buildKeys scratchpads raw =
    [ (k, actionFromString scratchpads v) | (k, v) <- M.toList raw ]

-- Workspace navigation keys (mod-[1..9] view, mod-shift-[1..9] shift) and
-- screen navigation (mod-h/l, mod-S-h/l). Built directly against the
-- XConfig so screen awareness is correct.
buildWorkspaceKeys :: XConfig Layout -> M.Map (KeyMask, KeySym) (X ())
buildWorkspaceKeys conf@XConfig {XMonad.modMask = modm} = M.fromList $
    [((m .|. modm, k), windows $ onCurrentScreen f i)
        | (i, k) <- zip (workspaces' conf) [xK_1 .. xK_9]
        , (f, m) <- [(W.view, 0), (W.shift, shiftMask)]]
    ++
    [ ((modm, xK_h),                cycleScreens Prev)
    , ((modm, xK_l),                cycleScreens Next)
    , ((modm .|. shiftMask, xK_h),  shiftAndFollowScreen Prev)
    , ((modm .|. shiftMask, xK_l),  shiftAndFollowScreen Next)
    ]
