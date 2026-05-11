module LayoutAgnostic
    ( withLayoutAgnosticKeys
    ) where

import qualified Data.Map.Strict as M
import Control.Exception (SomeException, try)
import Data.List (foldl')
import Data.Maybe (mapMaybe)
import System.IO.Unsafe (unsafePerformIO)
import System.Process (readProcessWithExitCode)
import System.Exit (ExitCode (..))
import XMonad

withLayoutAgnosticKeys :: XConfig l -> XConfig l
withLayoutAgnosticKeys c = c { keys = \cfg -> expandKeys (keys c cfg) }

expandKeys :: M.Map (KeyMask, KeySym) (X ()) -> M.Map (KeyMask, KeySym) (X ())
expandKeys original = unsafePerformIO $ do
    table <- loadKeycodeTable
    let extras =
            [ ((mask, alt), act)
            | ((mask, ks), act) <- M.toList original
            , kc <- maybe [] pure (M.lookup ks table)
            , alt <- M.findWithDefault [] kc (reverseTable table)
            , alt /= ks
            ]
    return $ M.union original (M.fromList extras)

reverseTable :: M.Map KeySym Int -> M.Map Int [KeySym]
reverseTable m = foldl' insert M.empty (M.toList m)
  where
    insert acc (ks, kc) = M.insertWith (++) kc [ks] acc

loadKeycodeTable :: IO (M.Map KeySym Int)
loadKeycodeTable = do
    result <- try (readProcessWithExitCode "xmodmap" ["-pke"] "")
        :: IO (Either SomeException (ExitCode, String, String))
    case result of
        Right (ExitSuccess, out, _) -> do
            pairs <- mapM resolveLine (lines out)
            return $ M.fromList (concat pairs)
        _ -> return M.empty

resolveLine :: String -> IO [(KeySym, Int)]
resolveLine line = case words line of
    ("keycode" : kcStr : "=" : rest) ->
        case reads kcStr of
            [(kc :: Int, _)] -> do
                syms <- mapM stringToKeysymIO rest
                return [(ks, kc) | ks <- mapMaybe id syms, ks /= 0]
            _ -> return []
    _ -> return []

stringToKeysymIO :: String -> IO (Maybe KeySym)
stringToKeysymIO name = do
    let ks = stringToKeysym name
    return (if ks == 0 then Nothing else Just ks)
