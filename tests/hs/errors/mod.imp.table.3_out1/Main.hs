-- Report 5.3.4, the table's row 3: import A (x) brings into scope x, A.x. Not y.
module Main (main) where

import A (x)

main :: IO ()
main = print y
