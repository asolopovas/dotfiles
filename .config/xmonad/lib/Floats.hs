module Floats
    ( toggleFloat
    , cycleFloatSize
    ) where

import Data.List (find, minimumBy)
import qualified Data.Map as M
import Data.Ord (comparing)
import XMonad
import qualified XMonad.StackSet as W
import XMonad.Util.NamedScratchpad (NamedScratchpad (..))

import Util (centeredRect, shellQuote)

defaultFloat :: W.RationalRect
defaultFloat = centeredRect 0.5

toggleFloat :: X ()
toggleFloat = withFocused $ \w -> do
    floats <- gets (W.floating . windowset)
    if w `M.member` floats
        then windows (W.sink w)
        else windows (W.float w defaultFloat)

floatSizes :: [(String, Double)]
floatSizes = [("small", 0.5), ("medium", 0.7), ("large", 0.9)]

cycleFloatSize :: [NamedScratchpad] -> Int -> X ()
cycleFloatSize sps dir = withFocused $ \w -> do
    floats <- gets (W.floating . windowset)
    let sizes  = map snd floatSizes
        names  = map fst floatSizes
        curW = case M.lookup w floats of
            Just (W.RationalRect _ _ rw _) -> fromRational rw :: Double
            Nothing                        -> 0.7
        curIdx =
            snd $
                minimumBy
                    (comparing fst)
                    [(abs (curW - v), i) | (i, v) <- zip [0 ..] sizes]
        nextIdx = max 0 (min (length sizes - 1) (curIdx + dir))
        newSize = sizes !! nextIdx
        newName = names !! nextIdx
    matched <- matchingScratchpad sps w
    windows (W.float w (centeredRect newSize))
    key <- maybe (runQuery className w) pure matched
    spawn ("scratchpad-resize-persist " ++ shellQuote key ++ " " ++ newName)

matchingScratchpad :: [NamedScratchpad] -> Window -> X (Maybe String)
matchingScratchpad sps w = do
    pairs <- mapM (\sp -> (\matched -> (matched, sp)) <$> runQuery (query sp) w) sps
    pure (name . snd <$> find fst pairs)
