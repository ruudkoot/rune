-- Report 5.3.1: a data constructor may be hidden by its own name.
module Main (main) where

import M hiding (Con)

main :: IO ()
main = case Con of _ -> return ()
