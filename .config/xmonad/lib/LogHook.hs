module LogHook (myLogHook) where

import XMonad
import XMonad.Hooks.DynamicLog
import qualified DBus as D
import qualified DBus.Client as D
import qualified Codec.Binary.UTF8.String as UTF8

red, blue, blue2 :: String
red   = "#fb4934"
blue  = "#83a598"
blue2 = "#2266d0"

myLogHook :: D.Client -> PP
myLogHook dbus = def
    {
      ppOutput  = dbusOutput dbus,
      ppCurrent = wrap ("%{F" ++ blue2 ++ "} ") " %{F-}",
      ppVisible = wrap ("%{F" ++ blue  ++ "} ") " %{F-}",
      ppUrgent  = wrap ("%{F" ++ red   ++ "} ") " %{F-}",
      ppHidden  = wrap " " " ",
      ppWsSep   = "",
      ppSep     = " | ",
      ppTitle   = myAddSpaces 25
    }

-- Emit a DBus signal on log updates
dbusOutput :: D.Client -> String -> IO ()
dbusOutput dbus str = do
    let signal = (D.signal objectPath interfaceName memberName) {
            D.signalBody = [D.toVariant $ UTF8.encodeString str]
        }
    D.emit dbus signal
  where
    objectPath    = D.objectPath_ "/org/xmonad/Log"
    interfaceName = D.interfaceName_ "org.xmonad.Log"
    memberName    = D.memberName_ "Update"

myAddSpaces :: Int -> String -> String
myAddSpaces len str = sstr ++ replicate (len - length sstr) ' '
  where
    sstr = shorten len str
