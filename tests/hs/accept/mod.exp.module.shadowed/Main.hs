-- rows: R30
-- Report 5.2: an entity in scope as both x and Q.x is exported by module Q, though x is also another's.
module Main (main) where

import X

main :: IO ()
main = print X.out
