module BrowserToggle (toggleActiveBrowser, autoRevealBrowserHook) where

import Control.Monad (filterM, when)
import qualified Data.Map.Strict as M
import Data.List (isPrefixOf)

import XMonad
import qualified XMonad.StackSet as W
import qualified XMonad.Util.ExtensibleState as XS
import XMonad.Util.NamedScratchpad (scratchpadWorkspaceTag)
import XMonad.Actions.DynamicWorkspaces (addHiddenWorkspace)

newtype Stash = Stash { sOrigins :: M.Map Window WorkspaceId }

instance ExtensionClass Stash where
    initialValue = Stash M.empty

-- Heuristic: any Chromium-family browser window.
isBrowser :: Query Bool
isBrowser = do
    c <- className
    n <- appName
    let s = map toLowerAscii (c ++ " " ++ n)
    return $ any (`isInfixOfList` s) ["brave", "chrome", "chromium"]
  where
    toLowerAscii ch
        | ch >= 'A' && ch <= 'Z' = toEnum (fromEnum ch + 32)
        | otherwise              = ch
    isInfixOfList needle hay = any (needle `isPrefixOf`) (tails hay)
    tails [] = [[]]
    tails xs@(_:rest) = xs : tails rest

isStashed :: WindowSet -> Window -> Bool
isStashed ws w = W.findTag w ws == Just scratchpadWorkspaceTag

findStashed :: WindowSet -> [Window] -> Maybe Window
findStashed ws bs = case filter (isStashed ws) bs of
    (w:_) -> Just w
    []    -> Nothing

ensureStashWorkspace :: X ()
ensureStashWorkspace = do
    ws <- gets windowset
    let tags = map W.tag (W.workspaces ws)
    when (scratchpadWorkspaceTag `notElem` tags) $
        addHiddenWorkspace scratchpadWorkspaceTag

stash :: Window -> X ()
stash w = do
    ensureStashWorkspace
    ws <- gets windowset
    case W.findTag w ws of
        Just t | t /= scratchpadWorkspaceTag -> do
            XS.modify $ \s -> s { sOrigins = M.insert w t (sOrigins s) }
            windows (W.shiftWin scratchpadWorkspaceTag w)
        _ -> return ()

unstash :: Window -> X ()
unstash w = do
    Stash origins <- XS.get
    ws <- gets windowset
    let target = M.findWithDefault (W.currentTag ws) w origins
    windows (W.focusWindow w . W.shiftWin target w)
    XS.modify $ \s -> s { sOrigins = M.delete w (sOrigins s) }

toggleActiveBrowser :: X ()
toggleActiveBrowser = do
    ws <- gets windowset
    browsers <- filterM (runQuery isBrowser) (W.allWindows ws)
    let mStashed = findStashed ws browsers
        focused  = W.peek ws
    focusedIsBrowser <- maybe (return False) (runQuery isBrowser) focused
    case (mStashed, focused, focusedIsBrowser) of
        (Just s, _, _)                  -> unstash s
        (Nothing, Just f, True)         -> stash f
        _ | null browsers               -> spawn "$BROWSER"
          | otherwise                   -> return ()

-- Called after any user-initiated focus change. If the newly-focused
-- window is a browser and a different browser is stashed, reveal it.
autoRevealBrowserHook :: X ()
autoRevealBrowserHook = do
    ws <- gets windowset
    browsers <- filterM (runQuery isBrowser) (W.allWindows ws)
    let mStashed = findStashed ws browsers
        focused  = W.peek ws
    focusedIsBrowser <- maybe (return False) (runQuery isBrowser) focused
    case (mStashed, focused, focusedIsBrowser) of
        (Just s, Just f, True) | f /= s -> unstash s
        _                                -> return ()
