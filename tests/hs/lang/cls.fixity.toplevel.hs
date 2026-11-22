-- Report 4.4.2: the same method's fixity declared at the top level instead: the same parses.
module Main (main) where

infixl 6 <+>

class C a where
  (<+>) :: a -> a -> a

instance C Int where
  a <+> b = a * 10 + b

main :: IO ()
main = print (1 <+> 2 <+> 3 :: Int, 2 * 3 <+> 4 :: Int)
