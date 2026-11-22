-- Report 5.3.4, the table's row 4: import qualified A brings into scope A.x, A.y. Not y.
module Main (main) where

import qualified A

main :: IO ()
main = print y
