{-# LANGUAGE OverloadedStrings #-}
module Config
    ( UserConfig (..)
    , WindowRule (..)
    , Scratchpad (..)
    , defaultConfig
    , loadConfig
    , loadConfigOrDefault
    , configPath
    , reloadWindowRules
    , reloadSwallowExclusions
    , matchesRule
    ) where

import Control.Exception (SomeException, try)
import Data.Aeson (FromJSON (..), eitherDecode, withObject, (.!=), (.:), (.:?))
import qualified Data.ByteString.Lazy as BL
import Data.List (isInfixOf, isPrefixOf, isSuffixOf)
import qualified Data.Map.Strict as M
import System.Directory (doesFileExist, getHomeDirectory)
import System.FilePath ((</>))
import System.IO (hPutStrLn, stderr)
import XMonad (Query, className, appName, title, stringProperty, (=?), (<&&>))

import FloatMode (FloatMode (..))

data WindowRule = WindowRule
    { wrClassName     :: Maybe String
    , wrAppName       :: Maybe String
    , wrTitle         :: Maybe String
    , wrTitleSuffix   :: Maybe String
    , wrTitlePrefix   :: Maybe String
    , wrTitleContains :: Maybe String
    , wrRole          :: Maybe String
    , wrFloat         :: Maybe FloatMode
    , wrWorkspace     :: Maybe String
    }
    deriving (Show, Eq)

instance FromJSON WindowRule where
    parseJSON = withObject "WindowRule" $ \o ->
        WindowRule
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
    { spName         :: String
    , spCommand      :: String
    , spMatchBy      :: String
    , spMatch        :: String
    , spFloat        :: FloatMode
    , spExcludeTitle :: Maybe String
    }
    deriving (Show)

instance FromJSON Scratchpad where
    parseJSON = withObject "Scratchpad" $ \o ->
        Scratchpad
            <$> o .:  "name"
            <*> o .:  "command"
            <*> o .:? "matchBy" .!= "className"
            <*> o .:  "match"
            <*> o .:? "float"   .!= FloatLarge
            <*> o .:? "excludeTitle"

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
    , ucSwallowExclusions :: [WindowRule]
    }
    deriving (Show)

instance FromJSON UserConfig where
    parseJSON = withObject "UserConfig" $ \o ->
        UserConfig
            <$> o .:? "terminal"           .!= ucTerminal          defaultConfig
            <*> o .:? "browser"            .!= ucBrowser           defaultConfig
            <*> o .:? "filebrowser"        .!= ucFilebrowser       defaultConfig
            <*> o .:? "modMask"            .!= ucModMask           defaultConfig
            <*> o .:? "borderWidth"        .!= ucBorderWidth       defaultConfig
            <*> o .:? "normalBorderColor"  .!= ucNormalColor       defaultConfig
            <*> o .:? "focusedBorderColor" .!= ucFocusedColor      defaultConfig
            <*> o .:? "focusFollowsMouse"  .!= ucFocusFollowsMouse defaultConfig
            <*> o .:? "clickJustFocuses"   .!= ucClickJustFocuses  defaultConfig
            <*> o .:? "workspaces"         .!= ucWorkspaces        defaultConfig
            <*> o .:? "keys"               .!= M.empty
            <*> o .:? "windowRules"        .!= []
            <*> o .:? "scratchpads"        .!= []
            <*> o .:? "swallowExclusions"  .!= []

defaultConfig :: UserConfig
defaultConfig =
    UserConfig
        { ucTerminal          = "alacritty"
        , ucBrowser           = "$BROWSER"
        , ucFilebrowser       = "thunar"
        , ucModMask           = "mod4"
        , ucBorderWidth       = 1
        , ucNormalColor       = "#dddddd"
        , ucFocusedColor      = "#fff323"
        , ucFocusFollowsMouse = False
        , ucClickJustFocuses  = False
        , ucWorkspaces        = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
        , ucKeys              = M.empty
        , ucWindowRules       = []
        , ucScratchpads       = []
        , ucSwallowExclusions = []
        }

configPath :: IO FilePath
configPath = do
    home <- getHomeDirectory
    pure (home </> ".config" </> "xmonad" </> "config.json")

loadConfig :: IO (Either String UserConfig)
loadConfig = do
    path <- configPath
    exists <- doesFileExist path
    if not exists
        then pure (Left ("config not found: " ++ path))
        else do
            r <- try (BL.readFile path) :: IO (Either SomeException BL.ByteString)
            case r of
                Left e   -> pure (Left (show e))
                Right bs -> pure (eitherDecode bs)

loadConfigOrDefault :: IO UserConfig
loadConfigOrDefault = do
    r <- loadConfig
    case r of
        Right c -> pure c
        Left e -> do
            hPutStrLn stderr ("[xmonad] config load failed, using defaults: " ++ e)
            pure defaultConfig

reloadWindowRules :: IO [WindowRule]
reloadWindowRules = ucWindowRules <$> loadConfigOrDefault

reloadSwallowExclusions :: IO [WindowRule]
reloadSwallowExclusions = ucSwallowExclusions <$> loadConfigOrDefault

matchesRule :: WindowRule -> Query Bool
matchesRule r =
    foldr
        (<&&>)
        (pure True)
        [ maybe (pure True) (className =?) (wrClassName r)
        , maybe (pure True) (appName   =?) (wrAppName   r)
        , maybe (pure True) (title     =?) (wrTitle     r)
        , maybe (pure True) (\s -> isSuffixOf s <$> title) (wrTitleSuffix   r)
        , maybe (pure True) (\s -> isPrefixOf s <$> title) (wrTitlePrefix   r)
        , maybe (pure True) (\s -> isInfixOf  s <$> title) (wrTitleContains r)
        , maybe (pure True) (stringProperty "WM_WINDOW_ROLE" =?) (wrRole r)
        ]
