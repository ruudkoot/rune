module M (C(..), T(..)) where

class C a where
  c :: a -> Int

data T = C
