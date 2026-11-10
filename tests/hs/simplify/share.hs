-- A sharing budget (M23; D51): t is a thunk used inside a lambda, so a
-- copy of it in the lambda would compute it once for each element; and h
-- keeps its lambda behind a let of work, so eta through that let would do
-- the work once for each call. Either makes the count of instructions grow
-- as the square of the size, not as the size. The size is read from
-- standard input.
-- budget: 400 800
module Main where

-- recursive, so that no pass inlines it: its own arity is what eta sees
h :: Int -> Int -> Int
h n = let t = sum [1 .. n] in \x -> if x < 0 then h n (negate x) else x + t

main :: IO ()
main = do
  s <- getLine
  let n = read s :: Int
      t = sum [1 .. n]
      f = \x -> x + t
      g = let u = product [1 .. 3 + n `mod` 2] in \x -> x * u
  print (sum (map f [1 .. n]))
  print (sum (map g [1 .. n]) `mod` 1000003)
  print (sum (map (h n) [1 .. n]))
