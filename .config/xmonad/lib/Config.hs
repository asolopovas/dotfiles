{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
module Config
    ( UserConfig(..)
    , WindowRule(..)
    , Scratchpad(..)
    , FloatMode(..)
    , defaultConfig
    , loadConfig
    , loadConfigOrDefault
    , configPath
    , reloadWindowRules
    ) where

import Data.Aeson
import qualified Data.ByteString.Lazy as BL
import qualified Data.Map.Strict as M
import qualified Data.Text as T
import Data.Maybe (fromMaybe)
import System.Directory (doesFileExist, getHomeDirectory)
import Control.Exception (catch, SomeException)

data FloatMode
    = FloatCenter
    | FloatSmall
    | FloatMedium
    | FloatLarge
    | FloatDefault     -- doFloat (keeps native size/position)
    | FloatTile        -- explicit tile (noop)
    | FloatIgnore      -- doIgnore
    | FloatCustom Double Double Double Double
    deriving (Show, Eq)

parseFloat :: T.Text -> Maybe FloatMode
parseFloat t = case T.toLower t of
    "center" -> Just FloatCenter
    "small"  -> Just FloatSmall
    "sm"     -> Just FloatSmall
    "medium" -> Just FloatMedium
    "md"     -> Just FloatMedium
    "large"  -> Just FloatLarge
    "lg"     -> Just FloatLarge
    "float"  -> Just FloatDefault
    "tile"   -> Just FloatTile
    "none"   -> Just FloatTile
    "ignore" -> Just FloatIgnore
    _        -> Nothing

instance FromJSON FloatMode where
    parseJSON (String t) = maybe (fail $ "Unknown float mode: " ++ T.unpack t) pure (parseFloat t)
    parseJSON (Object o) = FloatCustom
        <$> o .: "x" <*> o .: "y" <*> o .: "w" <*> o .: "h"
    parseJSON _ = fail "float must be string or {x,y,w,h} object"

data WindowRule = WindowRule
    { wrClassName    :: Maybe String
    , wrAppName      :: Maybe String
    , wrTitle        :: Maybe String
    , wrTitleSuffix  :: Maybe String
    , wrTitlePrefix  :: Maybe String
    , wrTitleContains:: Maybe String
    , wrRole         :: Maybe String
    , wrFloat        :: Maybe FloatMode
    , wrWorkspace    :: Maybe String
    } deriving (Show, Eq)

instance FromJSON WindowRule where
    parseJSON = withObject "WindowRule" $ \o -> WindowRule
        <$> o .:? "className"
        <*> o .:? "appName"
        <*> o .:? "title"
        <*> o .:? "titleSuffix"
        <*> o .:? "titlePrefix"
        <*> o .:? "titleContains"
        <*> o .:? "role"
        <*> o .:? "float"
        <*> o .:? "workspace"

data Scratchpad = Scratchpad
    { spName    :: String
    , spCommand :: String
    , spMatchBy :: String         -- "className" | "title" | "appName"
    , spMatch   :: String
    , spFloat   :: FloatMode
    } deriving Show

instance FromJSON Scratchpad where
    parseJSON = withObject "Scratchpad" $ \o -> Scratchpad
        <$> o .:  "name"
        <*> o .:  "command"
        <*> o .:? "matchBy" .!= "className"
        <*> o .:  "match"
        <*> o .:? "float"   .!= FloatLarge

data UserConfig = UserConfig
    { ucTerminal          :: String
    , ucBrowser           :: String
    , ucFilebrowser       :: String
    , ucModMask           :: String
    , ucBorderWidth       :: Int
    , ucNormalColor       :: String
    , ucFocusedColor      :: String
    , ucFocusFollowsMouse :: Bool
    , ucClickJustFocuses  :: Bool
    , ucWorkspaces        :: [String]
    , ucKeys              :: M.Map String String
    , ucWindowRules       :: [WindowRule]
    , ucScratchpads       :: [Scratchpad]
    } deriving Show

instance FromJSON UserConfig where
    parseJSON = withObject "UserConfig" $ \o -> UserConfig
        <$> o .:? "terminal"          .!= ucTerminal          defaultConfig
        <*> o .:? "browser"           .!= ucBrowser           defaultConfig
        <*> o .:? "filebrowser"       .!= ucFilebrowser       defaultConfig
        <*> o .:? "modMask"           .!= ucModMask           defaultConfig
        <*> o .:? "borderWidth"       .!= ucBorderWidth       defaultConfig
        <*> o .:? "normalBorderColor" .!= ucNormalColor       defaultConfig
        <*> o .:? "focusedBorderColor".!= ucFocusedColor      defaultConfig
        <*> o .:? "focusFollowsMouse" .!= ucFocusFollowsMouse defaultConfig
        <*> o .:? "clickJustFocuses"  .!= ucClickJustFocuses  defaultConfig
        <*> o .:? "workspaces"        .!= ucWorkspaces        defaultConfig
        <*> o .:? "keys"              .!= M.empty
        <*> o .:? "windowRules"       .!= []
        <*> o .:? "scratchpads"       .!= []

defaultConfig :: UserConfig
defaultConfig = UserConfig
    { ucTerminal          = "alacritty"
    , ucBrowser           = "$BROWSER"
    , ucFilebrowser       = "thunar"
    , ucModMask           = "mod4"
    , ucBorderWidth       = 1
    , ucNormalColor       = "#dddddd"
    , ucFocusedColor      = "#fff323"
    , ucFocusFollowsMouse = False
    , ucClickJustFocuses  = False
    , ucWorkspaces        = ["1","2","3","4","5","6","7","8","9"]
    , ucKeys              = M.empty
    , ucWindowRules       = []
    , ucScratchpads       = []
    }

configPath :: IO FilePath
configPath = fmap (++ "/.config/xmonad/config.json") getHomeDirectory

loadConfig :: IO (Either String UserConfig)
loadConfig = do
    path <- configPath
    exists <- doesFileExist path
    if not exists
        then return (Left ("config not found: " ++ path))
        else (do
            bs <- BL.readFile path
            case eitherDecode bs of
                Right cfg -> return (Right cfg)
                Left err  -> return (Left err))
            `catch` \e -> return (Left (show (e :: SomeException)))

loadConfigOrDefault :: IO UserConfig
loadConfigOrDefault = do
    r <- loadConfig
    case r of
        Right c -> return c
        Left e  -> do
            putStrLn ("[xmonad] config load failed, using defaults: " ++ e)
            return defaultConfig

-- Re-read just the windowRules array (used by manageHook). Falls back to
-- empty list on any failure.
reloadWindowRules :: IO [WindowRule]
reloadWindowRules = fmap ucWindowRules loadConfigOrDefault
