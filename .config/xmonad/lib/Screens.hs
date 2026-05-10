module Screens
    ( Direction (..)
    , cycleScreens
    , shiftAndFollowScreen
    ) where

import Control.Monad (when)
import XMonad
import XMonad.Layout.IndependentScreens (countScreens)
import qualified XMonad.StackSet as W

data Direction = Prev | Next

offset :: Direction -> ScreenId
offset Prev = -1
offset Next = 1

withNextScreen :: Direction -> (WorkspaceId -> X ()) -> X ()
withNextScreen dir act = do
    n <- countScreens
    when (n > 0) $ do
        cur <- gets (W.screen . W.current . windowset)
        let next = (cur + offset dir + n) `mod` n
        screenWorkspace next >>= flip whenJust act

cycleScreens :: Direction -> X ()
cycleScreens dir = withNextScreen dir (windows . W.view)

shiftAndFollowScreen :: Direction -> X ()
shiftAndFollowScreen dir = withNextScreen dir $ \ws -> do
    windows (W.shift ws)
    windows (W.view ws)
