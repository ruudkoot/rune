-- rows: R26
-- Report 5.4: an instance is in scope only through a chain of imports: none reaches Orphan's from Main (R26).
module Main (main) where

import Used

main :: IO ()
main = print id
