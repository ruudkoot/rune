-- Report 4.3.4: all the classes are the Prelude's or a standard library's: a user class stops defaulting (R22).
module Main (main) where

class C a where
  cc :: a -> Int
instance C Integer where
  cc _ = 0

c :: (C a, Num a) => a -> Int
c = cc

main :: IO ()
main = print (c 1)
