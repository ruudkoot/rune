-- On the chain from A to Orphan: its import of Orphan is all that puts
-- Orphan's instance in scope in A.
module Mid where

import Orphan ()

mid :: Int
mid = 0
