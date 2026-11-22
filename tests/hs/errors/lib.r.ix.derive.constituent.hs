-- Report 15.1: a derived Ix needs each constituent in Ix: Double is not.
module Main (main) where

import Ix

data P = P Double deriving (Eq, Ord, Ix)

main :: IO ()
main = return ()
