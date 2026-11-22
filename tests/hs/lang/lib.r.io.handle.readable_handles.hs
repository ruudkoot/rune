-- rows: lib.r.io.handle.open lib.r.io.handle.closed lib.r.io.std.open lib.r.io.openfile.mode lib.r.io.openfile.create lib.r.io.openfile.truncate lib.r.io.openfile.append lib.r.io.openfile.start lib.r.io.hclose.flush lib.r.io.hclose.twice lib.r.io.hclose.others lib.r.io.hfilesize lib.r.io.hisopen lib.r.io.hisclosed lib.r.io.hisreadable lib.r.io.hiswritable lib.r.io.hisseekable lib.r.io.hsetbuffering lib.r.io.hsetbuffering.size lib.r.io.hgetbuffering
-- Report 21.2, 21.3, 21.4, 21.6, 21.8: stdin, stdout and stderr open at the start; openFile creates a missing file for
-- output (it exists once written: 21.3.1 lets an empty one go), truncates in WriteMode, appends in AppendMode
-- and starts other modes at the beginning; each mode's readable and writable; open and closed across a handle's life, a file seekable in ReadMode, WriteMode and
-- ReadWriteMode (AppendMode's is the implementation's); hClose flushes, a second hClose is
-- no error and every other operation on a closed handle fails; hFileSize in bytes of an ASCII file;
-- hSetBuffering read back by hGetBuffering (BlockBuffering Nothing a size of the implementation's).
module Main (main) where

import IO
import Directory (doesFileExist, removeFile)

failed :: IO a -> IO Bool
failed act = try act >>= return . either (const True) (const False)

preds :: Handle -> IO [Bool]
preds h = sequence [hIsOpen h, hIsClosed h, hIsReadable h, hIsWritable h]

isBlock :: BufferMode -> Bool
isBlock (BlockBuffering _) = True
isBlock _ = False

main :: IO ()
main = do
  stds <- mapM hIsOpen [stdin, stdout, stderr]
  print stds
  x <- doesFileExist "new.txt"
  if x then removeFile "new.txt" else return ()
  w <- openFile "new.txt" WriteMode
  pw <- preds w
  sw <- hIsSeekable w
  print (pw, sw)
  hSetBuffering w (BlockBuffering (Just 64))
  b1 <- hGetBuffering w
  hSetBuffering w LineBuffering
  b2 <- hGetBuffering w
  hSetBuffering w NoBuffering
  b3 <- hGetBuffering w
  hSetBuffering w (BlockBuffering Nothing)
  b4 <- hGetBuffering w
  print (b1, b2, b3, isBlock b4)
  hPutStr w "hello\nworld"
  hClose w
  pc <- preds' w
  c <- doesFileExist "new.txt"
  print (pc, c)
  s1 <- readFile "new.txt"
  print s1
  hClose w
  others <- mapM failed [hGetChar w >> return (), hGetLine w >> return (), hLookAhead w >> return (), hGetContents w >> return (),
                         hPutChar w 'c', hPutStr w "s", hPrint w (), hFileSize w >> return (), hIsEOF w >> return (),
                         hSetBuffering w NoBuffering, hGetBuffering w >> return (), hFlush w, hGetPosn w >> return (),
                         hSeek w AbsoluteSeek 0, hReady w >> return (), hWaitForInput w 0 >> return (),
                         hIsReadable w >> return (), hIsWritable w >> return (), hIsSeekable w >> return ()]
  print others
  r <- openFile "new.txt" ReadMode
  pr <- preds r
  sr <- hIsSeekable r
  sz <- hFileSize r
  c1 <- hGetChar r
  print (pr, sr, sz, c1)
  hClose r
  a <- openFile "new.txt" AppendMode
  pa <- preds a
  hPutStr a "!"
  hClose a
  s2 <- readFile "new.txt"
  print (pa, s2)
  rw <- openFile "new.txt" ReadWriteMode
  prw <- preds rw
  srw <- hIsSeekable rw
  c2 <- hGetChar rw
  hClose rw
  print (prw, srw, c2)
  t <- openFile "new.txt" WriteMode
  hPutStr t "z"
  hClose t
  s3 <- readFile "new.txt"
  print (s3, length s3)
  removeFile "new.txt"
  where preds' h = sequence [hIsOpen h, hIsClosed h]
