-- Report 5.2: what is imported qualified only is not exported by module N.
module Main (main) where

import X

main :: IO ()
main = print x
