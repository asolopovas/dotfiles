module LogHook (logPP) where

import Control.Exception (SomeException, try)
import qualified DBus as D
import qualified DBus.Client as D
import qualified Data.ByteString.Char8 as BS8
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import System.IO (hPutStrLn, stderr)
import XMonad
import XMonad.Hooks.DynamicLog

red, blue, blue2 :: String
red   = "#fb4934"
blue  = "#83a598"
blue2 = "#2266d0"

logPP :: D.Client -> PP
logPP dbus =
    def
        { ppOutput  = dbusOutput dbus
        , ppCurrent = wrap ("%{F" ++ blue2 ++ "} ") " %{F-}"
        , ppVisible = wrap ("%{F" ++ blue  ++ "} ") " %{F-}"
        , ppUrgent  = wrap ("%{F" ++ red   ++ "} ") " %{F-}"
        , ppHidden  = wrap " " " "
        , ppWsSep   = ""
        , ppSep     = " | "
        , ppTitle   = padRight 25
        }

dbusOutput :: D.Client -> String -> IO ()
dbusOutput dbus str = do
    let payload = BS8.unpack (TE.encodeUtf8 (T.pack str))
        sig =
            (D.signal objectPath interfaceName memberName)
                {D.signalBody = [D.toVariant payload]}
    res <- try (D.emit dbus sig) :: IO (Either SomeException ())
    case res of
        Right _ -> pure ()
        Left e  -> hPutStrLn stderr ("[xmonad] dbus emit failed: " ++ show e)
  where
    objectPath    = D.objectPath_    "/org/xmonad/Log"
    interfaceName = D.interfaceName_ "org.xmonad.Log"
    memberName    = D.memberName_    "Update"

padRight :: Int -> String -> String
padRight n s = sstr ++ replicate (n - length sstr) ' '
  where
    sstr = shorten n s
