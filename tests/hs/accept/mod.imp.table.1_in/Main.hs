-- Report 5.3.4, the table's row 1: import A brings into scope x, y, A.x, A.y.
module Main (main) where

import A

main :: IO ()
main = print [x, y, A.x, A.y]
