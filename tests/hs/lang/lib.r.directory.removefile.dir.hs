-- Report 22: removeFile of a directory fails. Uncaught, the IOError ends the program (7.3). It waits for B's primitives for the file system.
module Main (main) where

import Directory

main :: IO ()
main = do
  createDirectory "d"
  removeFile "d"
