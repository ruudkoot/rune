-- rows: R73
-- Report 4.3.1: a method's context does not constrain the class variable.
module Main (main) where

class C a where
  m :: Eq a => a -> a

main :: IO ()
main = return ()
