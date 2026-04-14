module Scratchpads (myScratchPads, buildNS, buildNSTiled) where

import XMonad
import XMonad.Util.NamedScratchpad

import Settings
import Floats

myScratchPads :: [NamedScratchpad]
myScratchPads =
    [
        buildNSTiled "firefox" "firefox --class='FirefoxScratchpad' --enable-features=WebUIDarkMode --force-dark-mode" "className" "FirefoxScratchpad",
        buildNSTiled "brave"   "sh -c '$BROWSER --class=BraveScratchpad'"    "className" "BraveScratchpad",
        buildNS "filebrowser"  myFilebrowser                                 "className" "Thunar"            "lg",
        buildNS "terminal"     spawnTerm                                     "title"     "scratchpad"        "md",
        buildNS "stacer"       "sudo -A /usr/bin/stacer > /tmp/stacer.log"   "className" "stacer"            "md",
        buildNS "pavucontrol"  "pavucontrol"                                 "className" "Pavucontrol"       "md",
        buildNS "spotify"      "spotify"                                     "className" "Spotify"           "lg",
        buildNS "aimp"         "aimp"                                        "className" "Aimp"              "lg",
        buildNS "chatGPT"      "chat-gpt"                                    "className" "Chat-gpt"          "lg",
        buildNS "thunderbird"  "thunderbird"                                 "className" "thunderbird"       "lg",
        buildNS "calc"         "gnome-calculator"                            "className" "Gnome-calculator"  "lg",
        NS "help" "alacritty --class help-viewer,help-viewer -o window.dimensions.columns=82 -o window.dimensions.lines=50 -e glow -w 90 -p ~/dotfiles/docs/help.md" (appName =? "help-viewer") (customFloating helpFloat)
    ]
    where
      spawnTerm = myTerminal ++ " -t scratchpad"

-- A helper function to build the NS row more concisely
buildNS :: String -> String -> String -> String -> String -> NamedScratchpad
buildNS name cmd prop value floatTypeStr = NS name cmd (property =? value) (floatType floatTypeStr)
    where
        property
            | prop == "title"    = title
            | prop == "className" = className
        floatType "sm" = smFloatCustom
        floatType "md" = mdFloatCustom
        floatType "lg" = lgFloatCustom
        floatType "tiled" = doIgnore

-- Build scratchpad without floating
buildNSTiled :: String -> String -> String -> String -> NamedScratchpad
buildNSTiled name cmd prop value = NS name cmd (property =? value) nonFloating
    where
        property
            | prop == "title"    = title
            | prop == "className" = className
