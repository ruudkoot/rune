-- Report 5.2: the form T exports the type and none of its constructors.
module Main (main) where

import M

main :: IO ()
main = case C 1 of _ -> return ()
