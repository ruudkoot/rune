-- Report 5.3.4, the table's row 11: import A as B brings into scope x, y, B.x, B.y. Not A.x.
module Main (main) where

import A as B

main :: IO ()
main = print A.x
