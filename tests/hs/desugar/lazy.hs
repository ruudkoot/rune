-- Lazy patterns (3.17.2, rule (d)): ~p matches anything and forces nothing; each of its variables is a match of its
-- own, made when the variable is forced. An as-pattern binds the whole (rule (e)).
module Main (main) where

lazyPair :: (Int, Int) -> Int
lazyPair ~(_, _) = 1

lazyFirst :: (Int, Int) -> Int
lazyFirst ~(a, _) = a + 1

swap' :: (Int, Int) -> (Int, Int)
swap' ~(x, y) = (y, x)

second :: (Int, Int) -> Int
second (_, b) = b

whole :: [Int] -> (Int, Int)
whole all'@(x : _) = (x, length all')
whole [] = (0, 0)

main :: IO ()
main = do
  print (lazyPair undefined)
  print (lazyFirst (4, undefined))
  print (case undefined of ~(_, _) -> (0 :: Int))
  print (second (swap' (3, undefined)))
  print (let ~(Just z) = (Nothing :: Maybe Int) in (7 :: Int))
  print (whole [5, 6, 7])
