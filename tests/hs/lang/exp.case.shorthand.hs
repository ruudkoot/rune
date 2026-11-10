-- rows: exp.case.seq exp.case.guards.seq exp.case.env.pattern exp.case.env.decls exp.case.guard.body exp.case.guard.fallthrough tr.case.b.guards
-- Report 3.13: alternatives are tried in order, and guards in order; a guard sees the pattern's variables and the where's,
-- the where shadowing the pattern; when every guard fails the next alternative is tried, a where no obstacle.
module Main (main) where

f :: Int -> String
f x = case x of
  0 -> "zero"
  0 -> "never"
  n | n < 0 -> "neg"
    | n < 10 -> "small"
    | undefined -> "unreached"
  _ -> "big"

g :: (Int, Int) -> Int
g p = case p of
  (a, b) | c > 10 -> c
         | otherwise -> b
    where c = a * 2
          b = 7

h :: Int -> String
h x = case x of
  n | n > 10 -> "big"
    where m = n
  _ -> "other"

main :: IO ()
main = do
  print (map f [0, -1, 5])
  print (case 5 :: Int of { n | n > 0 -> "a" | undefined -> "b" })
  print (g (3, 1), g (6, 1))
  print (h 5, h 11)
