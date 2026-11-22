-- Report 4.3.2: an instance's declarations hold no fixity declaration.
module Main (main) where

class C a where
  (<+>) :: a -> a -> a
instance C Bool where
  infixl 6 <+>
  a <+> _ = a

main :: IO ()
main = return ()
