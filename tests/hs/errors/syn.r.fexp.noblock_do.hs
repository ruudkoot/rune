-- Report 9.5: fexp -> [fexp] aexp: an argument is an aexp, so no unparenthesised do.
module Main (main) where

main :: IO ()
main = id do return ()
