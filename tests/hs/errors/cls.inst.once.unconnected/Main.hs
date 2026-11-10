-- rows: R26
-- Report 4.3.2: "A type may not be declared as an instance of a particular class more than once in the program":
-- two modules that do not import each other, both with instance C T, in one program (R26: the rule is of the program).
module Main (main) where

import A
import B

main :: IO ()
main = print (a + b)
