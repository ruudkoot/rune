-- Report 3.7: : is built-in syntax and no constructor may be declared with it.
module Main (main) where

data T = Int : Int

main :: IO ()
main = return ()
