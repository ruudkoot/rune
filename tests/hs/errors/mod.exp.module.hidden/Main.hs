-- Report 5.2: what is hidden on import is not exported by module N.
module Main (main) where

import X

main :: IO ()
main = print y
