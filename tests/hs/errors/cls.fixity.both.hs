-- Report 4.3.1, 4.4.2: one fixity declaration for an operator, so not in the class and at the top too.
module Main (main) where

infixl 6 <+>

class C a where
  infixl 6 <+>
  (<+>) :: a -> a -> a

main :: IO ()
main = return ()
