module ManageRules (myManageHook) where

import XMonad
import XMonad.Hooks.ManageHelpers (doCenterFloat, doRectFloat)
import XMonad.Util.NamedScratchpad (namedScratchpadManageHook)
import Data.List (isSuffixOf, isPrefixOf)

import Floats
import Scratchpads

myManageHook :: ManageHook
myManageHook = composeAll
    [
        fmap (isPrefixOf "Mint") className                          --> doCenterFloat,
        stringProperty "WM_WINDOW_ROLE" =? "GtkFileChooserDialog"  --> doCenterFloat,
        stringProperty "WM_WINDOW_ROLE" =? "pop-up"                --> doCenterFloat,
        appName   =? "fzf-menu"                    --> doCenterFloat,
        appName   =? "pcmanfmTerm"                --> doCenterFloat,
        appName   =? "gnome-tweaks"               --> doCenterFloat,
        appName   =? "gnome-calculator"           --> doRectFloat smFloat,
        appName   =? "xdg-desktop-portal-gnome"   --> doCenterFloat,
        className =? "Thunar" <&&> fmap (isSuffixOf "- Thunar") title        --> doCenterFloat,
        className =? "Thunar" <&&> fmap (not . isSuffixOf "- Thunar") title --> doFloat,
        title     =? "Picture-in-picture"         --> doRectFloat smFloat,
        title     =? "Media viewer"               --> doCenterFloat,
        title     =? "Cryptomator"                --> doRectFloat mdFloat,
        title     =? "Preferences" <&&> className =? "org.cryptomator.launcher.Cryptomator$MainApp" --> doFloat,
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
        className =? "Xviewer"                    --> doCenterFloat,
        className =? "Image Lounge"               --> doCenterFloat,
        className =? "Seahorse"                   --> doCenterFloat,
        className =? "Xarchiver"                  --> doCenterFloat,
        className =? "Aimp"                       --> doCenterFloat,
        className =? "whatsapp-nativefier-d40211" --> doShift "1_7",
        className =? "TelegramDesktop"            --> doRectFloat lgFloat,
        className =? "Signal"                     --> doRectFloat lgFloat,
        className =? "Skype"                      --> doRectFloat lgFloat,
        className =? "Teamviewer"                 --> doRectFloat lgFloat,
        className =? "Windscribe2"                --> doFloat
    ] <+> namedScratchpadManageHook myScratchPads
