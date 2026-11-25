{-# LANGUAGE Haskell2010 #-}
-- one cycle, one unit: A of Haskell 2010, B of 98, and -XRelaxedPolyRec; each holds 4.5.1's case
module A (f, g, h) where
import B (k)

f :: Eq a => a -> Bool
f x = x == x || g True

g :: Ord a => a -> Bool
g y = y < y || f y

h :: Int
h = k 1
