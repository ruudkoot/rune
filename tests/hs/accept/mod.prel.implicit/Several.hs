module Several (s) where

import Prelude (map, Int)
import qualified Prelude as P

s :: [Int]
s = map (P.+ 1) (P.filter P.even [1, 2])
