{-# LANGUAGE Haskell2010 #-}
-- a module of Haskell 2010 in a program of 98: 4.5.1's relaxed dependency analysis
module A (f, g) where

f :: Eq a => a -> Bool
f x = x == x || g True

g :: Ord a => a -> Bool
g y = y < y || f y
