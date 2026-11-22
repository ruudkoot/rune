module A2 ( C.f, C.g, g, module B ) where

import B (f)
import qualified C (f, g)

g :: Int
g = C.f + C.g
