module BrowserToggle
    ( toggleActiveBrowser
    , autoRevealBrowserHook
    ) where

import Control.Monad (filterM, when)
import Data.Char (toLower)
import Data.List (isInfixOf, partition)
import qualified Data.Map.Strict as M
import XMonad
import XMonad.Actions.DynamicWorkspaces (addHiddenWorkspace)
import qualified XMonad.StackSet as W
import qualified XMonad.Util.ExtensibleState as XS
import XMonad.Util.NamedScratchpad (scratchpadWorkspaceTag)

newtype Stash = Stash {sOrigins :: M.Map Window WorkspaceId}

instance ExtensionClass Stash where
    initialValue = Stash M.empty

isBrowser :: Query Bool
isBrowser = do
    c <- className
    n <- appName
    let s = map toLower (c ++ " " ++ n)
    pure (any (`isInfixOf` s) ["brave", "chrome", "chromium"])

isStashed :: WindowSet -> Window -> Bool
isStashed ws w = W.findTag w ws == Just scratchpadWorkspaceTag

ensureStashWorkspace :: X ()
ensureStashWorkspace = do
    ws <- gets windowset
    let tags = map W.tag (W.workspaces ws)
    when (scratchpadWorkspaceTag `notElem` tags) $
        addHiddenWorkspace scratchpadWorkspaceTag

-- The workspace a browser "belongs to": its current workspace if visible,
-- or its recorded origin if stashed. Orphan stashed browsers (no origin
-- recorded — e.g. after xmonad restart) return Nothing.
browserWorkspace :: WindowSet -> M.Map Window WorkspaceId -> Window -> Maybe WorkspaceId
browserWorkspace ws origins w
    | isStashed ws w = M.lookup w origins
    | otherwise      = W.findTag w ws

stash :: Window -> X ()
stash w = do
    ensureStashWorkspace
    ws <- gets windowset
    case W.findTag w ws of
        Just t | t /= scratchpadWorkspaceTag -> do
            XS.modify $ \s -> s {sOrigins = M.insert w t (sOrigins s)}
            windows (W.shiftWin scratchpadWorkspaceTag w)
        _ -> pure ()

unstash :: Window -> X ()
unstash w = do
    ws <- gets windowset
    let target = W.currentTag ws
    windows (W.focusWindow w . W.shiftWin target w)
    XS.modify $ \s -> s {sOrigins = M.delete w (sOrigins s)}

-- A browser is "owned" by the current workspace if its workspace tag
-- matches, OR it is an orphan stashed browser (no origin) — so users can
-- reclaim orphans after an xmonad restart.
ownedByCurrent :: WorkspaceId -> WindowSet -> M.Map Window WorkspaceId -> [Window] -> [Window]
ownedByCurrent tag ws origins = filter own
  where
    own w = case browserWorkspace ws origins w of
        Just t  -> t == tag
        Nothing -> isStashed ws w

toggleActiveBrowser :: X ()
toggleActiveBrowser = do
    ws <- gets windowset
    allBrowsers <- filterM (runQuery isBrowser) (W.allWindows ws)
    let tag = W.currentTag ws
        onCurrent = filter ((== Just tag) . flip W.findTag ws) allBrowsers
        stashedAny = filter (isStashed ws) allBrowsers
        elsewhere = filter (\w -> let t = W.findTag w ws in t /= Just tag && t /= Just scratchpadWorkspaceTag) allBrowsers
    case (onCurrent, stashedAny, elsewhere) of
        (v : _, _, _)    -> stash v
        (_, s : _, _)    -> unstash s
        (_, _, e : _)    -> windows (W.focusWindow e . W.shiftWin tag e)
        _                -> pure ()

autoRevealBrowserHook :: X ()
autoRevealBrowserHook = do
    ws <- gets windowset
    Stash origins <- XS.get
    allBrowsers <- filterM (runQuery isBrowser) (W.allWindows ws)
    let tag = W.currentTag ws
        ownedStashed =
            filter (isStashed ws) (ownedByCurrent tag ws origins allBrowsers)
        focused = W.peek ws
    focusedIsBrowser <- maybe (pure False) (runQuery isBrowser) focused
    case (ownedStashed, focused, focusedIsBrowser) of
        (s : _, Just f, True) | f /= s -> unstash s
        _                              -> pure ()
