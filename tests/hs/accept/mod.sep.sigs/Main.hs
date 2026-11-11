-- rows: R20 R29
-- Report 5.7 (R20, R29; ruling 49 makes the row an acceptance): explicit signatures for all exported values "may be
-- necessary" for mutual recursion; rhc needs none for a function: A's f and B's g, exported, unsigned and mutually
-- recursive across the cycle, are inferred as one group (R29: an SCC compiled whole). What D30 needs is only that a
-- restricted variable used across the cycle have its type in its own module: here x's signature.
module Main (main) where

import A
import B

main :: IO ()
main = print (f 3, y)
