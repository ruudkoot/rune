-- rows: R49
-- Report 22: getPermissions of a missing path fails. Uncaught, the IOError ends the program (7.3). It waits for B's primitives for the file system.
module Main (main) where

import Directory

main :: IO ()
main = do
  getPermissions "nothing" >>= print . readable
