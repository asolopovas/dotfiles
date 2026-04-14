module Screens where

import XMonad
import qualified XMonad.StackSet as W
import XMonad.Layout.IndependentScreens (countScreens)
import Control.Monad (when)

data Direction = Prev | Next

-- Cycle through screens
cycleScreens :: Direction -> X ()
cycleScreens dir = do
    screenCount <- countScreens
    when (screenCount > 0) $ do
        currentScreen <- gets (W.screen . W.current . windowset)
        let offset = case dir of
                        Prev -> -1
                        Next -> 1
        let nextScreen = (currentScreen + offset + screenCount) `mod` screenCount
        screenWorkspace nextScreen >>= flip whenJust (windows . W.view)

-- Shift the current window to the next/previous screen and follow it
shiftAndFollowScreen :: Direction -> X ()
shiftAndFollowScreen dir = do
    screenCount <- countScreens
    when (screenCount > 0) $ do
        currentScreen <- gets (W.screen . W.current . windowset)
        let offset = case dir of
                        Prev -> -1
                        Next -> 1
        let nextScreenId = (currentScreen + offset + screenCount) `mod` screenCount
        screenWorkspace nextScreenId >>= flip whenJust (\ws -> do
            win <- gets (W.peek . windowset)
            case win of
                Just w -> do
                    windows $ W.shift ws
                    windows $ W.view ws
                Nothing -> return ())

fixWorkspaceAssignment :: X ()
fixWorkspaceAssignment = do
    nScreens <- countScreens
    when (nScreens == 2) $ do
        screenWorkspace 1 >>= flip whenJust (windows . W.view)
        windows $ W.view "1_1"
        screenWorkspace 0 >>= flip whenJust (windows . W.view)
    when (nScreens == 3) $ do
        screenWorkspace 1 >>= flip whenJust (windows . W.view)
        windows $ W.view "1_1"
        screenWorkspace 2 >>= flip whenJust (windows . W.view)
        windows $ W.view "2_1"
        screenWorkspace 0 >>= flip whenJust (windows . W.view)
