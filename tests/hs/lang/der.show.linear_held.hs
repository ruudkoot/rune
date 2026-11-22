-- Report 10.4: show of a deep left-nested tree costs time linear in its size; this runs now and waits for a --count
-- budget that shows it (tests/hs/perf, rhc's policy).
module Main (main) where

infixr 5 :^:
data Tree a = Leaf a | Tree a :^: Tree a deriving (Eq, Show, Read)

main :: IO ()
main = print (length (show (foldl (\t n -> t :^: Leaf n) (Leaf 0) [1 .. 2000 :: Int])))
