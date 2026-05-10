{-# LANGUAGE OverloadedStrings #-}
module FloatMode
    ( FloatMode (..)
    , parseFloat
    ) where

import Data.Aeson (FromJSON (..), Value (..), withObject, (.:))
import qualified Data.Text as T

data FloatMode
    = FloatCenter
    | FloatSmall
    | FloatMedium
    | FloatLarge
    | FloatDefault
    | FloatTile
    | FloatIgnore
    | FloatCustom Double Double Double Double
    deriving (Show, Eq)

parseFloat :: T.Text -> Maybe FloatMode
parseFloat t = case T.toLower t of
    "center" -> Just FloatCenter
    "small"  -> Just FloatSmall
    "sm"     -> Just FloatSmall
    "medium" -> Just FloatMedium
    "md"     -> Just FloatMedium
    "large"  -> Just FloatLarge
    "lg"     -> Just FloatLarge
    "float"  -> Just FloatDefault
    "tile"   -> Just FloatTile
    "none"   -> Just FloatTile
    "ignore" -> Just FloatIgnore
    _        -> Nothing

instance FromJSON FloatMode where
    parseJSON (String t) =
        maybe (fail $ "Unknown float mode: " ++ T.unpack t) pure (parseFloat t)
    parseJSON (Object o) =
        FloatCustom <$> o .: "x" <*> o .: "y" <*> o .: "w" <*> o .: "h"
    parseJSON _ = fail "float must be string or {x,y,w,h} object"
