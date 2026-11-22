-- rows: R26
-- Report 5.4, 4.3.2: one instance of a class and type in the program, also of modules that do not see each other.
module Main (main) where

import A2
import B2

main :: IO ()
main = print (a + b)
