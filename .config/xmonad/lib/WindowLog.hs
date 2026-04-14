{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE ScopedTypeVariables #-}
module WindowLog (logNewWindow) where

import XMonad
import qualified XMonad.Util.ExtensibleState as XS
import qualified Data.Set as Set
import Data.Set (Set)
import Data.Typeable (Typeable)
import System.Directory (doesFileExist, createDirectoryIfMissing, getHomeDirectory)
import System.FilePath (takeDirectory)
import Control.Monad (unless)
import Control.Exception (catch, SomeException)

windowLogPath :: IO FilePath
windowLogPath = fmap (++ "/.cache/xmonad/windows.tsv") getHomeDirectory

newtype SeenClasses = SeenClasses (Set String) deriving Typeable

instance ExtensionClass SeenClasses where
    initialValue = SeenClasses Set.empty

-- Seed the in-memory set from disk on first run. Subsequent calls are O(1).
primeSeen :: X ()
primeSeen = do
    SeenClasses cur <- XS.get
    case Set.toList cur of
        [] -> do
            path <- io windowLogPath
            disk <- io (loadFromDisk path)
            -- put a sentinel so we don't re-read even when the file is empty
            XS.put (SeenClasses (Set.insert "" disk))
        _ -> return ()
  where
    loadFromDisk path = (do
        exists <- doesFileExist path
        if not exists then return Set.empty
        else do
            contents <- readFile path
            return (Set.fromList [takeWhile (/= '\t') l | l <- lines contents, not (null l)]))
        `catch` \(_ :: SomeException) -> return Set.empty

logNewWindow :: ManageHook
logNewWindow = do
    cls <- className
    app <- appName
    ttl <- title
    liftX (record cls app ttl)
    idHook
  where
    record cls app ttl = do
        primeSeen
        SeenClasses seen <- XS.get
        unless (null cls || Set.member cls seen) $ do
            path <- io windowLogPath
            io (append path cls app ttl)
            XS.put (SeenClasses (Set.insert cls seen))
    append path cls app ttl = (do
        createDirectoryIfMissing True (takeDirectory path)
        appendFile path (cls ++ "\t" ++ app ++ "\t" ++ ttl ++ "\n"))
        `catch` \(_ :: SomeException) -> return ()
