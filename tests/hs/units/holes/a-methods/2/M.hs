-- C gains a method k, which clashes with Main's own k.
module M (C(..), D(..), T(..)) where

data T = T

class C a where
  m :: a -> String
  k :: a -> String
  k _ = "?"

class D a where
  n :: a -> String

instance C T where
  m _ = "m"

instance D T where
  n _ = "n"
