module MyPrelude (module Prelude, (++)) where

import Prelude hiding ((++))
import qualified Prelude as P

(++) :: [a] -> [a] -> [a]
xs ++ ys = ys P.++ xs
