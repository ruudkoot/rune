-- Report 5.3.4, the table's row 12: import A as B (x) brings into scope x, B.x. Not y.
module Main (main) where

import A as B (x)

main :: IO ()
main = print y
