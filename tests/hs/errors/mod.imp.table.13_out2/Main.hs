-- Report 5.3.4, the table's row 13: import qualified A as B brings into scope B.x, B.y. Not A.x.
module Main (main) where

import qualified A as B

main :: IO ()
main = print A.x
