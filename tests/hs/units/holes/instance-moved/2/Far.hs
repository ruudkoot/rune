-- Show T's instance, the same, moved here, where A's imports do not reach:
-- A, unedited, is refused, as a whole compile refuses it, not taken from
-- the store with the instance it found in Orphan.
module Far where

import T

far :: Int
far = 1

instance Show T where
  show _ = "orphan"
