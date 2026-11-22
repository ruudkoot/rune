-- Report 4.2.2: a recursive type synonym is not allowed.
module Main (main) where

type Rec a = [Rec a]

main :: IO ()
main = return ()
