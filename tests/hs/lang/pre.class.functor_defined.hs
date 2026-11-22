-- rows: pre.class.functor pre.class.functor.fmap
-- Report 8: class Functor has fmap and no default.
module Main (main) where

data T a = T a a deriving Show
instance Functor T where
  fmap f (T x y) = T (f y) (f x)

main :: IO ()
main = print (fmap (+ 1) (T 1 (2 :: Int)))
