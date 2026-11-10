module B (U(..), isOdd, (<+>)) where

import A

infixr 5 <+>

data U = U T | UEnd

isOdd 0 = False
isOdd n = isEven (n - 1)

(<+>) :: Int -> Int -> Int
a <+> b = a + b * 2

instance Shape U where
  size UEnd = 0
  size (U _) = 1
