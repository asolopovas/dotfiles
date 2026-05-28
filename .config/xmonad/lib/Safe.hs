{-# LANGUAGE ScopedTypeVariables #-}
module Safe
    ( safeRunQuery
    , silentCatchX
    ) where

import Control.Exception (SomeException, try)
import Control.Monad.Reader (ask)
import Control.Monad.State (get, put)
import XMonad

silentCatchX :: forall a. X a -> X a -> X a
silentCatchX job errcase = do
    st <- get
    conf <- ask
    res <- io (try (runX conf st job) :: IO (Either SomeException (a, XState)))
    case res of
        Right (a, st') -> do
            put st'
            pure a
        Left _ -> errcase

safeRunQuery :: a -> Query a -> Window -> X a
safeRunQuery fallback q w = silentCatchX (runQuery q w) (pure fallback)
