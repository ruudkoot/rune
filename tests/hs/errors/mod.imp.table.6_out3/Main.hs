-- Report 5.3.4, the table's row 6: import qualified A (x) brings into scope A.x. Not A.y.
module Main (main) where

import qualified A (x)

main :: IO ()
main = print A.y
