-- Generalised bindings (4.5): a pattern binding whose variables are polymorphic, functions that call each other, one of
-- no signature, a class's default of no argument, polymorphic recursion through a signature, a local function used
-- at two types, and a lambda whose case has guards.
module Main (main) where

(idA, idB) = (\x -> x, \y -> y)

evenL :: [a] -> Bool
evenL [] = True
evenL (_ : xs) = oddL xs

oddL [] = False
oddL (_ : xs) = evenL xs

class Def a where
  def :: a
  defs :: [a]
  defs = [def, def]

instance Def Int where
  def = 7

data Nest a = Flat a | Nested (Nest [a])

depth :: Nest a -> Int
depth (Flat _) = 0
depth (Nested n) = 1 + depth n

total :: Show a => a -> Int -> String
total x 0 = show x
total x n = total [x] (n - 1)

twice :: (Int, Integer)
twice = let dbl x = x + x in (dbl 3, dbl 4)

k :: Int -> Int
k = \x -> case x of
  0 -> 1
  n | even n -> n `div` 2
    | otherwise -> k (n - 1)

main :: IO ()
main = do
  print (idA (1 :: Int), idB [2 :: Int])
  putStrLn (if evenL "abcd" then "even" else "odd")
  print (defs :: [Int])
  print (depth (Nested (Nested (Flat [[1 :: Int]]))))
  putStrLn (total (1 :: Int) 2)
  print twice
  print (map k [0, 4, 7])
