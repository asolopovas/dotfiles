module Floats where

import XMonad
import qualified XMonad.StackSet as W
import qualified Data.Map as M
import XMonad.Util.NamedScratchpad (customFloating)

doNoBorder :: ManageHook
doNoBorder = ask >>= \w -> liftX (withDisplay $ \d -> io $ setWindowBorderWidth d w 0) >> idHook

centerRect :: W.RationalRect
centerRect = W.RationalRect 0.25 0.25 0.5 0.5

-- If the window is floating then (f), if tiled then (n)
floatOrNot :: X () -> X () -> X ()
floatOrNot f n = withFocused $ \windowId -> do
    floats <- gets (W.floating . windowset)
    if windowId `M.member` floats
       then f
       else n

-- Center and float a window (retain size)
centerFloat :: Window -> X ()
centerFloat win = do
    (_, W.RationalRect x y w h) <- floatLocation win
    windows $ W.float win (W.RationalRect ((1 - w) / 1.5) ((1 - h) / 1.5) w h)
    return ()

-- Float a window in the center
centerFloat' :: Window -> X ()
centerFloat' w = windows $ W.float w centerRect

-- Make a window my 'standard size' (half of the screen) keeping the center fixed
standardSize :: Window -> X ()
standardSize win = do
    (_, W.RationalRect x y w h) <- floatLocation win
    windows $ W.float win (W.RationalRect x y 0.5 0.5)
    return ()

-- Float and center a tiled window, sink a floating window
toggleFloat :: X ()
toggleFloat = floatOrNot (withFocused $ windows . W.sink) (withFocused centerFloat')

makeFloat :: Float -> W.RationalRect
makeFloat dim = W.RationalRect
    (toRational ((1 - dim) / 2))
    (toRational ((1 - dim) / 2))
    (toRational dim)
    (toRational dim)

-- Float Definitions for Scratchpads
smFloatCustom, mdFloatCustom, lgFloatCustom :: ManageHook
smFloatCustom = customFloating $ makeFloat 0.5
mdFloatCustom = customFloating $ makeFloat 0.7
lgFloatCustom = customFloating $ makeFloat 0.9

-- Float Definitions for Window Rules
smFloat, mdFloat, lgFloat, helpFloat :: W.RationalRect
smFloat   = makeFloat 0.5
mdFloat   = makeFloat 0.7
lgFloat   = makeFloat 0.9
helpFloat = W.RationalRect 0.25 0.1 0.5 0.8
