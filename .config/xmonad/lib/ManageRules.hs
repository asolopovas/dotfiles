module ManageRules (buildManageHook) where

import Data.List (isInfixOf, isPrefixOf, isSuffixOf)
import XMonad
import XMonad.Hooks.ManageHelpers (doCenterFloat, doRectFloat)
import XMonad.Util.NamedScratchpad (NamedScratchpad, namedScratchpadManageHook)

import Config (WindowRule (..), reloadWindowRules)
import FloatMode (FloatMode (..))
import Util (centeredRect, rect)
import WindowLog (logNewWindow)

buildManageHook :: [NamedScratchpad] -> ManageHook
buildManageHook scratchpads =
    logNewWindow
        <+> runtimeRules
        <+> namedScratchpadManageHook scratchpads

runtimeRules :: ManageHook
runtimeRules = do
    rules <- liftX (io reloadWindowRules)
    composeAll (map ruleHook rules)

ruleHook :: WindowRule -> ManageHook
ruleHook r = matches r --> action r

matches :: WindowRule -> Query Bool
matches r =
    foldr
        (<&&>)
        (pure True)
        [ maybe (pure True) (className =?) (wrClassName r)
        , maybe (pure True) (appName   =?) (wrAppName   r)
        , maybe (pure True) (title     =?) (wrTitle     r)
        , maybe (pure True) (\s -> isSuffixOf s <$> title) (wrTitleSuffix   r)
        , maybe (pure True) (\s -> isPrefixOf s <$> title) (wrTitlePrefix   r)
        , maybe (pure True) (\s -> isInfixOf  s <$> title) (wrTitleContains r)
        , maybe (pure True) (stringProperty "WM_WINDOW_ROLE" =?) (wrRole r)
        ]

action :: WindowRule -> ManageHook
action r = floatPart <+> shiftPart
  where
    floatPart = case wrFloat r of
        Just FloatCenter           -> doCenterFloat
        Just FloatSmall            -> doRectFloat (centeredRect 0.5)
        Just FloatMedium           -> doRectFloat (centeredRect 0.7)
        Just FloatLarge            -> doRectFloat (centeredRect 0.9)
        Just FloatDefault          -> doFloat
        Just FloatTile             -> idHook
        Just FloatIgnore           -> doIgnore
        Just (FloatCustom x y w h) -> doRectFloat (rect x y w h)
        Nothing                    -> idHook
    shiftPart = maybe idHook doShift (wrWorkspace r)
