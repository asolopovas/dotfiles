module Events (handleEventHook) where

import Data.Monoid (All (..))
import XMonad hiding (handleEventHook)
import XMonad.Hooks.WindowSwallowing (swallowEventHook)

import Config (WindowRule, matchesRule, reloadSwallowExclusions)

handleEventHook :: Event -> X All
handleEventHook ev =
    swallowEventHook terminalWindow swallowableWindow ev
        `catchX` pure (All True)

terminalWindow :: Query Bool
terminalWindow = className =? "Alacritty"

swallowableWindow :: Query Bool
swallowableWindow = do
    cls  <- className
    name <- appName
    let hardcoded = cls /= "Polybar" && cls /= "polybar" && name /= "polybar"
    if not hardcoded
        then pure False
        else do
            rules <- liftX (io reloadSwallowExclusions)
            excluded <- anyRuleMatches rules
            pure (not excluded)

anyRuleMatches :: [WindowRule] -> Query Bool
anyRuleMatches []     = pure False
anyRuleMatches (r:rs) = do
    m <- matchesRule r
    if m then pure True else anyRuleMatches rs
