module T1 (mapp, module P) where
import Prelude hiding (Maybe(Just))
import qualified Prelude as P (map, Maybe(..))
mapp f = P.map f
j = P.Just 1
