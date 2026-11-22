module A (a) where

import Klass

instance C T where
  c _ = 1

a :: Int
a = c T
