-- Report 4.2.1: a strictness flag takes an atype, so C !Maybe Int is two fields, of which Maybe has the
-- wrong kind.
module Main (main) where

data T = C !Maybe Int

main :: IO ()
main = return ()
