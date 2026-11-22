-- rows: R60
-- Report 2.4: reservedop includes :, "reserved solely for use as the Haskell list constructor": no constructor to declare.
module Main (main) where

data T = Int : Int

main :: IO ()
main = return ()
