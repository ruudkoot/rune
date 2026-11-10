-- Report 5.5.3: there y has no signature, since T is not in scope.
module Main (main) where

import M2

main :: IO ()
main = return ()
