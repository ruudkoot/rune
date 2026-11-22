-- Report 5.3.1: (..) brings in what the module exported, so no constructor of an abstract T.
module Main (main) where

import M (T(..))

main :: IO ()
main = case Hidden of _ -> return ()
