-- Report 5.3.4, the table's row 8: import A hiding (x) brings into scope y, A.y. Not A.x.
module Main (main) where

import A hiding (x)

main :: IO ()
main = print A.x
