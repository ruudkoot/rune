module B (b) where

import Klass

instance C T where
  c _ = 2

b :: Int
b = c T
