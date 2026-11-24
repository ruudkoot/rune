{-# LANGUAGE PackageImports #-}
-- System.IO (T10 chapter 41): base's (every name is monomorphic or over Show and Read).
module System.IO (
    IO, fixIO, FilePath, Handle, stdin, stdout, stderr, withFile,
    openFile, IOMode(ReadMode, WriteMode, AppendMode, ReadWriteMode), hClose,
    readFile, writeFile, appendFile, hFileSize, hSetFileSize, hIsEOF,
    isEOF, BufferMode(NoBuffering, LineBuffering, BlockBuffering),
    hSetBuffering, hGetBuffering, hFlush, hGetPosn, hSetPosn, HandlePosn,
    hSeek, SeekMode(AbsoluteSeek, RelativeSeek, SeekFromEnd), hTell,
    hIsOpen, hIsClosed, hIsReadable, hIsWritable, hIsSeekable,
    hIsTerminalDevice, hSetEcho, hGetEcho, hShow, hWaitForInput, hReady,
    hGetChar, hGetLine, hLookAhead, hGetContents, hPutChar, hPutStr,
    hPutStrLn, hPrint, interact, putChar, putStr, putStrLn, print,
    getChar, getLine, getContents, readIO, readLn
  ) where
import "base" System.IO
