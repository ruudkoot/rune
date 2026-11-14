-- A full device (/dev/full) refuses what a handle writes out: hFlush, hClose, writeFile and appendFile raise an
-- IOError for which isFullError holds, and so does hPutStr on a handle that is not buffered (21.1; the owner's A of
-- 2026-11-12, the lead's ruling 62: the system's flush and close report their failure). On the VM the bytes wait
-- in the system's buffer and the flush or the close fails; Core's interpreter writes at once, so its write fails
-- first, the same IOError (hs/library/devicefull).
module Main (main) where

import IO

full :: IO a -> IO String
full act = try act >>= \r -> return (either kind (const "no error") r)
  where kind e = if isFullError e then "isFullError" else "another: " ++ show e

main :: IO ()
main = do
  h1 <- openFile "/dev/full" WriteMode
  a <- full (hPutStr h1 "abc" >> hFlush h1)
  _ <- try (hClose h1)
  h2 <- openFile "/dev/full" WriteMode
  b <- full (hPutStr h2 "abc" >> hClose h2)
  _ <- try (hClose h2)
  c <- full (writeFile "/dev/full" "abc")
  d <- full (appendFile "/dev/full" "abc")
  h3 <- openFile "/dev/full" WriteMode
  hSetBuffering h3 NoBuffering
  e <- full (hPutStr h3 "abc")
  _ <- try (hClose h3)
  print (a, b, c, d, e)
