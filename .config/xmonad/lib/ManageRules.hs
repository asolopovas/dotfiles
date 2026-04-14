{-# LANGUAGE ScopedTypeVariables #-}
module ManageRules (buildManageHook) where

import XMonad
import XMonad.Hooks.ManageHelpers (doCenterFloat, doRectFloat)
import XMonad.Util.NamedScratchpad (namedScratchpadManageHook, NamedScratchpad)
import Data.List (isSuffixOf, isPrefixOf, isInfixOf)
import qualified XMonad.StackSet as W

import Config (WindowRule(..), FloatMode(..), reloadWindowRules)
import WindowLog (logNewWindow)

-- Full manageHook: log new windows, then apply runtime rules from JSON,
-- then scratchpad rules last.
buildManageHook :: [NamedScratchpad] -> ManageHook
buildManageHook scratchpads =
    logNewWindow
    <+> runtimeRules
    <+> namedScratchpadManageHook scratchpads

-- Re-reads window-rules on every new window (cheap — one file stat + tiny
-- JSON parse). This means changes take effect immediately without any
-- xmonad restart.
runtimeRules :: ManageHook
runtimeRules = do
    rules <- liftX (io reloadWindowRules)
    composeAll (map ruleHook rules)

ruleHook :: WindowRule -> ManageHook
ruleHook r =
    matches r --> action r

matches :: WindowRule -> Query Bool
matches r = foldr (<&&>) (pure True)
    [ maybe (pure True) (className =?) (wrClassName r)
    , maybe (pure True) (appName   =?) (wrAppName   r)
    , maybe (pure True) (title     =?) (wrTitle     r)
    , maybe (pure True) (\s -> fmap (isSuffixOf s)  title) (wrTitleSuffix   r)
    , maybe (pure True) (\s -> fmap (isPrefixOf s)  title) (wrTitlePrefix   r)
    , maybe (pure True) (\s -> fmap (isInfixOf s)   title) (wrTitleContains r)
    , maybe (pure True) (\s -> stringProperty "WM_WINDOW_ROLE" =? s) (wrRole r)
    ]

action :: WindowRule -> ManageHook
action r = floatPart <+> shiftPart
  where
    floatPart = case wrFloat r of
        Just FloatCenter            -> doCenterFloat
        Just FloatSmall             -> doRectFloat (centered 0.5)
        Just FloatMedium            -> doRectFloat (centered 0.7)
        Just FloatLarge             -> doRectFloat (centered 0.9)
        Just FloatDefault           -> doFloat
        Just FloatTile              -> idHook
        Just FloatIgnore            -> doIgnore
        Just (FloatCustom x y w h)  -> doRectFloat (mkRect x y w h)
        Nothing                     -> idHook
    shiftPart = maybe idHook doShift (wrWorkspace r)

centered :: Double -> W.RationalRect
centered d = mkRect ((1 - d) / 2) ((1 - d) / 2) d d

mkRect :: Double -> Double -> Double -> Double -> W.RationalRect
mkRect x y w h = W.RationalRect (toRational x) (toRational y) (toRational w) (toRational h)
