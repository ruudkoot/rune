-- m and n swap classes: M exports the same names, and Main's C(..) no
-- longer brings m.
module M (C(..), D(..), T(..)) where

data T = T

class C a where
  n :: a -> String

class D a where
  m :: a -> String

instance C T where
  n _ = "n"

instance D T where
  m _ = "m"
