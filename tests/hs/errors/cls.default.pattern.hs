-- Report 4.3.1: a default method's left side is no pattern: not (op1, op2) = ... in a class.
module Main (main) where

class Foo a where
  op1, op2 :: a -> a
  (op1, op2) = (id, id)

main :: IO ()
main = return ()
