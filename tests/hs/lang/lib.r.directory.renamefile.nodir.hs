-- rows: lib.r.directory.permissions.exec lib.r.directory.permissions.search
-- Report 22: renameFile of a directory fails with isPermissionError; a directory is searchable and a file not. It waits for
-- B's primitives for the file system.
module Main (main) where

import Directory
import IO

main :: IO ()
main = do
  createDirectory "d"
  writeFile "f" "x"
  r <- try (renameFile "d" "e")
  print (either isPermissionError (const False) r)
  pd <- getPermissions "d"
  pf <- getPermissions "f"
  print (searchable pd, searchable pf)
