-- Report 9.3: `do { if a ; then b ; else c }` is refused: in Haskell 98 a ; ends a statement, and then is none.
module Main (main) where

main :: IO ()
main = do { if True ; then print 1 ; else print 2 }
