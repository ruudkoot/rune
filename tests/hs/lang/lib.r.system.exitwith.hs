-- rows: lib.r.system.exitwith.close lib.system.data.exitcode lib.r.system.exitcode
-- Report 23: exitWith (ExitFailure 3) ends the program with status 3, its open handles closed so that buffered output is
-- written; ExitCode's instances. It waits for B's primitives for the process and its environment.
module Main (main) where

import System
import IO

main :: IO ()
main = do
  print (ExitFailure 3 == ExitFailure 3, ExitSuccess < ExitFailure 1, show (ExitFailure 2), read "ExitSuccess" :: ExitCode)
  h <- openFile "out.txt" WriteMode
  hPutStr h "kept"
  putStr "buffered"
  exitWith (ExitFailure 3)
