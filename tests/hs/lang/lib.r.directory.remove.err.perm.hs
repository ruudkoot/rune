-- Report 22: removeDirectory of an entry of a directory that is not writable fails with isPermissionError. It waits for B's primitives for the file system; root, who is refused nothing, skips it (ruling 32).
module Main (main) where

import Directory
import IO

ro :: Permissions
ro = Permissions { readable = True, writable = False, executable = False, searchable = True }

rw :: Permissions
rw = ro { writable = True }

main :: IO ()
main = do
  createDirectory "ro"
  createDirectory "ro/sub"
  setPermissions "ro" ro
  r <- try (removeDirectory "ro/sub")
  setPermissions "ro" rw
  removeDirectory "ro/sub"
  removeDirectory "ro"
  print (either isPermissionError (const False) r)
