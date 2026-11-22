-- Report 22: renameFile in a directory that is not writable fails with isPermissionError. It waits for B's primitives for the file system; root, who is refused nothing, skips it (ruling 32).
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
  writeFile "ro/f" "x"
  setPermissions "ro" ro
  r <- try (renameFile "ro/f" "ro/g")
  setPermissions "ro" rw
  removeFile "ro/f"
  removeDirectory "ro"
  print (either isPermissionError (const False) r)
