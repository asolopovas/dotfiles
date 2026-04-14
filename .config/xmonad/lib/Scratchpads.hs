module Scratchpads (buildScratchpads) where

import XMonad
import XMonad.Util.NamedScratchpad
import qualified XMonad.StackSet as W

import Config (Scratchpad(..), FloatMode(..))

buildScratchpads :: [Scratchpad] -> [NamedScratchpad]
buildScratchpads = map toNS

toNS :: Scratchpad -> NamedScratchpad
toNS sp = NS (spName sp) (spCommand sp) (matcher sp) (floater (spFloat sp))

matcher :: Scratchpad -> Query Bool
matcher sp = case spMatchBy sp of
    "title"     -> title     =? spMatch sp
    "appName"   -> appName   =? spMatch sp
    "className" -> className =? spMatch sp
    _           -> className =? spMatch sp

floater :: FloatMode -> ManageHook
floater FloatCenter         = customFloating (rect 0.25 0.25 0.5 0.5)
floater FloatSmall          = customFloating (centeredRect 0.5)
floater FloatMedium         = customFloating (centeredRect 0.7)
floater FloatLarge          = customFloating (centeredRect 0.9)
floater FloatTile           = nonFloating
floater FloatDefault        = customFloating (centeredRect 0.7)
floater FloatIgnore         = nonFloating
floater (FloatCustom x y w h) = customFloating (rect x y w h)

centeredRect :: Double -> W.RationalRect
centeredRect d = rect ((1 - d) / 2) ((1 - d) / 2) d d

rect :: Double -> Double -> Double -> Double -> W.RationalRect
rect x y w h = W.RationalRect (toRational x) (toRational y) (toRational w) (toRational h)
