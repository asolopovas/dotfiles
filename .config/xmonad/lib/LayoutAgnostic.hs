module LayoutAgnostic
    ( withLayoutAgnosticKeys
    ) where

import qualified Data.Map.Strict as M
import XMonad

withLayoutAgnosticKeys :: XConfig l -> XConfig l
withLayoutAgnosticKeys c = c { keys = \cfg -> expandKeys (keys c cfg) }

expandKeys :: M.Map (KeyMask, KeySym) (X ()) -> M.Map (KeyMask, KeySym) (X ())
expandKeys original = M.union original (M.fromList extras)
  where
    extras =
        [ ((mask, alt), act)
        | ((mask, ks), act) <- M.toList original
        , alt <- russianAlternate ks
        ]

russianAlternate :: KeySym -> [KeySym]
russianAlternate ks = maybe [] pure (M.lookup ks russianKeys)

russianKeys :: M.Map KeySym KeySym
russianKeys = M.fromList (zip latinKeys cyrillicKeys)
  where
    latinKeys = map (fromIntegral . fromEnum) ("qwertyuiopasdfghjklzxcvbnm" :: String)
    cyrillicKeys =
        [ 0x06ca, 0x06c3, 0x06d5, 0x06cb, 0x06c5, 0x06ce, 0x06c7, 0x06db, 0x06dd, 0x06da
        , 0x06c6, 0x06d9, 0x06d7, 0x06c1, 0x06d0, 0x06d2, 0x06cf, 0x06cc, 0x06c4
        , 0x06d1, 0x06de, 0x06d3, 0x06cd, 0x06c9, 0x06d4, 0x06d8
        ]
