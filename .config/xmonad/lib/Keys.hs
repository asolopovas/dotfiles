module Keys (myKeyb, myKeys) where

import XMonad
import qualified XMonad.StackSet as W
import qualified Data.Map as M
import System.Exit (exitSuccess)
import Graphics.X11.ExtraTypes.XF86

import XMonad.Actions.WithAll (killAll)
import XMonad.Actions.CopyWindow (kill1)
import XMonad.Actions.Promote (promote)
import XMonad.Util.NamedScratchpad (namedScratchpadAction)
import XMonad.Layout.ResizableTile (MirrorResize(..))
import XMonad.Layout.MultiToggle.Instances (StdTransformers(MIRROR))
import qualified XMonad.Layout.ToggleLayouts as T (ToggleLayout(Toggle))
import qualified XMonad.Layout.MultiToggle as MT (Toggle(..))
import XMonad.Layout.IndependentScreens (workspaces', onCurrentScreen)

import Settings
import Scratchpads (myScratchPads)
import Floats (toggleFloat)
import Layouts (resetLayout)
import Screens (Direction(..), cycleScreens, shiftAndFollowScreen)

myKeyb :: [(String, X ())]
myKeyb =
  [
    --Windows
    ("M-q",            kill1                           ),
    ("M-S-q",          killAll                         ),
    ("M-s",            windows W.focusMaster           ),
    ("M-j",            windows W.focusDown             ),
    ("M-k",            windows W.focusUp               ),
    ("M-S-j",          windows W.swapDown              ),
    ("M-S-k",          windows W.swapUp                ),
    ("M-<Backspace>",  promote                         ),
    ("M-f",            sendMessage (T.Toggle "full")   ),
    ("M-S-<Space>",    sendMessage (MT.Toggle MIRROR)  ),
    ("M-S-y",          sendMessage Expand              ),
    ("M-S-o",          sendMessage Shrink              ),
    ("M-S-u",          sendMessage MirrorExpand        ),
    ("M-S-i",          sendMessage MirrorShrink        ),
    ("M-S-0",          resetLayout                     ),
    --Applications
    ("M-<Return>",     spawn myTerminal               ),
    ("M-c",            namedScratchpadAction myScratchPads "brave"         ),
    ("M-0",            spawn "sysact"                 ),
    ("M-p",            spawn "fzf-menu fzf-thunar"    ),
    ("M-o",            spawn "fzf-menu fzf-code"      ),
    ("M-S-p",          spawn "fzf-menu fzf-alacritty" ),
    --Layouts
    ("M-.",           sendMessage (IncMasterN 1)      ),
    ("M-,",           sendMessage (IncMasterN (-1))   ),
    --Floating Windows
    ("M-<Delete>",     withFocused $ windows . W.sink ),
    ("M-t",            toggleFloat                    ),
    --Xmonad
    ("M-<F6>",         spawn "xmonad --recompile; xmonad --restart; notify-send 'Xmonad Recompiled'"),
    ("M-S-e",          io exitSuccess                                    ),
    --Scratchpads
    ("M-m",              namedScratchpadAction myScratchPads "aimp"           ),
    ("<F7>",             spawn "aimp-delete-track"                            ),
    ("<F6>",             namedScratchpadAction myScratchPads "thunderbird"   ),
    ("M-b"  ,            namedScratchpadAction myScratchPads "firefox"       ),
    ("M-x",              namedScratchpadAction myScratchPads "filebrowser"   ),
    ("M-S-x",            namedScratchpadAction myScratchPads "pcmanfmSearch" ),
    ("M-S-<Return>",     namedScratchpadAction myScratchPads "terminal"      ),
    ("<XF86Launch6>",    namedScratchpadAction myScratchPads "pavucontrol"   ),
    ("<F8>",             namedScratchpadAction myScratchPads "stacer"        ),
    ("<XF86Calculator>", namedScratchpadAction myScratchPads "calc"          ),

    --Help
    ("<F1>",             namedScratchpadAction myScratchPads "help"          ),

    --Media Keys
    ("<XF86AudioLowerVolume>",  spawn "lmc down"                             ),
    ("<XF86AudioRaiseVolume>",  spawn "lmc up"                               ),
    ("<XF86AudioMute>",         spawn "pamixer --toggle-mute"                ),
    ("<XF86AudioPlay>",         spawn "playerctl play-pause"                 ),
    ("<XF86MonBrightnessUp>",   spawn "brightnessctl set +5%"                ),
    ("<XF86MonBrightnessDown>", spawn "brightnessctl set 5%-"                ),
    ("<XF86AudioStop>",         spawn "playerctl stop"                       ),
    ("<XF86AudioPrev>",         spawn "playerctl previous"                   ),
    ("<XF86AudioNext>",         spawn "playerctl next"                       ),
    ("<Print>",                 spawn "flameshot gui"                        ),
    ("<XF86MenuPB>",            spawn "flameshot gui"                        )
  ]

myKeys :: XConfig Layout -> M.Map (KeyMask, KeySym) (X ())
myKeys conf@XConfig {XMonad.modMask = modm} = M.fromList $
    -- mod-[1..9] / mod-shift-[1..9], view / shift to workspace N
    [((m .|. modm, k), windows $ onCurrentScreen f i)
        | (i, k) <- zip (workspaces' conf) [xK_1 .. xK_9]
        , (f, m) <- [(W.view, 0), (W.shift, shiftMask)]]
    ++
    -- h/l: cycle through screens
    [((modm, xK_h), cycleScreens Prev)
    ,((modm, xK_l), cycleScreens Next)]
    ++
    -- M-S-h / M-S-l: shift and follow window to another screen
    [((modm .|. shiftMask, xK_h), shiftAndFollowScreen Prev)
    ,((modm .|. shiftMask, xK_l), shiftAndFollowScreen Next)]
