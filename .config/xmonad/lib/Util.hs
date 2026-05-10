module Util
    ( centeredRect
    , rect
    , shellQuote
    ) where

import qualified XMonad.StackSet as W

centeredRect :: Double -> W.RationalRect
centeredRect d = rect ((1 - d) / 2) ((1 - d) / 2) d d

rect :: Double -> Double -> Double -> Double -> W.RationalRect
rect x y w h =
    W.RationalRect (toRational x) (toRational y) (toRational w) (toRational h)

shellQuote :: String -> String
shellQuote s = '\'' : concatMap esc s ++ "'"
  where
    esc '\'' = "'\\''"
    esc c    = [c]
