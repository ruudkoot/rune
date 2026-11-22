-- Report 9.5: newconstr -> con atype: no strictness flag.
module Main (main) where

newtype N = N !Int

main :: IO ()
main = return ()
