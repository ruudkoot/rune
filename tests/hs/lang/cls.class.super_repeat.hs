-- Report 4.3.1 and 4.1.3: a class's context is a set of assertions, and one that names Eq twice gives the class
-- one superclass Eq; compiled whole or in units, against the snapshot, alike.
module Main (main) where

class (Eq a, Show a, Eq a) => C a where
  c :: a -> String
  c x = if x == x then show x else ""

instance C Int

f :: C a => a -> a -> String
f x y = if x == y then c x else show y

main :: IO ()
main = putStrLn (f (1 :: Int) 1) >> putStrLn (f (2 :: Int) 3)
