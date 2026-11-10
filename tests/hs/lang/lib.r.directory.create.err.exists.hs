-- Report 22: creating a directory that exists fails. Uncaught, the IOError ends the program (7.3). It waits for B's primitives for the file system.
module Main (main) where

import Directory

main :: IO ()
main = do
  createDirectory "d"
  createDirectory "d"
