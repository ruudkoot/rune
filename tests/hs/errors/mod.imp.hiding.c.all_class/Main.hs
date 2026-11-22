-- Report 5.3.1: and the class.
module Main (main) where

import M hiding (C)

f :: C a => a -> Int
f _ = 0

main :: IO ()
main = return ()
