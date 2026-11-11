-- rows: R32
-- Report 5.6.1 and 8 (R32; ruling 49 makes the row a refusal): the parts chapter 8 shows the Prelude in, PreludeList
-- and the rest, some of whose types and functions it cannot give in Haskell, "cannot be imported separately"
-- (R32's seed): import PreludeList is refused, and the Prelude itself is all a program sees of them.
module Main (main) where

import PreludeList

main :: IO ()
main = print 1
