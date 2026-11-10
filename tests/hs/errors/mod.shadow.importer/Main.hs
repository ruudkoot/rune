-- Report 5.6.2: a module importing A unqualified and using null must resolve the ambiguity.
module Main (main) where

import A2

main :: IO ()
main = print (null 0)
