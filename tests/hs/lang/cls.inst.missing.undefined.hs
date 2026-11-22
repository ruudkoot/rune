-- Report 4.3.2: a method an instance leaves out, with no default, is bottom where used; the other methods work.
module Main (main) where

class K a where
  k1 :: a -> Int
  k2 :: a -> Int

instance K Bool where
  k1 _ = 1

main :: IO ()
main = do
  print (k1 True)
  print (k2 True)
