-- Report 4.3.2: an instance's declarations hold no type signature.
module Main (main) where

class C a where
  m :: a -> Int
instance C Bool where
  m :: Bool -> Int
  m _ = 0

main :: IO ()
main = return ()
