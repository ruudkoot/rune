-- Report 5.2: C(..) of an imported class exports the methods in scope alone.
module Main (main) where

import M

main :: IO ()
main = print (c2 True)
