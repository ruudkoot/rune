
module IO (
    Handle, HandlePosn,
    IOMode(ReadMode,WriteMode,AppendMode,ReadWriteMode),
    BufferMode(NoBuffering,LineBuffering,BlockBuffering),
    SeekMode(AbsoluteSeek,RelativeSeek,SeekFromEnd),
    stdin, stdout, stderr, 
    openFile, hClose, hFileSize, hIsEOF, isEOF,
    hSetBuffering, hGetBuffering, hFlush, 
    hGetPosn, hSetPosn, hSeek, 
    hWaitForInput, hReady, hGetChar, hGetLine, hLookAhead, hGetContents, 
    hPutChar, hPutStr, hPutStrLn, hPrint,
    hIsOpen, hIsClosed, hIsReadable, hIsWritable, hIsSeekable,
    isAlreadyExistsError, isDoesNotExistError, isAlreadyInUseError, 
    isFullError, isEOFError,
    isIllegalOperation, isPermissionError, isUserError, 
    ioeGetErrorString, ioeGetHandle, ioeGetFileName,
    try, bracket, bracket_,

    -- ...and what the Prelude exports
    IO, FilePath, IOError, ioError, userError, catch, interact,
    putChar, putStr, putStrLn, print, getChar, getLine, getContents,
    readFile, writeFile, appendFile, readIO, readLn
    ) where

import Ix(Ix)

data Handle = ...			-- implementation-dependent
instance Eq Handle where ...
instance Show Handle where ..           -- implementation-dependent

data HandlePosn = ...			-- implementation-dependent
instance Eq HandlePosn where ...
instance Show HandlePosn where ---      -- implementation-dependent


data IOMode      =  ReadMode | WriteMode | AppendMode | ReadWriteMode
                    deriving (Eq, Ord, Ix, Bounded, Enum, Read, Show)
data BufferMode  =  NoBuffering | LineBuffering 
                 |  BlockBuffering (Maybe Int)
                    deriving (Eq, Ord, Read, Show)
data SeekMode    =  AbsoluteSeek | RelativeSeek | SeekFromEnd
                    deriving (Eq, Ord, Ix, Bounded, Enum, Read, Show)

stdin, stdout, stderr :: Handle

openFile              :: FilePath -> IOMode -> IO Handle
hClose                :: Handle -> IO ()

hFileSize             :: Handle -> IO Integer
hIsEOF                :: Handle -> IO Bool
isEOF                 :: IO Bool
isEOF                 =  hIsEOF stdin

hSetBuffering         :: Handle  -> BufferMode -> IO ()
hGetBuffering         :: Handle  -> IO BufferMode
hFlush                :: Handle -> IO () 
hGetPosn              :: Handle -> IO HandlePosn
hSetPosn              :: HandlePosn -> IO () 
hSeek                 :: Handle -> SeekMode -> Integer -> IO () 

hWaitForInput	      :: Handle -> Int -> IO Bool
hReady                :: Handle -> IO Bool 
hReady h	      =  hWaitForInput h 0
hGetChar              :: Handle -> IO Char
hGetLine              :: Handle -> IO String
hLookAhead            :: Handle -> IO Char
hGetContents          :: Handle -> IO String
hPutChar              :: Handle -> Char -> IO ()
hPutStr               :: Handle -> String -> IO ()
hPutStrLn             :: Handle -> String -> IO ()
hPrint                :: Show a => Handle -> a -> IO ()

hIsOpen               :: Handle -> IO Bool
hIsClosed             :: Handle -> IO Bool
hIsReadable           :: Handle -> IO Bool
hIsWritable           :: Handle -> IO Bool
hIsSeekable           :: Handle -> IO Bool

isAlreadyExistsError  :: IOError -> Bool
isDoesNotExistError   :: IOError -> Bool
isAlreadyInUseError   :: IOError -> Bool
isFullError           :: IOError -> Bool
isEOFError            :: IOError -> Bool
isIllegalOperation    :: IOError -> Bool
isPermissionError     :: IOError -> Bool
isUserError           :: IOError -> Bool

ioeGetErrorString     :: IOError -> String
ioeGetHandle          :: IOError -> Maybe Handle
ioeGetFileName        :: IOError -> Maybe FilePath

try                   :: IO a -> IO (Either IOError a)
bracket               :: IO a -> (a -> IO b) -> (a -> IO c) -> IO c
bracket_              :: IO a -> (a -> IO b) -> IO c -> IO c
