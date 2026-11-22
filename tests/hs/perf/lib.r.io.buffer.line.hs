-- Report 21.6 and 21.3.3: hPutStr under LineBuffering writes each character
-- and flushes at a newline. rhc's policy is that this costs per character
-- about what BlockBuffering does: the checks are made once for the string,
-- and the runtime's loop (rtPutChars) writes its characters. lib.r.io.buffer.line.budget:
-- n characters by line cost at most 1.3 times n by block (1.06 measured);
-- with each character through hPutChar's checks, as before 2026-11-16, 3.8 times.
module Main (main) where

import IO

main :: IO ()
main = do
  [m, n] <- fmap (map read . words) getLine
  h <- openFile "out.txt" WriteMode
  hSetBuffering h (if m == 1 then LineBuffering else BlockBuffering Nothing)
  hPutStr h (concat (replicate (n `div` 80) (replicate 79 'x' ++ "\n")))
  hClose h
  s <- readFile "out.txt"
  print (length s)
