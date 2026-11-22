-- g beside f: Main's own names stand, since Main imports M qualified
-- alone.
module M (f, g) where

f :: Int
f = 1

g :: Int
g = 4
