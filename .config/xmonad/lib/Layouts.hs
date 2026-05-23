{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeSynonymInstances #-}

module Layouts
    ( layoutHook
    , resetLayout
    ) where

import XMonad hiding (layoutHook)
import qualified XMonad as X
import XMonad.Config.Desktop (desktopLayoutModifiers)
import XMonad.Layout.IfMax (ifMax)
import qualified XMonad.Layout.LayoutModifier as LM
import XMonad.Layout.LimitWindows (limitWindows)
import XMonad.Layout.MultiToggle (mkToggle, single)
import XMonad.Layout.MultiToggle.Instances (StdTransformers (MIRROR))
import XMonad.Layout.NoBorders (noBorders)
import XMonad.Layout.PerWorkspace (onWorkspaces)
import XMonad.Layout.Reflect (reflectHoriz)
import XMonad.Layout.Renamed (Rename (Replace), renamed)
import XMonad.Layout.ResizableTile (ResizableTall (..))
import XMonad.Layout.Spacing (Border (..), Spacing, spacingRaw)
import qualified XMonad.Layout.ToggleLayouts as T
import qualified XMonad.StackSet as W

terminalClasses :: [String]
terminalClasses = ["Alacritty", "kitty", "Kitty", "st-256color", "URxvt", "XTerm"]

centeredInside :: Rational -> Rational -> Rectangle -> Rectangle
centeredInside wr hr (Rectangle sx sy sw sh) =
    let w = floor (fromIntegral sw * wr :: Rational)
        h = floor (fromIntegral sh * hr :: Rational)
        x = sx + fromIntegral ((fromIntegral sw - w) `div` 2)
        y = sy + fromIntegral ((fromIntegral sh - h) `div` 2)
    in  Rectangle x y (fromIntegral w) (fromIntegral h)

data CenterMidIf a = CenterMidIf [String] Rational Rational deriving (Show, Read)

instance LayoutClass CenterMidIf Window where
    doLayout (CenterMidIf classes wr hr) screenRect stack = do
        let ws = W.integrate stack
        case ws of
            [w] -> do
                cls <- runQuery className w
                let r = if cls `elem` classes
                            then centeredInside wr hr screenRect
                            else screenRect
                pure ([(w, r)], Nothing)
            _ -> pure (zip ws (repeat screenRect), Nothing)
    description _ = "CenterMidIf"

evenSpacing :: Integer -> l a -> LM.ModifiedLayout Spacing l a
evenSpacing i = spacingRaw False (Border i i i i) True (Border i i i i) True

baseTile :: ResizableTall Window
baseTile = ResizableTall 1 (3 / 100) (1 / 2) []

tiled =
    renamed [Replace "tiled"]
        $ mkToggle (single MIRROR)
        $ limitWindows 12
        $ evenSpacing 5
        $ ifMax 1 (CenterMidIf terminalClasses (7 / 10) (4 / 5)) baseTile

tiledR =
    renamed [Replace "tiledR"]
        $ mkToggle (single MIRROR)
        $ limitWindows 12
        $ evenSpacing 5
        $ reflectHoriz
        $ ifMax 1 (CenterMidIf terminalClasses (7 / 10) (4 / 5)) baseTile

full =
    renamed [Replace "full"] $
        noBorders Full

screenWorkspaces :: Int -> [String]
screenWorkspaces s =
    [ show s ++ "_" ++ show n
    | n <- [1 .. 9 :: Int]
    ]
        ++ [show s ++ "_7:chat"]

layoutHook =
    desktopLayoutModifiers $
        T.toggleLayouts full $
            onWorkspaces (screenWorkspaces 1) tiled $
                onWorkspaces (screenWorkspaces 0) tiledR tiled

resetLayout :: X ()
resetLayout = do
    layout <- asks (X.layoutHook . config)
    setLayout layout
    refresh
