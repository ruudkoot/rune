-- Known dictionaries and their specialisation (M23, D49): overloaded
-- functions of the Prelude and of the program, at several types, with
-- superclasses and default methods, each printing what -O0 prints.
-- fuel: every lint holds and it prints the same whatever rewrite it stops after
module Main where

class Shape a where
  area :: a -> Double
  name :: a -> String
  describe :: a -> String
  describe x = name x ++ " of area " ++ show (area x)

data Square = Square Double
data Circle = Circle Double

instance Shape Square where
  area (Square s) = s * s
  name _ = "square"

instance Shape Circle where
  area (Circle r) = 3 * r * r
  name _ = "circle"
  describe c = "a round " ++ name c

class (Eq a) => Container a where
  empty :: a
  insert :: Int -> a -> a
  toL :: a -> [Int]

newtype Stack = Stack [Int]
instance Eq Stack where
  Stack a == Stack b = a == b
instance Container Stack where
  empty = Stack []
  insert x (Stack xs) = Stack (x : xs)
  toL (Stack xs) = xs

fill :: Container a => [Int] -> a
fill = foldr insert empty

same :: Container a => a -> a -> Bool
same a b = a == b && toL a == toL b

total :: (Num a) => [a] -> a
total xs = go 0 xs
  where go acc [] = acc
        go acc (y:ys) = go (acc + y) ys

pairUp :: (Show a, Show b) => a -> b -> String
pairUp a b = "(" ++ show a ++ "," ++ show b ++ ")"

main :: IO ()
main = do
  print (sum [1 .. 100 :: Int], sum [1 .. 100 :: Integer])
  print (product [1 .. 10 :: Int], product [1 .. 20 :: Integer])
  print (total [1, 2, 3 :: Int], total [1.5, 2.5 :: Double])
  print (elem 3 [1, 2, 3 :: Int], elem 'z' "abc")
  print (maximum [3, 1, 4, 1, 5, 9, 2, 6 :: Int], minimum "hello")
  putStrLn (describe (Square 2))
  putStrLn (describe (Circle 1))
  print (toL (fill [1, 2, 3] :: Stack))
  print (same (fill [1, 2] :: Stack) (insert 1 (insert 2 empty)), same (fill [1] :: Stack) empty)
  putStrLn (pairUp (1 :: Int) True ++ pairUp "x" [2 :: Integer, 3])
  print (map (\x -> x * x) [1, 2, 3 :: Integer], [x + 1 | x <- [1, 2, 3 :: Int], odd x])
  print (show (Just (3 :: Int)), read "[1,2,3]" :: [Int])
  print (compare (1 :: Int) 2, compare "b" "a", max (Just 'a') Nothing)
