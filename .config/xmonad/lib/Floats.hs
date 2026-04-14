module Floats (toggleFloat) where

import XMonad
import qualified XMonad.StackSet as W
import qualified Data.Map as M

centerRect :: W.RationalRect
centerRect = W.RationalRect 0.25 0.25 0.5 0.5

floatOrNot :: X () -> X () -> X ()
floatOrNot f n = withFocused $ \wid -> do
    floats <- gets (W.floating . windowset)
    if wid `M.member` floats then f else n

centerFloat' :: Window -> X ()
centerFloat' w = windows $ W.float w centerRect

-- Float a tiled window in the center, or sink a floating one.
toggleFloat :: X ()
toggleFloat = floatOrNot (withFocused $ windows . W.sink) (withFocused centerFloat')
