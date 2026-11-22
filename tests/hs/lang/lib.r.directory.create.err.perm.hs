-- Report 22: createDirectory in a directory that is not writable fails with isPermissionError. It waits for B's primitives for the file system; root, who is refused nothing, skips it (ruling 32).
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
  setPermissions "ro" ro
  r <- try (createDirectory "ro/x")
  setPermissions "ro" rw
  removeDirectory "ro"
  print (either isPermissionError (const False) r)
