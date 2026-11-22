-- Report 5.3.4, the table's row 10: import qualified A hiding (x) brings into scope A.y. Not A.x.
module Main (main) where

import qualified A hiding (x)

main :: IO ()
main = print A.x
