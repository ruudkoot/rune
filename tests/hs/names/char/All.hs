-- A program whose module Char is its own: All sees the program's Char, and
-- the library's modules theirs.
module All () where

import Char (Shout, shout, toUpper)
import qualified Time

greeting :: Shout
greeting = shout (map toUpper "hello")
