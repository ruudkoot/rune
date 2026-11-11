-- rows: mod.recursive.types mod.recursive.instances R29 R28
-- Report 5: "Modules may be mutually recursive": A and B import each other, with values, types, a class and an instance
-- across the cycle; the expected result is the Report's, by its conversion of a program to one module, and
-- not an oracle's (D52: no oracle compiles a cycle as written; R29).
module Main (main) where

import A
import B

main :: IO ()
main = print (fa 3, ca (Tb (Tc (Ta 4))), cb Td)
