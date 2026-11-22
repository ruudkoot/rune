-- Report 4.3.2: nor a synonym that would expand to a legal head: type L = [].
module Main (main) where

type L = []
class K f where
  k :: f a -> Int
instance K L where
  k _ = 0

main :: IO ()
main = return ()
