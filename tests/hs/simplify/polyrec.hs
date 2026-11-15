-- Polymorphic recursion (Augustsson 1993, fig 9): f at [a] calls itself at
-- [[a]], so the dictionaries it is given have no end, and specialisation
-- stops at its fuel. It compiles at -O2 and prints what -O0 prints.
module Main where

f :: Eq a => a -> a
f x = if x == x then x else head (f [x])

data Nested a = Flat a | Nest (Nested [a])

depth :: Show a => Nested a -> String
depth (Flat x) = show x
depth (Nest n) = "[" ++ depth n ++ "]"

nested :: Int -> a -> Nested a
nested 0 x = Flat x
nested n x = Nest (nested (n - 1) [x])

main :: IO ()
main = do
  print (f (3 :: Int), f "abc")
  putStrLn (depth (nested 3 'x'))
  putStrLn (depth (nested 5 (1 :: Int)))
