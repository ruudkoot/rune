module T1 (map, module P) where
import Prelude hiding (map, Maybe(Just))
import qualified Prelude as P (map, Maybe(..))
map f = P.map f
j = P.Just 1
