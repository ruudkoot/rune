-- rows: lib.r.directory.remove lib.r.directory.removefile lib.r.directory.renamedir lib.r.directory.renamefile lib.r.directory.contents lib.r.directory.contents.relative lib.r.directory.contents.nosub lib.r.directory.doesdirectoryexist lib.r.directory.doesfileexist lib.r.directory.setcurrent lib.r.directory.getcurrent lib.r.directory.permissions lib.r.directory.permissions.example lib.directory.data.permissions lib.directory.inst.eqpermissions lib.directory.inst.ordpermissions lib.directory.inst.showpermissions lib.directory.inst.readpermissions
-- Report 22: create, list, rename and remove directories and files in the run's own directory; doesFileExist and
-- doesDirectoryExist on a file, a directory and nothing; permissions read and set back; Permissions' fields and
-- instances. -- It waits for B's primitives for the file system.
module Main (main) where

import Directory
import List (sort)

main :: IO ()
main = do
  createDirectory "d"
  writeFile "d/f" "x"
  createDirectory "d/e"
  writeFile "d/e/g" "y"
  cs <- getDirectoryContents "d"
  print (sort (filter (`notElem` [".", ".."]) cs))
  a <- doesFileExist "d/f"
  b <- doesDirectoryExist "d/f"
  c <- doesDirectoryExist "d"
  e <- doesFileExist "nothing"
  print (a, b, c, e)
  renameFile "d/f" "d/h"
  renameDirectory "d/e" "d/k"
  cs2 <- getDirectoryContents "d"
  print (sort (filter (`notElem` [".", ".."]) cs2))
  p <- getPermissions "d/h"
  setPermissions "d/h" p
  p2 <- getPermissions "d/h"
  print (p == p2, readable p, searchable p, p <= p2, read (show p) == p)
  removeFile "d/h"
  removeFile "d/k/g"
  removeDirectory "d/k"
  x <- doesFileExist "d/h"
  y <- doesDirectoryExist "d/k"
  print (x, y)
  here <- getCurrentDirectory
  setCurrentDirectory "d"
  there <- getCurrentDirectory
  setCurrentDirectory here
  removeDirectory "d"
  print (length there > length here, take (length here) there == here)
