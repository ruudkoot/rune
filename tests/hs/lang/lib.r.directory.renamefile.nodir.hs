-- rows: lib.r.directory.permissions.exec lib.r.directory.permissions.search
-- Report 22: renameFile of a directory fails with isPermissionError; a directory is searchable and a file not, and a
-- directory is not executable. It clears what an earlier run in the same directory left, and what it makes, so that
-- every family that runs it twice in one place sees the same.
module Main (main) where

import Directory
import IO

clean :: IO ()
clean = do
  d <- doesDirectoryExist "d"
  if d then removeDirectory "d" else return ()
  e <- doesDirectoryExist "e"
  if e then removeDirectory "e" else return ()
  f <- doesFileExist "f"
  if f then removeFile "f" else return ()

main :: IO ()
main = do
  clean
  createDirectory "d"
  writeFile "f" "x"
  r <- try (renameFile "d" "e")
  print (either isPermissionError (const False) r)
  pd <- getPermissions "d"
  pf <- getPermissions "f"
  print (searchable pd, searchable pf, executable pd)
  clean
