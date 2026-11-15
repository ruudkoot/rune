-- infixr: 10 <+> (3 <+> 2).
module Lib where

infixr 6 <+>

(<+>) :: Int -> Int -> Int
a <+> b = a - b
