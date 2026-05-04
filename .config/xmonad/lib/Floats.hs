module Floats (toggleFloat, cycleFloatSize) where

import XMonad
import qualified XMonad.StackSet as W
import qualified Data.Map as M
import Data.List (minimumBy, find)
import Data.Ord (comparing)
import XMonad.Util.NamedScratchpad (NamedScratchpad(..))

centerRect :: W.RationalRect
centerRect = W.RationalRect 0.25 0.25 0.5 0.5

floatOrNot :: X () -> X () -> X ()
floatOrNot f n = withFocused $ \wid -> do
    floats <- gets (W.floating . windowset)
    if wid `M.member` floats then f else n

centerFloat' :: Window -> X ()
centerFloat' w = windows $ W.float w centerRect

toggleFloat :: X ()
toggleFloat = floatOrNot (withFocused $ windows . W.sink) (withFocused centerFloat')

floatSizes :: [(String, Double)]
floatSizes = [("small", 0.5), ("medium", 0.7), ("large", 0.9)]

centeredRect :: Double -> W.RationalRect
centeredRect d = W.RationalRect (toRational ((1 - d) / 2)) (toRational ((1 - d) / 2)) (toRational d) (toRational d)

cycleFloatSize :: [NamedScratchpad] -> Int -> X ()
cycleFloatSize sps dir = withFocused $ \w -> do
    floats <- gets (W.floating . windowset)
    let sizes  = map snd floatSizes
        names  = map fst floatSizes
        curW   = case M.lookup w floats of
                     Just (W.RationalRect _ _ rw _) -> fromRational rw :: Double
                     Nothing                        -> 0.7
        curIdx = snd $ minimumBy (comparing fst)
                    [(abs (curW - v), i) | (i, v) <- zip [0..] sizes]
        nextIdx = max 0 (min (length sizes - 1) (curIdx + dir))
        newSize = sizes  !! nextIdx
        newName = names  !! nextIdx
    matched <- matchingScratchpad sps w
    windows (W.float w (centeredRect newSize))
    case matched of
        Just spName -> spawn ("scratchpad-resize-persist " ++ shellQuote spName ++ " " ++ newName)
        Nothing     -> do
            cls <- runQuery className w
            spawn ("scratchpad-resize-persist " ++ shellQuote cls ++ " " ++ newName)
  where
    shellQuote s = '\'' : concatMap esc s ++ "'"
    esc '\'' = "'\\''"
    esc c    = [c]

matchingScratchpad :: [NamedScratchpad] -> Window -> X (Maybe String)
matchingScratchpad sps w = do
    pairs <- mapM (\sp -> do { b <- runQuery (query sp) w; return (b, sp) }) sps
    return (fmap (name . snd) (find (\(b, _) -> b) pairs))
