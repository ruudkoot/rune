-- rows: tr.lambda.fresh exp.let.lexical
-- Report 3.3, 3.12: bound variables renamed consistently keep a program's meaning; rename.locals.pair.hs is this
-- program with every bound variable renamed.
module Main (main) where

f :: Int -> Int
f x = let y = x * 2 in y + g x
  where g z = z - 1

h :: [Int] -> Int
h xs = case xs of
  (a : as) -> a + sum (map (\b -> b * 10) as)
  [] -> 0

main :: IO ()
main = do
  print (f 5, h [1, 2, 3])
  print (let x = 1; y = x + 1 in (\x -> x + y) (10 :: Int))
