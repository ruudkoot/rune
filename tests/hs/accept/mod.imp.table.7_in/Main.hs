-- Report 5.3.4, the table's row 7: import A hiding () brings into scope x, y, A.x, A.y.
module Main (main) where

import A hiding ()

main :: IO ()
main = print [x, y, A.x, A.y]
