-- A cycle of two modules (D30): even and odd, unsigned and mutually
-- recursive across them, one binding group; a type group across them,
-- T in A and U in B, each a field of the other; an operator of B's with
-- its fixity used in A; and an instance of A's class at B's type.
module A (T(..), isEven, Shape(..), size) where

import B

data T = T Int U | TEnd

isEven 0 = True
isEven n = isOdd (n - 1)

class Shape a where
  size :: a -> Int

sumT :: T -> Int
sumT TEnd = 0
sumT (T n u) = n <+> sumU u

sumU :: U -> Int
sumU UEnd = 0
sumU (U t) = 1 <+> sumT t <+> 1
