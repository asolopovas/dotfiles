module Scratchpads (buildScratchpads) where

import Control.Exception (SomeException, try)
import Data.List (stripPrefix)
import Data.Maybe (fromMaybe)
import System.Directory (getHomeDirectory)
import System.FilePath ((</>))
import XMonad
import XMonad.Util.NamedScratchpad

import Config (Scratchpad (..))
import FloatMode (FloatMode (..))
import Util (centeredRect, rect)

buildScratchpads :: [Scratchpad] -> [NamedScratchpad]
buildScratchpads = map toNS

toNS :: Scratchpad -> NamedScratchpad
toNS sp = NS (spName sp) (spCommand sp) (matcher sp) (dynamicFloater (spName sp) (spFloat sp))

matcher :: Scratchpad -> Query Bool
matcher sp = baseMatch <&&> notExcluded
  where
    baseMatch = case spMatchBy sp of
        "title"   -> title   =? spMatch sp
        "appName" -> appName =? spMatch sp
        _         -> className =? spMatch sp
    notExcluded = maybe (pure True) (\t -> fmap (/= t) title) (spExcludeTitle sp)

dynamicFloater :: String -> FloatMode -> ManageHook
dynamicFloater name fallback = do
    liveMode <- liftIO (lookupLiveMode name)
    floater (fromMaybe fallback liveMode)

lookupLiveMode :: String -> IO (Maybe FloatMode)
lookupLiveMode name = do
    home <- getHomeDirectory
    let path = home </> ".cache" </> "xmonad" </> "scratchpad-sizes"
    res <- try (readFile path) :: IO (Either SomeException String)
    case res of
        Left _        -> pure Nothing
        Right content -> pure (lookupName name (lines content))

lookupName :: String -> [String] -> Maybe FloatMode
lookupName _ [] = Nothing
lookupName name (l : rest) = case stripPrefix (name ++ " ") l of
    Just sizeName -> parseMode sizeName
    Nothing       -> lookupName name rest

parseMode :: String -> Maybe FloatMode
parseMode "small"  = Just FloatSmall
parseMode "medium" = Just FloatMedium
parseMode "large"  = Just FloatLarge
parseMode "center" = Just FloatCenter
parseMode _        = Nothing

floater :: FloatMode -> ManageHook
floater FloatCenter           = customFloating (rect 0.25 0.25 0.5 0.5)
floater FloatSmall            = customFloating (centeredRect 0.5)
floater FloatMedium           = customFloating (centeredRect 0.7)
floater FloatLarge            = customFloating (centeredRect 0.9)
floater FloatTile             = nonFloating
floater FloatDefault          = customFloating (centeredRect 0.7)
floater FloatIgnore           = nonFloating
floater (FloatCustom x y w h) = customFloating (rect x y w h)
