module A (T(..), useA) where

import B (U(..))

data T = T Int

useA :: String
useA = show (U 1)
