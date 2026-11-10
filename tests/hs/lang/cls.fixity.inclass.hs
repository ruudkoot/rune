-- Report 4.3.1, 4.4.2: a fixity declaration in a class body gives its infix method that fixity: infixl 6 <+>.
module Main (main) where

class C a where
  infixl 6 <+>
  (<+>) :: a -> a -> a

instance C Int where
  a <+> b = a * 10 + b

main :: IO ()
main = print (1 <+> 2 <+> 3 :: Int, 2 * 3 <+> 4 :: Int)
