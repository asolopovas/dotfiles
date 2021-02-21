-------------------------------------------
-- Imports
-------------------------------------------
import XMonad
import XMonad.ManageHook
import XMonad.Config.Desktop

-- Actions
import XMonad.Actions.WithAll (sinkAll, killAll)
import XMonad.Actions.CopyWindow (kill1, killAllOtherCopies)
import XMonad.Actions.WindowGo (runOrRaise)
import XMonad.Actions.Promote

-- Util
import XMonad.Util.Run
import XMonad.Util.SpawnOnce
import XMonad.Util.NamedScratchpad
import XMonad.Util.EZConfig (additionalKeysP)
import XMonad.Util.NoTaskbar

-- Layouts
import XMonad.Layout.ResizableTile
import XMonad.Layout.Magnifier
import XMonad.Layout.Reflect
import XMonad.Layout.IndependentScreens

-- Layout Modifiers
import XMonad.Layout.PerWorkspace
import XMonad.Layout.Spacing
import XMonad.Layout.LayoutModifier
import XMonad.Layout.NoBorders (noBorders, smartBorders)
import XMonad.Layout.LimitWindows (limitWindows)
import XMonad.Layout.Renamed (renamed, Rename(Replace))
import XMonad.Layout.MultiToggle (mkToggle, single, EOT(EOT), (??))
import XMonad.Layout.MultiToggle.Instances (StdTransformers(NBFULL, MIRROR, NOBORDERS))
import qualified XMonad.Layout.ToggleLayouts as T (toggleLayouts, ToggleLayout(Toggle))
import qualified XMonad.Layout.MultiToggle as MT (Toggle(..))

-- Hooks
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.EwmhDesktops ( fullscreenEventHook)
import XMonad.Hooks.ManageDocks (manageDocks, docks, avoidStruts)
import XMonad.Hooks.ManageHelpers (isFullscreen, doFullFloat, doCenterFloat)
import XMonad.Hooks.DynamicProperty ( dynamicPropertyChange )

import Data.Monoid
import System.Exit

import qualified DBus as D
import qualified DBus.Client as D
import qualified XMonad.Layout.BoringWindows as B
import qualified Codec.Binary.UTF8.String as UTF8

import qualified XMonad.StackSet as W
import qualified Data.Map        as M

-------------------------------------------
-- Colours
-------------------------------------------
red       = "#fb4934"
blue      = "#83a598"
blue2     = "#2266d0"

-------------------------------------------
-- Globals
-------------------------------------------
myTerminal      = "alacritty"
myBrowser       = "google-chrome-stable"

-- Whether focus follows the mouse pointer.
myFocusFollowsMouse :: Bool
myFocusFollowsMouse = False

-- Whether clicking on a window to focus also passes the click to the window
myClickJustFocuses :: Bool
myClickJustFocuses = False

myModMask       = mod4Mask

-- A tagging example:
-- > workspaces = ["web", "irc", "code" ] ++ map show [4..9]
myWorkspaces    = ["1","2","3","4","5","6","7","8","9"]

myBorderWidth   = 2
myNormalBorderColor  = "#dddddd"
myFocusedBorderColor = "#fff323"

--------------------------------------------
-- Workspaces Binding
--------------------------------------------
myKeys conf@(XConfig {XMonad.modMask = modm}) = M.fromList $
    -- mod-[1..9], Switch to workspace N
    -- mod-shift-[1..9], Move client to workspace N
    [((m .|. modm, k), windows $ onCurrentScreen f i)
        | (i, k) <- zip (workspaces' conf) [xK_1 .. xK_9]
        , (f, m) <- [(W.view, 0), (W.shift, shiftMask)]]
    ++

    -- mod-{h,j}, Switch to physical/Xinerama screens 1, 2, or 3
    -- mod-shift-{h,j}, Move client to screen 1, 2, or 3
    [((m .|. modm, key), screenWorkspace sc >>= flip whenJust (windows . f))
        | (key, sc) <- zip [xK_h, xK_l] [0..]
        , (f, m) <- [(W.view, 0), (shiftAndView, shiftMask)]]

-------------------------------------------
-- Floating functions
-------------------------------------------
centerRect = W.RationalRect 0.25 0.25 0.5 0.5

-- If the window is floating then (f), if tiled then (n)
floatOrNot f n = withFocused $ \windowId -> do
    floats <- gets (W.floating . windowset)
    if windowId `M.member` floats -- if the current window is floating...
       then f
       else n

-- Center and float a window (retain size)
centerFloat win = do
    (_, W.RationalRect x y w h) <- floatLocation win
    windows $ W.float win (W.RationalRect ((1 - w) / 1.5) ((1 - h) / 1.5) w h)
    return ()

-- Float a window in the center
centerFloat' w = windows $ W.float w centerRect

-- Make a window my 'standard size' (half of the screen) keeping the center of the window fixed
standardSize win = do
    (_, W.RationalRect x y w h) <- floatLocation win
    windows $ W.float win (W.RationalRect x y 0.5 0.5)
    return ()

-- Float and center a tiled window, sink a floating window
toggleFloat = floatOrNot (withFocused $ windows . W.sink) (withFocused centerFloat')

-------------------------------------------
-- Keybinding
-------------------------------------------

myKeyb :: [(String, X ())]
myKeyb =
  [
    --Windows
    ("M-q",           kill1                           ), -- Kill focused window
    ("M-S-q",         killAll                         ), -- Kill all workspace windows
    ("M-s",           windows W.focusMaster           ), -- Move focus to the master window
    ("M-j",           windows W.focusDown             ), -- Move focus to the next window
    ("M-k",           windows W.focusUp               ), -- Move focus to the prev window
    ("M-S-j",         windows W.swapDown              ), -- Swap focused window with next window
    ("M-S-k",         windows W.swapUp                ), -- Swap focused window with prev window
    ("M-<Backspace>", promote                         ), -- Moves focused window to master
    ("M-f",           sendMessage (T.Toggle "full")   ), -- Toggle layout full layout
    ("M1-<Space>",    sendMessage NextLayout          ), -- Toggle layout full layout
    ("M1-y",          sendMessage Shrink              ), -- Expand Layout
    ("M1-o",          sendMessage Expand              ), -- Shrink Layout
    ("M1-u",          sendMessage MirrorShrink        ), -- Vertical Shrink Layout
    ("M1-i",          sendMessage MirrorExpand        ), -- Vertical Expand Layout

    --Applications
    ("M-<Return>",     spawn myTerminal               ),
    ("M-b",            spawn myBrowser                ),
    ("M-d",            spawn "rofi -show run"         ),
    ("M-S-d",          spawn "su_dmenu_run"           ),
    ("M-0",            spawn "sysact"                 ),
    ("M-p",            spawn "fzfmenu storm"          ),
    ("M-S-p",          spawn "fzfmenu fzfst"          ),
    ("M-o",            spawn "fzfmenu vscode"         ),

    --Layouts
    ("M-.",           sendMessage (IncMasterN 1)      ), -- Increase number of clients in master pane
    ("M-,",           sendMessage (IncMasterN (-1))   ), -- Decrease number of clients in master pane

    --Floating Windows
    ("M-<Delete>",     withFocused $ windows . W.sink ), -- Push floating window back to tile
    ("M-t",            toggleFloat                    ),

    --Xmonad
    ("M-r",           spawn "xmonad --recompile; xmonad --restart"      ), -- Restarts xmonad
    ("M-S-e",         io exitSuccess                                    ), -- Quits xmonad

    --Scratchpads
    ("M-S-<Return>",  namedScratchpadAction myScratchPads "terminal"    ),
    ("M-m",           namedScratchpadAction myScratchPads "spotify"     ),
    ("M-<F11>",       namedScratchpadAction myScratchPads "teamviewer"  ),
    ("M-x",           namedScratchpadAction myScratchPads "thunar"      ),
    ("M-v",           namedScratchpadAction myScratchPads "pavucontrol" ),
    ("<XF86Launch9>", namedScratchpadAction myScratchPads "stacer"      ),

    --Media Keys
    ("<XF86AudioLowerVolume>", spawn "lmc down; kill -44 $(pidof dwmblocks)"            ),
    ("<XF86AudioRaiseVolume>", spawn "lmc up; kill -44 $(pidof dwmblocks)"              ),
    ("<XF86AudioMute>",        spawn "lmc mute; kill -44 $(pidof dwmblocks)"            ),  -- Bug prevents it from toggling correctly in 12.04.
    ("<XF86AudioPlay>",        spawn "playerctl play-pause"                             ),
    ("<XF86AudioStop>",        spawn "playerctl stop"                                   ),
    ("<XF86AudioPrev>",        spawn "playerctl prev"                                   ),
    ("<XF86AudioNext>",        spawn "playerctl next"                                   ), 
    ("<XF86Launch7>",          runOrRaise "qalculate-gtk" (resource =? "qalculate-gtk") ),
    ("<XF86Launch8>",          spawn "flameshot gui"                                    )

  ]


shiftAndView i = W.view i . W.shift i

--------------------------------------------
-- Mouse bindings
--------------------------------------------
myMouseBindings (XConfig {XMonad.modMask = modm}) = M.fromList $
    [
      -- mod-button1, Set the window to floating mode and move by dragging
      ((modm, button1), (\w -> focus w >> mouseMoveWindow w
                                       >> windows W.shiftMaster)),
      -- mod-button2, Raise the window to the top of the stack
      ((modm, button2), (\w -> focus w >> windows W.shiftMaster)),
       -- mod-button3, Set the window to floating mode and resize by dragging
      ((modm, button3), (\w -> focus w >> mouseResizeWindow w
                                       >> windows W.shiftMaster))
      -- you may also bind events to the mouse scroll wheel (button4 and button5)
    ]

--------------------------------------------
-- LogHook
--------------------------------------------
myLogHook :: D.Client -> PP
myLogHook dbus = def
    {
      ppOutput  = dbusOutput dbus,
      ppCurrent = wrap ("%{F" ++ blue2 ++ "} ") " %{F-}",
      ppVisible = wrap ("%{F" ++ blue ++ "} ") " %{F-}",
      ppUrgent  = wrap ("%{F" ++ red ++ "} ") " %{F-}",
      ppHidden  = wrap " " " ",
      ppWsSep   = "",
      ppSep     = " | ",
      ppTitle   = myAddSpaces 25
    }

-- Emit a DBus signal on log updates
dbusOutput :: D.Client -> String -> IO ()
dbusOutput dbus str = do
    let signal = (D.signal objectPath interfaceName memberName) {
            D.signalBody = [D.toVariant $ UTF8.decodeString str]
        }
    D.emit dbus signal
  where
    objectPath = D.objectPath_ "/org/xmonad/Log"
    interfaceName = D.interfaceName_ "org.xmonad.Log"
    memberName = D.memberName_ "Update"

myAddSpaces :: Int -> String -> String
myAddSpaces len str = sstr ++ replicate (len - length sstr) ' '
  where
    sstr = shorten len str

-------------------------------------------
-- Scratchpads
-------------------------------------------
myScratchPads =
  [
    NS "terminal"      spawnTerm          (title     =? "scratchpad")    mediumFloat,
    NS "spotify"       "spotify"          (className =? "Spotify")       largeFloat,
    NS "teamviewer"    "teamviewer"       (className =? "TeamViewer")    defaultFloating,
    NS "thunar"        "thunar"           (className =? "Thunar")        defaultFloating,
    NS "pavucontrol"   "pavucontrol"      (className =? "Pavucontrol")   mediumFloat,
    NS "stacer"        "sudo -A stacer"   (className =? "stacer")        mediumFloat
  ]

  where
    spawnTerm      = myTerminal ++ " -t scratchpad"
    smallFloat    = customFloating $ W.RationalRect l t w h
                     where
                       h = 0.5
                       w = 0.5
                       t = 0.7 -h
                       l = 0.7 -w

    mediumFloat    = customFloating $ W.RationalRect l t w h
                     where
                       h = 0.6
                       w = 0.6
                       t = 0.8 -h
                       l = 0.8 -w
    largeFloat     = customFloating $ W.RationalRect l t w h
                     where
                       h = 0.9
                       w = 0.9
                       t = 0.95 -h
                       l = 0.95 -w

--------------------------------------------
-- Layouts
--------------------------------------------
mySpacing :: Integer -> l a -> XMonad.Layout.LayoutModifier.ModifiedLayout Spacing l a
mySpacing i = spacingRaw False (Border i i i i) True (Border i i i i) True


tiled   =    renamed [Replace "tiled"]
           $ smartBorders
           $ limitWindows 12
           $ mySpacing 5
           $ ResizableTall 1 (3/100) (1/2) []
tiledR  =   renamed [Replace "tiledR"]
           $ smartBorders
           $ limitWindows 12
           $ mySpacing 5
           $ reflectHoriz
           $ ResizableTall 1 (3/100) (1/2) []
full    =    renamed [Replace "full"]
           $ noBorders
           $ Full

myLayout =   desktopLayoutModifiers
           $ T.toggleLayouts full
           $ onWorkspaces ["1_1", "1_2", "1_3", "1_4", "1_5", "1_6", "1_7:chat", "1_8", "1_9"] tiled
           $ onWorkspaces ["0_1", "0_2", "0_3", "0_4", "0_5", "0_6", "0_7:chat", "0_8", "0_9"] tiledR
           $ myDefaultLayout
  where
    myDefaultLayout = tiled

-------------------------------------------
-- Window Rules
--------------------------------------------
myManageHook = composeAll
    [
      appName   =? "fzfmenu"                    --> doCenterFloat,
      title     =? "Media viewer"               --> doCenterFloat,
      className =? "Pavucontrol"                --> doCenterFloat,
      className =? "pavucontrol"                --> doCenterFloat,
      className =? "vlc"                        --> doCenterFloat,
      className =? "stacer"                     --> doCenterFloat,
      className =? "Lxappearance"               --> doCenterFloat,
      className =? "Vmware"                     --> doCenterFloat,
      className =? "Nvidia-settings"            --> doCenterFloat,
      className =? "Hexchat"                    --> doCenterFloat,
      className =? "p3x-onenote"                --> doCenterFloat,
      className =? "Gimp"                       --> doCenterFloat,
      className =? "Viewnioprogramr"            --> doCenterFloat,
      className =? "Blueman-manager"            --> doCenterFloat,
      className =? "Catfish"                    --> doCenterFloat,
      className =? "Gpg-crypter"                --> doCenterFloat,
      className =? "kcachegrind"                --> doCenterFloat,
      className =? "Qalculate-gtk"              --> doCenterFloat,
      className =? "Lxappearance"               --> doCenterFloat,
      className =? "Psi"                        --> doCenterFloat,
      className =? "Image Lounge"               --> doCenterFloat,
      className =? "Seahorse"                   --> doCenterFloat,
      className =? "jetbrains-phpstorm"         --> doShift "0_1",
      className =? "whatsapp-nativefier-d40211" --> doShift "1_7",
      className =? "TelegramDesktop"            --> doShift "1_7",
      className =? "Signal"                     --> doShift "1_7",
      className =? "Skype"                      --> doShift "1_7"
    ] <+> namedScratchpadManageHook myScratchPads

--------------------------------------------
-- Event handling
--------------------------------------------
myHandleEventHook :: Event -> X All
myHandleEventHook = dynamicPropertyChange "WM_NAME" (title =? "Spotify" --> floating)
    where floating  = customFloating $ W.RationalRect l t w h
                      where
                          h = 0.9
                          w = 0.9
                          t = 0.95 -h
                          l = 0.95 -w

myEventHook = myHandleEventHook

spawnToWorkspace :: String -> String -> X ()
spawnToWorkspace workspace program = do
                                      spawnOnce program     
                                      windows $ W.greedyView workspace
--------------------------------------------
-- Startup Hook
--------------------------------------------
myStartupHook = do
    spawnOnce            "picom --no-fading-openclose &" -- Compositor,
    spawnOnce            ".config/polybar/launch.sh &"
    spawnOnce            "xrandr --output DP-2 --auto --output DP-4 --auto --right-of DP-2 &"
    spawnOnce            "xsetroot -cursor_name left_ptr &"
    spawnOnce            "autorandr --change --force &"
    spawnOnce            "flameshot &"
    spawnOnce            "nm-applet &"
    spawnOnce            "clipit &"
    spawnOnce            "blueman-applet &"
    spawnOnce            "setbg &"
    spawnOnce            "remaps &"
    spawnOnce            "whatsapp-nativefier &" 
    spawnOnce            "skypeforlinux &"           
    spawnOnce            "signal-desktop &"     
    spawnOnce            "telegram-desktop &"       
    spawnOnce            "cryptomator &"       
    -- screenWorkspace 1 >>= flip whenJust (windows . W.view)
    -- windows $ W.greedyView "1_7"
    -- screenWorkspace 0 >>= flip whenJust (windows . W.view)
    -- windows $ W.greedyView "0_1"

-------------------------------------------
-- Main
-------------------------------------------
main :: IO ()
main = do
  nScreens <- countScreens
  dbus <- D.connectSession
  D.requestName dbus (D.busName_ "org.xmonad.Log")
    [D.nameAllowReplacement, D.nameReplaceExisting, D.nameDoNotQueue]

  xmonad
    $ docks
    $ def {

        -- simple stuff
        terminal           = myTerminal,
        focusFollowsMouse  = myFocusFollowsMouse,
        clickJustFocuses   = myClickJustFocuses,
        borderWidth        = myBorderWidth,
        modMask            = myModMask,
        workspaces         = withScreens nScreens myWorkspaces,
        normalBorderColor  = myNormalBorderColor,
        focusedBorderColor = myFocusedBorderColor,

         -- key bindings
        keys               = myKeys,
        mouseBindings      = myMouseBindings,

        -- hooks, layouts
        layoutHook         = myLayout,
        manageHook         = myManageHook,
        handleEventHook    = myEventHook <+> fullscreenEventHook,
        startupHook        = myStartupHook,
        logHook            = dynamicLogWithPP (myLogHook dbus)
    } `additionalKeysP` myKeyb
