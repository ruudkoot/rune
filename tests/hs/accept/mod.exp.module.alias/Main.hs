-- rows: R30
-- Report 5.2: module M is matched against qualifiers, which an as clause sets: module Q for N imported as Q (R30).
module Main (main) where

import X

main :: IO ()
main = print (x, y)
