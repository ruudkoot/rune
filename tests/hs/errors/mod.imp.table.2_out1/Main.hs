-- Report 5.3.4, the table's row 2: import A () brings into scope nothing. Not x.
module Main (main) where

import A ()

main :: IO ()
main = print x
