-- rows: R1 deviation
-- Report 9.3 gives `do a == b == c` the single parse (do { a == b }) == c, since == is non-associative, and says the rule
-- "is hard to implement in its full generality": rhc closes blocks by the grammar alone, with operators flat
-- (D27), so the block holds a == b == c and fixity resolution refuses it (R1: D38, a deviation the Report
-- concedes, advising programmers to avoid such code; every oracle refuses it too).
module Main (main) where

f :: Bool -> Bool -> Bool -> Bool
f a b c = do a == b == c

main :: IO ()
main = return ()
