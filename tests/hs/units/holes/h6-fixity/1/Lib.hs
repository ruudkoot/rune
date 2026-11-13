-- H6: <+>'s fixity, which Main's expression is read by.
module Lib where

infixl 6 <+>

(<+>) :: Int -> Int -> Int
a <+> b = a - b
