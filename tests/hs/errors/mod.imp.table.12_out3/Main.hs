-- Report 5.3.4, the table's row 12: import A as B (x) brings into scope x, B.x. Not A.x.
module Main (main) where

import A as B (x)

main :: IO ()
main = print A.x
