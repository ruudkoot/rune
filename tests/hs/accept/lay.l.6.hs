-- rows: lay.note2.empty lay.note2.mimic lay.informal.empty
-- Report 9.3, equation 6 and Note 2: "If the first token after a where (say) is not indented more than the enclosing
-- layout context, then the block must be empty, so empty braces are inserted"; {n} becomes <n>, giving the ;
-- that follows.
module Main (main) where

f :: Int
f = x where
g :: Int
g = 2

x :: Int
x = 1

main :: IO ()
main = print (f + g)
