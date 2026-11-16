-- A string with a bottom in it is written up to the bottom: every character
-- before it is in the file, and the program ends with the bottom's error
-- (status 1). The way it writes is the line on its standard input: writeFile,
-- appendFile (to a file that holds "kept\n"), or hPutStr under NoBuffering
-- ("none"), LineBuffering ("line"), BlockBuffering Nothing ("block") or
-- BlockBuffering (Just 2) ("block2") (21.3.3, 21.6, 7.1; rhc's library writes
-- each character as it is evaluated). hs/library/bottomwrite reads the file
-- after each run, on Core's interpreter and on the VM.
module Main (main) where

import IO

text :: String
text = "abc" ++ error "the bottom"

through :: BufferMode -> IO ()
through mode = do
  h <- openFile "out.txt" WriteMode
  hSetBuffering h mode
  hPutStr h text
  hClose h

main :: IO ()
main = do
  way <- getLine
  case way of
    "writeFile"  -> writeFile "out.txt" text
    "appendFile" -> appendFile "out.txt" text
    "none"       -> through NoBuffering
    "line"       -> through LineBuffering
    "block"      -> through (BlockBuffering Nothing)
    "block2"     -> through (BlockBuffering (Just 2))
    _            -> ioError (userError ("no way " ++ way))
