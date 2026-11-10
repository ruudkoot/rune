-- rows: lib.r.io.openfile.err.perm
-- Report 21.1, 21.3.1: openFile of a file without read permission fails with isPermissionError (a run as root opens it).
module Main (main) where

import IO
import Directory

main :: IO ()
main = do
  writeFile "secret.txt" "s"
  p <- getPermissions "secret.txt"
  setPermissions "secret.txt" (p { readable = False })
  r <- try (openFile "secret.txt" ReadMode)
  case r of
    Left e -> print (isPermissionError e, isDoesNotExistError e, isUserError e)
    Right h -> hClose h >> putStrLn "opened"
  setPermissions "secret.txt" p
  removeFile "secret.txt"
