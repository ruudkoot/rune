-- Report 4.6: a class and its superclass agree on the variable's kind.
module Main (main) where

class Functor f => C f where
  m :: f -> Int

main :: IO ()
main = return ()
