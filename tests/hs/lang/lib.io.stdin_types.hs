-- rows: lib.io.stdout lib.io.stderr lib.io.openfile lib.io.hclose lib.io.hfilesize lib.io.hiseof lib.io.hsetbuffering lib.io.hgetbuffering lib.io.hflush lib.io.hgetposn lib.io.hsetposn lib.io.hseek lib.io.hwaitforinput lib.io.hgetchar lib.io.hgetline lib.io.hlookahead lib.io.hgetcontents lib.io.hputchar lib.io.hputstr lib.io.hputstrln lib.io.hprint lib.io.hisopen lib.io.hisclosed lib.io.hisreadable lib.io.hiswritable lib.io.hisseekable lib.io.isalreadyexistserror lib.io.isdoesnotexisterror lib.io.isalreadyinuseerror lib.io.isfullerror lib.io.iseoferror lib.io.isillegaloperation lib.io.ispermissionerror lib.io.isusererror lib.io.ioegeterrorstring lib.io.ioegethandle lib.io.ioegetfilename
-- Report 21: each name the chapter gives no definition for, at its Report type by a signature; what each does is the
-- prose rows' programs'.
module Main (main) where

import IO

t0 :: Handle
t0 = stdin

t1 :: Handle
t1 = stdout

t2 :: Handle
t2 = stderr

t3 :: FilePath -> IOMode -> IO Handle
t3 = openFile

t4 :: Handle -> IO ()
t4 = hClose

t5 :: Handle -> IO Integer
t5 = hFileSize

t6 :: Handle -> IO Bool
t6 = hIsEOF

t7 :: IO Bool
t7 = isEOF

t8 :: Handle -> BufferMode -> IO ()
t8 = hSetBuffering

t9 :: Handle -> IO BufferMode
t9 = hGetBuffering

t10 :: Handle -> IO ()
t10 = hFlush

t11 :: Handle -> IO HandlePosn
t11 = hGetPosn

t12 :: HandlePosn -> IO ()
t12 = hSetPosn

t13 :: Handle -> SeekMode -> Integer -> IO ()
t13 = hSeek

t14 :: Handle -> Int -> IO Bool
t14 = hWaitForInput

t15 :: Handle -> IO Bool
t15 = hReady

t16 :: Handle -> IO Char
t16 = hGetChar

t17 :: Handle -> IO String
t17 = hGetLine

t18 :: Handle -> IO Char
t18 = hLookAhead

t19 :: Handle -> IO String
t19 = hGetContents

t20 :: Handle -> Char -> IO ()
t20 = hPutChar

t21 :: Handle -> String -> IO ()
t21 = hPutStr

t22 :: Handle -> String -> IO ()
t22 = hPutStrLn

t23 :: Show a => Handle -> a -> IO ()
t23 = hPrint

t24 :: Handle -> IO Bool
t24 = hIsOpen

t25 :: Handle -> IO Bool
t25 = hIsClosed

t26 :: Handle -> IO Bool
t26 = hIsReadable

t27 :: Handle -> IO Bool
t27 = hIsWritable

t28 :: Handle -> IO Bool
t28 = hIsSeekable

t29 :: IOError -> Bool
t29 = isAlreadyExistsError

t30 :: IOError -> Bool
t30 = isDoesNotExistError

t31 :: IOError -> Bool
t31 = isAlreadyInUseError

t32 :: IOError -> Bool
t32 = isFullError

t33 :: IOError -> Bool
t33 = isEOFError

t34 :: IOError -> Bool
t34 = isIllegalOperation

t35 :: IOError -> Bool
t35 = isPermissionError

t36 :: IOError -> Bool
t36 = isUserError

t37 :: IOError -> String
t37 = ioeGetErrorString

t38 :: IOError -> Maybe Handle
t38 = ioeGetHandle

t39 :: IOError -> Maybe FilePath
t39 = ioeGetFileName

t40 :: IO a -> IO (Either IOError a)
t40 = try

t41 :: IO a -> (a -> IO b) -> (a -> IO c) -> IO c
t41 = bracket

t42 :: IO a -> (a -> IO b) -> IO c -> IO c
t42 = bracket_

main :: IO ()
main = putStrLn "typed"
