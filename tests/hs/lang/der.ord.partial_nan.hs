-- rows: R45 R90
-- Report 10.1, readings.md R90 (implementation-defined): derived Ord over a Double field compares by compare, and
-- compare NaN x is GT, by Ord's default over IEEE's == and <=.
module Main (main) where

data T = T Double deriving (Eq, Ord)

nan :: Double
nan = 0 / 0

main :: IO ()
main = print (compare (T nan) (T 1), T nan > T 1, T nan < T 1, T 1 == T 1, compare (T 1) (T 2))
