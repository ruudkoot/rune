-- Report 4.3.1: a default is given only for the class's methods: not another name.
module Main (main) where

class C a where
  m :: a -> a
  other x = x

main :: IO ()
main = return ()
