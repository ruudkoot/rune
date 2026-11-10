-- Report 4.6: an instance has its class's kind: not C Int for C over * -> *.
module Main (main) where

class C f where
  m :: f a -> a

instance C Int where
  m = undefined

main :: IO ()
main = return ()
