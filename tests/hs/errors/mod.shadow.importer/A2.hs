module A2 (null, nonNull) where

import Prelude hiding (null)

null, nonNull :: Int -> Bool
null x = x == 0
nonNull x = not (null x)
