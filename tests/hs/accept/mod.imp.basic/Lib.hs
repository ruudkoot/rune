module Lib (z, w, T(..), U(..), C(..), D(..), (+++)) where

z :: Int
z = 1

w :: Int
w = 2

data T = A | B { fld :: Int }
data U = U

class C a where
  cm :: a -> Int
class D a where
  dm :: a -> Int

instance C Bool where
  cm _ = 0
instance D Bool where
  dm _ = 1

(+++) :: Int -> Int -> Int
a +++ b = a + b
