-- Report 4.3.1: an instance of the superclasses is no instance of the subclass: Textual at Int needs its own.
module Main (main) where

class (Read a, Show a) => Textual a where
  t :: a -> String
  t = show

main :: IO ()
main = putStrLn (t (1 :: Int))
