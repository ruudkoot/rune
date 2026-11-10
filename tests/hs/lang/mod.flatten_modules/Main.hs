-- Report 5: a program of three modules: Main, A and B, each with an f; mod.flatten_joined is it as one module.
module Main (main) where

import qualified A
import qualified B

main :: IO ()
main = A.f >> B.f >> print (A.g 2)
