-- A class's methods, which Main imports with C(..) (build-cache-issues.md,
-- issue 37's A).
module M (C(..), D(..), T(..)) where

data T = T

class C a where
  m :: a -> String

class D a where
  n :: a -> String

instance C T where
  m _ = "m"

instance D T where
  n _ = "n"
