-- rows: lib.r.io.buffer.block lib.r.io.buffer.none lib.r.io.hsetbuffering.toflush lib.r.io.hflush
-- Report 21.6, 21.6.1: what a handle has given the system, shown by the system itself (cat): line buffering
-- gives a line at its newline and holds a part line; hFlush gives what is held; block buffering holds a short
-- line; changing to NoBuffering gives what is held, and then each character goes at once; hClose gives the rest.
-- `look` shows what the file holds as the system has it, between bars.
-- interp: no: Core's interpreter writes a file at once, with no buffer, so the buffering shown is the VM's runtime's
module Main (main) where

import IO
import System

look :: String -> IO ()
look tag = do
  putStr (tag ++ ": |")
  hFlush stdout
  _ <- system "cat b.txt"
  putStrLn "|"

main :: IO ()
main = do
  h <- openFile "b.txt" WriteMode
  hSetBuffering h LineBuffering
  hPutStr h "ab"
  look "line, a part line"
  hPutStr h "c\nd"
  look "line, after a newline"
  hFlush h
  look "line, after hFlush"
  hSetBuffering h (BlockBuffering Nothing)
  hPutStr h "ef\n"
  look "block, a short line"
  hSetBuffering h NoBuffering
  look "changed to none"
  hPutStr h "g"
  look "none"
  hSetBuffering h LineBuffering
  hPutStr h "h"
  hClose h
  look "after hClose"
