-- rows: lib.io.export.handleposn lib.io.export.iomodereadmodecwritemodecappendmodecreadwritemod lib.io.export.buffermodenobufferingclinebufferingcblockbufferi lib.io.export.seekmodeabsoluteseekcrelativeseekcseekfromend lib.io.export.stdin lib.io.export.stdout lib.io.export.stderr lib.io.export.openfile lib.io.export.hclose lib.io.export.hfilesize lib.io.export.hiseof lib.io.export.iseof lib.io.export.hsetbuffering lib.io.export.hgetbuffering lib.io.export.hflush lib.io.export.hgetposn lib.io.export.hsetposn lib.io.export.hseek lib.io.export.hwaitforinput lib.io.export.hready lib.io.export.hgetchar lib.io.export.hgetline lib.io.export.hlookahead lib.io.export.hgetcontents lib.io.export.hputchar lib.io.export.hputstr lib.io.export.hputstrln lib.io.export.hprint lib.io.export.hisopen lib.io.export.hisclosed lib.io.export.hisreadable lib.io.export.hiswritable lib.io.export.hisseekable lib.io.export.isalreadyexistserror lib.io.export.isdoesnotexisterror lib.io.export.isalreadyinuseerror lib.io.export.isfullerror lib.io.export.iseoferror lib.io.export.isillegaloperation lib.io.export.ispermissionerror lib.io.export.isusererror lib.io.export.ioegeterrorstring lib.io.export.ioegethandle lib.io.export.ioegetfilename lib.io.export.try lib.io.export.bracket lib.io.export.bracketu lib.io.export.io lib.io.export.filepath lib.io.export.ioerror lib.io.export.ioerror.2 lib.io.export.usererror lib.io.export.catch lib.io.export.interact lib.io.export.putchar lib.io.export.putstr lib.io.export.putstrln lib.io.export.print lib.io.export.getchar lib.io.export.getline lib.io.export.getcontents lib.io.export.readfile lib.io.export.writefile lib.io.export.appendfile lib.io.export.readio lib.io.export.readln
-- Report 21: module IO exports each of these: an explicit import of every one compiles, and each name is used.
module Main (main) where

import IO (Handle, HandlePosn, IOMode(ReadMode,WriteMode,AppendMode,ReadWriteMode), BufferMode(NoBuffering,LineBuffering,BlockBuffering), SeekMode(AbsoluteSeek,RelativeSeek,SeekFromEnd), stdin, stdout, stderr, openFile, hClose, hFileSize, hIsEOF, isEOF, hSetBuffering, hGetBuffering, hFlush, hGetPosn, hSetPosn, hSeek, hWaitForInput, hReady, hGetChar, hGetLine, hLookAhead, hGetContents, hPutChar, hPutStr, hPutStrLn, hPrint, hIsOpen, hIsClosed, hIsReadable, hIsWritable, hIsSeekable, isAlreadyExistsError, isDoesNotExistError, isAlreadyInUseError, isFullError, isEOFError, isIllegalOperation, isPermissionError, isUserError, ioeGetErrorString, ioeGetHandle, ioeGetFileName, try, bracket, bracket_, IO, FilePath, IOError, ioError, userError, catch, interact, putChar, putStr, putStrLn, print, getChar, getLine, getContents, readFile, writeFile, appendFile, readIO, readLn)

t0 :: Handle -> ()
t0 _ = ()

t1 :: HandlePosn -> ()
t1 _ = ()

t2 :: IOMode -> ()
t2 _ = ()
s2_0 _ = ReadMode
s2_1 _ = WriteMode
s2_2 _ = AppendMode
s2_3 _ = ReadWriteMode

t3 :: BufferMode -> ()
t3 _ = ()
s3_0 _ = NoBuffering
s3_1 _ = LineBuffering
s3_2 _ = BlockBuffering

t4 :: SeekMode -> ()
t4 _ = ()
s4_0 _ = AbsoluteSeek
s4_1 _ = RelativeSeek
s4_2 _ = SeekFromEnd

v5 _ = stdin

v6 _ = stdout

v7 _ = stderr

v8 _ = openFile

v9 _ = hClose

v10 _ = hFileSize

v11 _ = hIsEOF

v12 _ = isEOF

v13 _ = hSetBuffering

v14 _ = hGetBuffering

v15 _ = hFlush

v16 _ = hGetPosn

v17 _ = hSetPosn

v18 _ = hSeek

v19 _ = hWaitForInput

v20 _ = hReady

v21 _ = hGetChar

v22 _ = hGetLine

v23 _ = hLookAhead

v24 _ = hGetContents

v25 _ = hPutChar

v26 _ = hPutStr

v27 _ = hPutStrLn

v28 _ = hPrint

v29 _ = hIsOpen

v30 _ = hIsClosed

v31 _ = hIsReadable

v32 _ = hIsWritable

v33 _ = hIsSeekable

v34 _ = isAlreadyExistsError

v35 _ = isDoesNotExistError

v36 _ = isAlreadyInUseError

v37 _ = isFullError

v38 _ = isEOFError

v39 _ = isIllegalOperation

v40 _ = isPermissionError

v41 _ = isUserError

v42 _ = ioeGetErrorString

v43 _ = ioeGetHandle

v44 _ = ioeGetFileName

v45 _ = try

v46 _ = bracket

v47 _ = bracket_

t48 :: IO Int -> ()
t48 _ = ()

t49 :: FilePath -> ()
t49 _ = ()

t50 :: IOError -> ()
t50 _ = ()

v51 _ = ioError

v52 _ = userError

v53 _ = catch

v54 _ = interact

v55 _ = putChar

v56 _ = putStr

v57 _ = putStrLn

v58 _ = print

v59 _ = getChar

v60 _ = getLine

v61 _ = getContents

v62 _ = readFile

v63 _ = writeFile

v64 _ = appendFile

v65 _ = readIO

v66 _ = readLn

main :: IO ()
main = return ()
