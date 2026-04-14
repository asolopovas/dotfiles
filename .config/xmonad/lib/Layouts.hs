module Layouts (myLayout, resetLayout) where

import XMonad
import XMonad.Config.Desktop (desktopLayoutModifiers)
import XMonad.Layout.ResizableTile
import XMonad.Layout.Reflect
import XMonad.Layout.PerWorkspace (onWorkspaces)
import XMonad.Layout.Spacing
import qualified XMonad.Layout.LayoutModifier
import XMonad.Layout.NoBorders (noBorders, smartBorders)
import XMonad.Layout.LimitWindows (limitWindows)
import XMonad.Layout.Renamed (renamed, Rename(Replace))
import XMonad.Layout.MultiToggle (mkToggle, single)
import XMonad.Layout.MultiToggle.Instances (StdTransformers(MIRROR))
import qualified XMonad.Layout.ToggleLayouts as T (toggleLayouts)

mySpacing :: Integer -> l a -> XMonad.Layout.LayoutModifier.ModifiedLayout Spacing l a
mySpacing i = spacingRaw False (Border i i i i) True (Border i i i i) True

tiled  = renamed [Replace "tiled"]
       $ mkToggle (single MIRROR)
       $ smartBorders
       $ limitWindows 12
       $ mySpacing 5
       $ ResizableTall 1 (3/100) (1/2) []

tiledR = renamed [Replace "tiledR"]
       $ mkToggle (single MIRROR)
       $ smartBorders
       $ limitWindows 12
       $ mySpacing 5
       $ reflectHoriz
       $ ResizableTall 1 (3/100) (1/2) []

full   = renamed [Replace "full"]
       $ noBorders
       $ Full

myLayout = desktopLayoutModifiers
         $ T.toggleLayouts full
         $ onWorkspaces ["1_1", "1_2", "1_3", "1_4", "1_5", "1_6", "1_7:chat", "1_8", "1_9"] tiled
         $ onWorkspaces ["0_1", "0_2", "0_3", "0_4", "0_5", "0_6", "0_7:chat", "0_8", "0_9"] tiledR
         $ myDefaultLayout
  where
    myDefaultLayout = tiled

-- Reset layout to default (fresh from config, clears resize ratios and mirror)
resetLayout :: X ()
resetLayout = do
    layout <- asks (XMonad.layoutHook . XMonad.config)
    setLayout layout
    refresh
