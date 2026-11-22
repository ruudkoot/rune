-- rows: lib.r.io.hgetchar.eof lib.r.io.hgetline lib.r.io.hgetline.eof.first lib.r.io.hgetline.eof.mid lib.r.io.hlookahead lib.r.io.hlookahead.eof lib.r.io.hgetcontents lib.r.io.hgetcontents.eof lib.r.io.hputchar lib.r.io.hputstr lib.r.io.hprint lib.r.io.hiseof lib.r.io.hgetposn lib.r.io.hseek.absolute lib.r.io.hseek.relative lib.r.io.hseek.end lib.r.io.hseek.buffer lib.r.io.hseek.negative lib.r.io.hseek.beyond lib.r.io.hready lib.r.io.hready.eof R49
-- Report 21.5, 21.7, 21.9: hIsEOF before and after the last character; hGetChar, hLookAhead (no removal) and hGetLine
-- (no newline; end of file mid-line ends the line), each failing with isEOFError at the end, as hReady does;
-- hSetPosn back to hGetPosn; hSeek from the start, the current position and the end, refusing a negative
-- position and one beyond the end of a file; hGetContents of the unread rest; hPutChar, hPutStr, hPrint; a seek
-- writes the output buffer; an empty file's hGetContents, "" or isEOFError (R49: "may" leaves both).
module Main (main) where

import IO

caught :: IO a -> IO String
caught act = try act >>= return . either kind (const "no error")
  where kind e = if isEOFError e then "isEOFError" else if isIllegalOperation e then "isIllegalOperation" else "another error"

failed :: IO a -> IO Bool
failed act = try act >>= return . either (const True) (const False)

main :: IO ()
main = do
  writeFile "r.txt" "ab\ncd"
  h <- openFile "r.txt" ReadMode
  e0 <- hIsEOF h
  c1 <- hGetChar h
  c2 <- hLookAhead h
  c3 <- hGetChar h
  l1 <- hGetLine h
  p <- hGetPosn h
  rd <- hReady h
  l2 <- hGetLine h
  e1 <- hIsEOF h
  print (e0, c1, c2, c3, l1)
  print (rd, l2, e1)
  r1 <- caught (hGetChar h)
  r2 <- caught (hGetLine h)
  r3 <- caught (hLookAhead h)
  r4 <- caught (hReady h)
  print (r1, r2, r3, r4)
  hSetPosn p
  l3 <- hGetLine h
  print l3
  hClose h
  writeFile "s.txt" "0123456789"
  h2 <- openFile "s.txt" ReadMode
  hSeek h2 AbsoluteSeek 3
  a <- hGetChar h2
  hSeek h2 RelativeSeek 2
  b <- hGetChar h2
  hSeek h2 SeekFromEnd (-1)
  c <- hGetChar h2
  print (a, b, c)
  n <- failed (hSeek h2 AbsoluteSeek (-1))
  f <- failed (hSeek h2 AbsoluteSeek 11)
  print (n, f)
  hSeek h2 AbsoluteSeek 7
  s <- hGetContents h2
  print s
  w <- openFile "w.txt" WriteMode
  hPutChar w 'x'
  hPutStr w "yz"
  hPrint w (1 :: Int, "two")
  hPutStrLn w "line"
  hClose w
  readFile "w.txt" >>= putStr
  rw <- openFile "rw.txt" ReadWriteMode
  hPutStr rw "abcdef"
  hSeek rw AbsoluteSeek 2
  x <- hGetChar rw
  hSeek rw AbsoluteSeek 0
  hPutChar rw 'Z'
  hSeek rw AbsoluteSeek 0
  y <- hGetLine rw
  hClose rw
  print (x, y)
  writeFile "empty.txt" ""
  e <- openFile "empty.txt" ReadMode
  t <- try (hGetContents e >>= \str -> length str `seq` return str)
  print (either (const "") id t)
  hClose e
