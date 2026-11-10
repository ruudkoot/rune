-- rows: lib.directory.setpermissions lib.directory.getpermissions
-- Report 22: the chapter's example as printed, makeReadable, which sets one field of a file's Permissions by record
-- update and keeps the others, run on a file made write-only; the bits printed are those root sees too (ruling 32).
-- It waits for the primitives of the file system.
module Main (main) where

import Directory

makeReadable f = do
		    p <- getPermissions f
		    setPermissions f (p {readable = True})

main :: IO ()
main = do
  writeFile "f" "x"
  setPermissions "f" (Permissions { readable = False, writable = True, executable = False, searchable = False })
  makeReadable "f"
  p <- getPermissions "f"
  print (readable p, writable p, executable p, searchable p)
  removeFile "f"
