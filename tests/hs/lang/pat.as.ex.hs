-- rows: pat.wild.form pat.m.as pat.m.var pat.m.wild pat.m.irref.succeed pat.m.irref.bind pat.m.irref.delay pat.irref.def pat.irref.var pat.irref.wild pat.irref.as pat.irref.lazy pat.ex.lazypair pat.ex.lazysingleton.unused pat.ex.lazynested.lazy pat.ex.lazycons pat.result
-- Report 3.17: the Report's examples: f s@(x:xs) = x:s, case e of { [x,_,_] -> ... }; matching a variable, a wildcard or
-- an irrefutable pattern succeeds on anything, bottom too, and binds lazily.
module Main (main) where

f :: [Int] -> [Int]
f s@(x : xs) = x : s

g :: [Int] -> [Int]
g (x : xs) = x : x : xs

main :: IO ()
main = do
  print (f [1, 2], g [1, 2])
  print (case [1, 2, 3 :: Int] of { [x, _, _] -> x }, case [1, 2, 3 :: Int] of { [x, y, z] -> x })
  print (case [1, 2 :: Int] of s@(x : _) -> (s, x))
  print ((\x -> 1 :: Int) (undefined :: Int), (\_ -> 1 :: Int) (undefined :: Int), (\x@_ -> 1 :: Int) (undefined :: Int))
  print ((\ ~(x, y) -> 0 :: Int) (undefined :: (Int, Int)), (\ ~(x, y) -> x) (1 :: Int, 2 :: Int))
  print ((\ ~(x, y) -> x) (1 :: Int, undefined :: Int), (\ ~True -> 1 :: Int) False)
  print ((\ ~(Just x) -> 1 :: Int) (undefined :: Maybe Int), (\ ~[x] -> 0 :: Int) ([] :: [Int]))
  print ((\ ~[x, ~(a, b)] -> x) [(0, 1), undefined :: (Int, Int)])
  print (case (\ ~(x : xs) -> x : x : xs) (undefined :: [Int]) of { (_ : _ : _) -> "cons"; _ -> "other" })
