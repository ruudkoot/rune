-- Report 5.3.4, the table's row 5: import qualified A () brings into scope nothing. Not A.y.
module Main (main) where

import qualified A ()

main :: IO ()
main = print A.y
