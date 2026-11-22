-- Report 4.4.1, 4.5.2: a function on a nested datatype, typed by its signature and so polymorphically recursive, takes
-- a dictionary at each level and ends on a finite value.
module Main (main) where

data Nested a = Flat a | Nest (Nested [a])

showN :: (Show a) => Nested a -> String
showN (Flat x) = show x
showN (Nest n) = showN n

depth :: Nested a -> Int
depth (Flat _) = 0
depth (Nest n) = 1 + depth n

main :: IO ()
main = do
  putStrLn (showN (Nest (Nest (Flat [[1, 2], [3 :: Int]]))))
  print (depth (Nest (Nest (Flat [[True]]))))
