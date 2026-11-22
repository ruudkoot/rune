-- Report 15.1, 4.3.3: Ix's superclass Ord must be there: deriving Ix alone is refused.
module Main (main) where

import Ix

data C = R | S deriving (Eq, Ix)

main :: IO ()
main = return ()
