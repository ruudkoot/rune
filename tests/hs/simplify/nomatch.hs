-- Sestoft's trees (D34's B) make nothing for a match that does not fail
-- on the run: zipW's tree has two leaves that fail, which no run here
-- reaches, and zipC's none. Where the match's no-match continuation is
-- bound at the head of the tree, it is a suspension made at every call
-- and never forced, and zipW's run makes one more object a call than
-- zipC's (hs/simplify/objects/nomatch). The Report's order pays one for
-- zipW too, the suspension of the clause zipW's first falls to, which
-- tests again: that order's cost, not held here.
-- objects: 1 20000 <= 2 20000
module Main where

zipW :: [Int] -> [Int] -> [Int]
zipW (x:xs) (y:ys) = x + y : zipW xs ys
zipW [] [] = []

zipC :: [Int] -> [Int] -> [Int]
zipC (x:xs) (y:ys) = x + y : zipC xs ys
zipC _ _ = []

main :: IO ()
main = do
  [which, n] <- fmap (map read . words) getLine
  let f = if which == 1 then zipW else zipC
  print (sum (f [1 .. n] [1 .. n]))
