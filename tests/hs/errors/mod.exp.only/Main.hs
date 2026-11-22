-- Report 5.2: a module exports only what it declares or imports.
module Main (main) where

import M

main :: IO ()
main = return ()
