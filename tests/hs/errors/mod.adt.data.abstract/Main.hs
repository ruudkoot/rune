-- Report 5.8: an importer of Stack cannot construct through its constructors.
module Main (main) where

import Stack

main :: IO ()
main = case EmptyStk of _ -> return ()
