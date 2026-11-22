-- rows: lib.io.data.buffermode lib.io.data.seekmode lib.io.data.handle lib.io.data.handleposn lib.io.inst.eqhandle lib.io.inst.showhandle lib.io.inst.eqhandleposn lib.io.inst.showhandleposn lib.r.io.handle.show lib.r.io.handle.eq
-- Report 21: IOMode and SeekMode derive Eq, Ord, Ix, Bounded, Enum, Read and Show, BufferMode Eq, Ord, Read and Show;
-- Handle and HandlePosn are in Eq and Show: a handle is equal only to itself (two handles on one file are not),
-- and its show, system dependent, is non-empty and tells two handles of different files apart. The expected
-- output is written by hand (GHC's IOMode and SeekMode have no Bounded).
module Main (main) where

import IO
import Ix

main :: IO ()
main = do
  print ([minBound .. maxBound :: IOMode], range (ReadMode, ReadWriteMode), index (ReadMode, ReadWriteMode) AppendMode, inRange (WriteMode, AppendMode) ReadMode)
  print (ReadMode < WriteMode, succ ReadMode, fromEnum ReadWriteMode, read "AppendMode" :: IOMode, (minBound, maxBound) :: (IOMode, IOMode))
  print ([NoBuffering, LineBuffering, BlockBuffering Nothing, BlockBuffering (Just 4)], LineBuffering < BlockBuffering Nothing, BlockBuffering (Just 1) < BlockBuffering (Just 2))
  print (read "BlockBuffering (Just 8)" :: BufferMode, read " NoBuffering" :: BufferMode, BlockBuffering Nothing == BlockBuffering Nothing)
  print ([minBound .. maxBound :: SeekMode], range (AbsoluteSeek, SeekFromEnd), read "RelativeSeek" :: SeekMode, compare SeekFromEnd AbsoluteSeek)
  print (stdin == stdin, stdin == stdout, stdout /= stderr, not (null (show stdin)), show stdin /= show stdout)
  writeFile "h1.txt" "abc"
  writeFile "h2.txt" "xyz"
  h1 <- openFile "h1.txt" ReadMode
  h2 <- openFile "h1.txt" ReadMode
  h3 <- openFile "h2.txt" ReadMode
  print (h1 == h1, h1 == h2, h1 /= h3, not (null (show h1)), show h1 /= show h3)
  p1 <- hGetPosn h1
  c <- hGetChar h1
  p2 <- hGetPosn h1
  print (c, p1 == p1, p1 == p2, not (null (show p1)))
  mapM_ hClose [h1, h2, h3]
