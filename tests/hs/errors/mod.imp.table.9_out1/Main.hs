-- Report 5.3.4, the table's row 9: import qualified A hiding () brings into scope A.x, A.y. Not x.
module Main (main) where

import qualified A hiding ()

main :: IO ()
main = print x
