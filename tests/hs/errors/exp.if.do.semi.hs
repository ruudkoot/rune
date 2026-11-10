-- rows: R12
-- Report 3.6, 3.14: if has no optional semicolons, so do { if a ; then b ; else c } is refused (R12: rhc
-- follows the Report, not Haskell 2010's DoAndIfThenElse).
module Main (main) where

main :: IO ()
main = do { if True ; then return () ; else return () }
