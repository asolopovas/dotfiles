{-# LANGUAGE ScopedTypeVariables #-}
module WindowLog (logNewWindow) where

import Control.Exception (SomeException, catch)
import Control.Monad (unless)
import Control.Monad.Reader (ask)
import Data.Set (Set)
import qualified Data.Set as Set
import System.Directory (createDirectoryIfMissing, doesFileExist, getHomeDirectory)
import System.FilePath (takeDirectory, (</>))
import XMonad
import qualified XMonad.Util.ExtensibleState as XS

import Safe (safeRunQuery)

windowLogPath :: IO FilePath
windowLogPath = do
    home <- getHomeDirectory
    pure (home </> ".cache" </> "xmonad" </> "windows.tsv")

newtype SeenClasses = SeenClasses (Set String)

instance ExtensionClass SeenClasses where
    initialValue = SeenClasses Set.empty

primeSeen :: X ()
primeSeen = do
    SeenClasses cur <- XS.get
    case Set.toList cur of
        [] -> do
            path <- io windowLogPath
            disk <- io (loadFromDisk path)
            XS.put (SeenClasses (Set.insert "" disk))
        _ -> pure ()
  where
    loadFromDisk path =
        ( do
            exists <- doesFileExist path
            if not exists
                then pure Set.empty
                else do
                    contents <- readFile path
                    pure (Set.fromList [takeWhile (/= '\t') l | l <- lines contents, not (null l)])
        )
            `catch` \(_ :: SomeException) -> pure Set.empty

logNewWindow :: ManageHook
logNewWindow = do
    w <- ask
    cls <- liftX (safeRunQuery "" className w)
    app <- liftX (safeRunQuery "" appName w)
    ttl <- liftX (safeRunQuery "" title w)
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
    append path cls app ttl =
        ( do
            createDirectoryIfMissing True (takeDirectory path)
            appendFile path (cls ++ "\t" ++ app ++ "\t" ++ ttl ++ "\n")
        )
            `catch` \(_ :: SomeException) -> pure ()
