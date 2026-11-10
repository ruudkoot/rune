-- rows: lib.r.io.getline.shorthand lib.r.io.std.channels R46
-- Report 21.2.1, 21.5, 21.9.2: isEOF is hIsEOF stdin; getLine, a shorthand for hGetLine stdin, returns the last line
-- without its newline (R46); stdout and stderr are channels apart: what goes to stderr is not in stdout.
module Main (main) where

import IO

main :: IO ()
main = do
  e0 <- isEOF
  l1 <- getLine
  hPutStrLn stderr "to standard error"
  l2 <- getLine
  e1 <- isEOF
  print (e0, l1, l2, e1)
  hPutStrLn stdout "to standard output"
