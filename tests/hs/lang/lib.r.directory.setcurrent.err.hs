-- Report 22: changing to a missing directory fails. Uncaught, the IOError ends the program (7.3). It waits for B's primitives for the file system.
module Main (main) where

import Directory

main :: IO ()
main = do
  setCurrentDirectory "nothing"
