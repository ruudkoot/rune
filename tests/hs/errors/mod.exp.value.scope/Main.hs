-- Report 5.2: an exported name is in scope: N.z, not imported.
module Main (main) where

import M

main :: IO ()
main = return ()
