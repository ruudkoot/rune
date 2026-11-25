{-# LANGUAGE Haskell2010,
             FooBar #-}
module Main (main) where

f :: Eq a => a -> Bool
f x = x == x || g True

g :: Ord a => a -> Bool
g y = y < y || f y

main :: IO ()
main = print (f 'c', g (1 :: Int))
