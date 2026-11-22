-- rows: lib.r.io.iserror.exists lib.r.io.iserror.inuse lib.r.io.iserror.eof lib.r.io.iserror.illegal lib.r.io.iserror.user lib.r.io.iserror.bool lib.r.io.ioegethandle lib.r.io.ioegetfilename lib.r.io.ioegeterrorstring.user lib.r.io.try lib.r.io.openfile.err.notexist lib.r.io.openfile.err.inuse lib.r.io.lock.writer
-- Report 21.1, 21.2.3, 21.3.1: each error's predicates (exists, does-not-exist, in-use, full, EOF, illegal, permission,
-- user), each true of its own kind only; ioeGetFileName and ioeGetHandle of the error that refers to a file or a
-- handle, ioeGetErrorString of a user error its string; try's Left and Right; a file open for output cannot be
-- opened again.
module Main (main) where

import IO
import Directory (createDirectory, removeDirectory, doesDirectoryExist)

kinds :: IOError -> [Bool]
kinds e = map ($ e) [isAlreadyExistsError, isDoesNotExistError, isAlreadyInUseError, isFullError, isEOFError,
                     isIllegalOperation, isPermissionError, isUserError]

caught :: String -> IO a -> IO (Maybe IOError)
caught what act = do
  r <- try act
  case r of
    Left e -> putStrLn (what ++ ": " ++ show (kinds e)) >> return (Just e)
    Right _ -> putStrLn (what ++ ": no error") >> return Nothing

main :: IO ()
main = do
  d <- doesDirectoryExist "exists.dir"
  if d then return () else createDirectory "exists.dir"
  _ <- caught "createDirectory of an existing directory" (createDirectory "exists.dir")
  removeDirectory "exists.dir"
  Just e1 <- caught "openFile of a missing file" (openFile "missing.txt" ReadMode)
  print (ioeGetFileName e1, fmap (const ()) (ioeGetHandle e1))
  w <- openFile "inuse.txt" WriteMode
  _ <- caught "openFile for writing of a file open for writing" (openFile "inuse.txt" WriteMode)
  _ <- caught "openFile for reading of a file open for writing" (openFile "inuse.txt" ReadMode)
  hClose w
  writeFile "eof.txt" ""
  h <- openFile "eof.txt" ReadMode
  Just e2 <- caught "hGetChar at end of file" (hGetChar h)
  print (fmap (== h) (ioeGetHandle e2), ioeGetFileName e2 == Nothing || ioeGetFileName e2 == Just "eof.txt")
  hClose h
  _ <- caught "hPutStr on a closed handle" (hPutStr h "x")
  Just e3 <- caught "fail" (fail "the user's own" :: IO ())
  Just e4 <- caught "ioError (userError s)" (ioError (userError "another"))
  print (ioeGetErrorString e3, ioeGetErrorString e4, fmap (const ()) (ioeGetHandle e3), ioeGetFileName e4)
  r <- try (return 'r')
  print (either (const "Left") (: []) r)
