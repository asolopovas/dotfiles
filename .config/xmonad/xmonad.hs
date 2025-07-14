-------------------------------------------
-- Imports
-------------------------------------------
import XMonad
import XMonad.ManageHook
import XMonad.Config.Desktop
import Control.Concurrent (threadDelay)
import Graphics.X11.ExtraTypes.XF86

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
import XMonad.Hooks.Place
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.EwmhDesktops
import XMonad.Hooks.ManageDocks (manageDocks, docks, avoidStruts)
import XMonad.Hooks.ManageHelpers (isFullscreen, doFullFloat, doCenterFloat, doRectFloat)
import XMonad.Hooks.WindowSwallowing

import Data.Monoid
import System.Exit
import System.Environment

import qualified DBus as D
import qualified DBus.Client as D
import qualified XMonad.Layout.BoringWindows as B
import qualified Codec.Binary.UTF8.String as UTF8

import qualified XMonad.StackSet as W
import qualified Data.Map        as M

import System.IO (appendFile)
import Control.Monad (when)

-------------------------------------------
-- Globals
-------------------------------------------
myNormalBorderColor  = "#dddddd"
myFocusedBorderColor = "#fff323"

myTerminal           = "alacritty"
myBrowser            = "brave-browser --no-default-browser-check --enable-features=WebUIDarkMode --force-dark-mode"
myFilebrowser        = "thunar"
myModMask            = mod4Mask
myWorkspaces         = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
myBorderWidth        = 1

myFocusFollowsMouse :: Bool
myFocusFollowsMouse = False
-- Whether clicking on a window to focus also passes the click to the window
myClickJustFocuses :: Bool
myClickJustFocuses = False

-------------------------------------------
-- Keybinding
-------------------------------------------
myKeyb :: [(String, X ())]
myKeyb =
  [
    --Windows
    ("M-q",            kill1                           ), -- Kill focused window
    ("M-S-q",          killAll                         ), -- Kill all workspace windows
    ("M-s",            windows W.focusMaster           ), -- Move focus to the master window
    ("M-j",            windows W.focusDown             ), -- Move focus to the next window
    ("M-k",            windows W.focusUp               ), -- Move focus to the prev window
    ("M-S-j",          windows W.swapDown              ), -- Swap focused window with next window
    ("M-S-k",          windows W.swapUp                ), -- Swap focused window with prev window
    ("M-<Backspace>",  promote                         ), -- Moves focused window to master
    ("M-f",            sendMessage (T.Toggle "full")   ), -- Toggle layout full layout
    ("M-S-<Space>",    sendMessage NextLayout          ), -- Toggle layout full layout
    ("M-S-y",          sendMessage Shrink              ), -- Expand Layout
    ("M-S-o",          sendMessage Expand              ), -- Shrink Layout
    ("M-S-u",          sendMessage MirrorShrink        ), -- Vertical Shrink Layout
    ("M-S-i",          sendMessage MirrorExpand        ), -- Vertical Expand Layout
    --Applications
    ("M-<Return>",     spawn myTerminal               ),
    ("M-d",            spawn "rofi -show run"         ),
    ("M-c",            spawn myBrowser                ),
    ("M-S-d",          spawn "su_dmenu_run"           ),
    ("M-0",            spawn "sysact"                 ),
    ("M-p",            spawn "fzf-menu fzf-thunar"    ),
    ("M-o",            spawn "fzf-menu fzf-code"      ),
    ("M-S-p",          spawn "fzf-menu fzf-alacritty" ),
    --Layouts
    ("M-.",           sendMessage (IncMasterN 1)      ), -- Increase number of clients in master pane
    ("M-,",           sendMessage (IncMasterN (-1))   ), -- Decrease number of clients in master pane
    --Floating Windows
    ("M-<Delete>",     withFocused $ windows . W.sink ), -- Push floating window back to tile
    ("M-t",            toggleFloat                    ),
    --Xmonad
    ("M-<F6>",         spawn "xmonad --recompile; xmonad --restart; notify-send 'Xmonad Recompiled'"      ), -- Restarts xmonad
    ("M-S-e",          io exitSuccess                                    ), -- Quits xmonad
    --Scratchpads
    ("M-m",              namedScratchpadAction myScratchPads "spotify"       ),
    ("<F7>",             namedScratchpadAction myScratchPads "chatGPT"       ),
    ("M-b"  ,            namedScratchpadAction myScratchPads "firefox"       ),
    ("M-x",              namedScratchpadAction myScratchPads "filebrowser"   ),
    ("M-S-x",            namedScratchpadAction myScratchPads "pcmanfmSearch" ),
    ("M-S-<Return>",     namedScratchpadAction myScratchPads "terminal"      ),
    ("<XF86Launch6>",    namedScratchpadAction myScratchPads "pavucontrol"   ),
    ("<F8>",             namedScratchpadAction myScratchPads "stacer"        ),
    ("<XF86Calculator>", namedScratchpadAction myScratchPads "calc"          ),

    --Media Keys
    ("<XF86AudioLowerVolume>", spawn "lmc down; kill -44 $(pidof dwmblocks)" ),
    ("<XF86AudioRaiseVolume>", spawn "lmc up; kill -44 $(pidof dwmblocks)"   ),
    ("<XF86AudioMute>",        spawn "lmc mute; kill -44 $(pidof dwmblocks)" ),  -- Bug prevents it from toggling correctly in 12.04.
    ("<XF86AudioPlay>",        spawn "playerctl play-pause"                  ),
    ("<XF86MonBrightnessUp>",   spawn "lux -a 5%"                            ),
    ("<XF86MonBrightnessDown>", spawn "lux -s 5%"                            ),
    ("<XF86AudioStop>",        spawn "playerctl stop"                        ),
    ("<XF86AudioPrev>",        spawn "playerctl previous"                    ),
    ("<XF86AudioNext>",        spawn "playerctl next"                        ),
    ("<Print>",                spawn "flameshot gui"                         ),
    ("<XF86MenuPB>",           spawn "flameshot gui"                         )

  ]

myScratchPads =
    [
        buildNS "filebrowser"  myFilebrowser                                 "className" "Thunar"            "lg",
        buildNS "firefox"      "firefox --class='FirefoxScratchpad'"         "className" "FirefoxScratchpad" "lg",
        buildNS "terminal"     spawnTerm                                     "title"     "scratchpad"        "md",
        buildNS "stacer"       "sudo -A /usr/bin/stacer > /tmp/stacer.log"  "className" "stacer"            "md",
        buildNS "pavucontrol"  "pavucontrol"                                 "className" "Pavucontrol"       "md",
        buildNS "spotify"      "spotify"                                     "className" "Spotify"           "lg",
        buildNS "chatGPT"      "chat-gpt"                                    "className" "Chat-gpt"          "lg",
        buildNS "thunderbird"  "thunderbird"                                 "className" "Thunderbird"       "lg",
        buildNS "calc"         "gnome-calculator"                            "className" "Gnome-calculator"  "lg"
    ]

    where
      spawnTerm  = myTerminal ++ " -t scratchpad"

myManageHook = composeAll
    [
        stringProperty "WM_WINDOW_ROLE" =? "GtkFileChooserDialog"  -->doCenterFloat,
        stringProperty "WM_WINDOW_ROLE" =? "pop-up" --> doCenterFloat,
        appName   =? "fzf-menu"                    --> doCenterFloat,
        appName   =? "pcmanfmTerm"                --> doCenterFloat,
        appName   =? "gnome-tweaks"               --> doCenterFloat,
        appName   =? "gnome-calculator"           --> doRectFloat smFloat,
        appName   =? "xdg-desktop-portal-gnome"   --> doCenterFloat,
        title     =? "Picture-in-picture"         --> doRectFloat smFloat,
        title     =? "Media viewer"               --> doCenterFloat,
        title     =? "Cryptomator"                --> doRectFloat mdFloat,
        title     =? "Bitwarden"                  --> doFloat,
        className =? "Pavucontrol"                --> doCenterFloat,
        className =? "qt5ct"                      --> doCenterFloat,
        className =? "Nm-connection-editor"       --> doCenterFloat,
        className =? "Gnome-builder"              --> doCenterFloat,
        className =? "Org.gnome.Software"         --> doCenterFloat,
        className =? "Libfm-pref-apps"            --> doCenterFloat,
        className =? "pavucontrol"                --> doCenterFloat,
        className =? "vlc"                        --> doRectFloat mdFloat,
        className =? "Insync"                     --> doRectFloat mdFloat,
        className =? "Viewnior"                   --> doCenterFloat,
        className =? "Barrier"                    --> doCenterFloat,
        className =? "stacer"                     --> doCenterFloat,
        className =? "Lxappearance"               --> doCenterFloat,
        className =? "Vmware"                     --> doCenterFloat,
        className =? "Nvidia-settings"            --> doCenterFloat,
        className =? "Hexchat"                    --> doCenterFloat,
        className =? "p3x-onenote"                --> doCenterFloat,
        className =? "Gimp"                       --> doCenterFloat,
        className =? "Viewnioprogramr"            --> doCenterFloat,
        className =? "Blueman-manager"            --> doRectFloat mdFloat,
        className =? "Catfish"                    --> doCenterFloat,
        className =? "Gpg-crypter"                --> doCenterFloat,
        className =? "kcachegrind"                --> doCenterFloat,
        className =? "Qalculate-gtk"              --> doCenterFloat,
        className =? "flameshot"                  --> doRectFloat lgFloat,
        className =? "Anydesk"                    --> doRectFloat mdFloat,
        className =? "Psi"                        --> doCenterFloat,
        className =? "Image Lounge"               --> doCenterFloat,
        className =? "Seahorse"                   --> doCenterFloat,
        className =? "Xarchiver"                  --> doCenterFloat,
        className =? "whatsapp-nativefier-d40211" --> doShift "1_7",
        className =? "TelegramDesktop"            --> doRectFloat lgFloat,
        className =? "Signal"                     --> doRectFloat lgFloat,
        className =? "Skype"                      --> doRectFloat lgFloat,
        className =? "Teamviewer"                 --> doRectFloat lgFloat
    ] <+> namedScratchpadManageHook myScratchPads

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

myKeys conf@ XConfig {XMonad.modMask = modm} = M.fromList $
    -- mod-[1..9], Switch to workspace N
    -- mod-shift-[1..9], Move client to workspace N
    [((m .|. modm, k), windows $ onCurrentScreen f i)
        | (i, k) <- zip (workspaces' conf) [xK_1 .. xK_9]
        , (f, m) <- [(W.view, 0), (W.shift, shiftMask)]]
    ++
    -- Bind h and l to cycle through screens
    [((modm, xK_h), cycleScreens Prev)  -- Bind h to cycle backwards
    ,((modm, xK_l), cycleScreens Next)] -- Bind l to cycle forwards
    ++
    -- Bind mod-shift-h and mod-shift-l to shift and follow window to another screen
    [((modm .|. shiftMask, xK_h), shiftAndFollowScreen Prev)  -- Bind M-S-h
    ,((modm .|. shiftMask, xK_l), shiftAndFollowScreen Next)] -- Bind M-S-l

--------------------------------------------
-- Functions and Configurations
--------------------------------------------
-- Enum to represent screen cycling direction
data Direction = Prev | Next

-- Function to cycle through screens
cycleScreens :: Direction -> X ()
cycleScreens dir = do
    screenCount <- countScreens
    when (screenCount > 0) $ do
        currentScreen <- gets (W.screen . W.current . windowset)
        let offset = case dir of
                        Prev -> -1
                        Next -> 1
        let nextScreen = (currentScreen + offset + screenCount) `mod` screenCount
        screenWorkspace nextScreen >>= flip whenJust (windows . W.view)

-- Function to shift the current window to the next or previous screen and then follow it
shiftAndFollowScreen :: Direction -> X ()
shiftAndFollowScreen dir = do
    screenCount <- countScreens
    when (screenCount > 0) $ do
        currentScreen <- gets (W.screen . W.current . windowset)
        let offset = case dir of
                        Prev -> -1
                        Next -> 1
        let nextScreenId = (currentScreen + offset + screenCount) `mod` screenCount
        screenWorkspace nextScreenId >>= flip whenJust (\ws -> do
            win <- gets (W.peek . windowset)
            case win of
                Just w -> do
                    windows $ W.shift ws
                    windows $ W.view ws
                Nothing -> return ())

--------------------------------------------
-- Startup
--------------------------------------------
myStartupHook = do
    fixWorkspaceAssignment
    spawnOnce "dotfiles/autostart.sh &"

fixWorkspaceAssignment :: X ()
fixWorkspaceAssignment = do
    nScreens <- countScreens
    when (nScreens == 2) $ do
        -- Logic for two screens
        screenWorkspace 1 >>= flip whenJust (windows . W.view)
        windows $ W.view "1_1"
        screenWorkspace 0 >>= flip whenJust (windows . W.view)
    when (nScreens == 3) $ do
        -- Logic for three screens
        screenWorkspace 1 >>= flip whenJust (windows . W.view)
        windows $ W.view "1_1"
        screenWorkspace 2 >>= flip whenJust (windows . W.view)
        windows $ W.view "2_1"
        screenWorkspace 0 >>= flip whenJust (windows . W.view)

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

-- Utility Functions
makeFloat :: Float -> W.RationalRect
makeFloat dim = W.RationalRect
    (toRational ((1 - dim) / 2))
    (toRational ((1 - dim) / 2))
    (toRational dim)
    (toRational dim)

-- Float Definitions for Scratchpads
smFloatCustom  = customFloating $ makeFloat 0.5
mdFloatCustom  = customFloating $ makeFloat 0.7
lgFloatCustom  = customFloating $ makeFloat 0.9

-- Float Definitions for Window Rules
smFloat = makeFloat 0.5
mdFloat = makeFloat 0.7
lgFloat = makeFloat 0.9

-- A helper function to build the NS row more concisely
buildNS :: String -> String -> String -> String -> String -> NamedScratchpad
buildNS name cmd prop value floatTypeStr = NS name cmd (property =? value) (floatType floatTypeStr)
    where
        property
            | prop == "title"    = title
            | prop == "className" = className
            -- Add other properties as needed
        floatType "sm" = smFloatCustom
        floatType "md" = mdFloatCustom
        floatType "lg" = lgFloatCustom

--------------------------------------------
-- Mouse bindings
--------------------------------------------
myMouseBindings XConfig {XMonad.modMask = modm} = M.fromList
    [
      -- mod-button1, Set the window to floating mode and move by dragging
      ((modm, button1), \w -> focus w >> mouseMoveWindow w
                                       >> windows W.shiftMaster),
      -- mod-button2, Raise the window to the top of the stack
      ((modm, button2), \w -> focus w >> windows W.shiftMaster),
       -- mod-button3, Set the window to floating mode and resize by dragging
      ((modm, button3), \w -> focus w >> mouseResizeWindow w
                                       >> windows W.shiftMaster)
      -- you may also bind events to the mouse scroll wheel (button4 and button5)
    ]

--------------------------------------------
-- LogHook
--------------------------------------------
red       = "#fb4934"
blue      = "#83a598"
blue2     = "#2266d0"
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

--------------------------------------------
-- Event handling
--------------------------------------------
winSwallowHook :: Event -> X All
winSwallowHook = swallowEventHook ( className =? "Alacritty" ) (return True)

myHandleEventHook = winSwallowHook
-- myHandleEventHook = winSwallowHook

spawnToWorkspace :: String -> String -> X ()
spawnToWorkspace workspace program = do
                                      spawnOnce program
                                      windows $ W.greedyView workspace

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
    $ ewmhFullscreen
    $ def {
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
        -- manageHook         = placeHook myPlacement <+> myManageHook,
        manageHook         = myManageHook,
        handleEventHook    = myHandleEventHook,
        startupHook        = myStartupHook,
        logHook            = dynamicLogWithPP (myLogHook dbus)
    }
    `additionalKeysP` myKeyb
