-- rows: mod.closure.class mod.closure.t mod.closure.synonym
-- Report 5.5.3: what the compiler needs and the program does not mention need not be imported: the Report's M1 and
-- M2, whose y has the type T that M2 cannot name; a class in a type not imported; a synonym not exported.
module Main (main) where

import M2
import M1 (k)
import S

main :: IO ()
main = print (k y, sx + (1 :: Int))
