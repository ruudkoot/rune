-- N's Read instance, in scope where a chain of imports leads here (5.4).
module Orphan where

import N

instance Read N where
  readsPrec d s = [(N k, r) | (k, r) <- readsPrec d s]
