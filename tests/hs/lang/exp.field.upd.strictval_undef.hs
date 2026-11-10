-- Report 3.15.3: an update is strict in the value updated: seq (undefined {f1 = 1}) () diverges.
module Main (main) where

data T = C1 {f1, f2 :: Int}

main :: IO ()
main = print (seq ((undefined :: T) {f1 = 1}) ())
