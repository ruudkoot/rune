-- Module IO, sections 21 and 21.11 of the Haskell 98 Report: the interface
-- section 21 prints, with the code of 21.11, which omits the export list
-- and gives try, bracket and bracket_ alone (overlay ov.io.interface).
-- The code of the online Revised Report of December 2002, with its published
-- errata and rhc's overlay applied: a modified version of the Report's code,
-- which does not define Haskell 98. LICENSE says what was changed; errata.tsv
-- and overlay.tsv list each change, and pristine/ holds the code as printed.

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
import PreludeBuiltin                      -- Handle, HandlePosn, IOError (rhc's)

-- Handle and HandlePosn are PreludeBuiltin's (overlay ov.io.handles); the
-- two Show instances were printed `where ..` and `where ---` (ov.io.misprints)
instance Eq Handle where
    h == h'          =  primHandleEq h h'
instance Show Handle where
    showsPrec _ h    =  showString (primHandleShow h)

instance Eq HandlePosn where
    HandlePosn h p == HandlePosn h' p' = h == h' && p == p'
instance Show HandlePosn where
    showsPrec _ (HandlePosn h p) = showString (primHandleShow h) . showString " at position " . shows p


data IOMode      =  ReadMode | WriteMode | AppendMode | ReadWriteMode
                    deriving (Eq, Ord, Ix, Bounded, Enum, Read, Show)
data BufferMode  =  NoBuffering | LineBuffering 
                 |  BlockBuffering (Maybe Int)
                    deriving (Eq, Ord, Read, Show)
data SeekMode    =  AbsoluteSeek | RelativeSeek | SeekFromEnd
                    deriving (Eq, Ord, Ix, Bounded, Enum, Read, Show)

stdin, stdout, stderr :: Handle
stdin                 =  primStdin
stdout                =  primStdout
stderr                =  primStderr

openFile              :: FilePath -> IOMode -> IO Handle
openFile f m          =  primOpenFile f (fromEnum m)
hClose                :: Handle -> IO ()
hClose                =  primHClose

hFileSize             :: Handle -> IO Integer
hFileSize             =  primHFileSize
hIsEOF                :: Handle -> IO Bool
hIsEOF                =  primHIsEOF
isEOF                 :: IO Bool
isEOF                 =  hIsEOF stdin

hSetBuffering         :: Handle  -> BufferMode -> IO ()
hSetBuffering h NoBuffering     =  primHSetBuffering h 0 0
hSetBuffering h LineBuffering   =  primHSetBuffering h 1 0
hSetBuffering h (BlockBuffering m) =
    case m of
      Nothing            -> primHSetBuffering h 2 0
      Just n | n > 0     -> primHSetBuffering h 2 n
             | otherwise -> ioError (IOError IllegalOperation "hSetBuffering: the size of a block is not positive" (Just h) Nothing)
hGetBuffering         :: Handle  -> IO BufferMode
hGetBuffering h       =  primHGetBuffering h >>= \(m, n) ->
                         return (if m == 0 then NoBuffering
                                 else if m == 1 then LineBuffering
                                 else BlockBuffering (if n > 0 then Just n else Nothing))
hFlush                :: Handle -> IO () 
hFlush                =  primHFlush
hGetPosn              :: Handle -> IO HandlePosn
hGetPosn              =  primHGetPosn
hSetPosn              :: HandlePosn -> IO () 
hSetPosn (HandlePosn h p) = primHSeek h 0 p
hSeek                 :: Handle -> SeekMode -> Integer -> IO () 
hSeek h m n           =  primHSeek h (fromEnum m) n

hWaitForInput	      :: Handle -> Int -> IO Bool
hWaitForInput         =  primHWaitForInput
hReady                :: Handle -> IO Bool 
hReady h	      =  hWaitForInput h 0
hGetChar              :: Handle -> IO Char
hGetChar              =  primHGetChar
hGetLine              :: Handle -> IO String
hGetLine              =  primHGetLine
hLookAhead            :: Handle -> IO Char
hLookAhead            =  primHLookAhead
hGetContents          :: Handle -> IO String
hGetContents          =  primHGetContents
hPutChar              :: Handle -> Char -> IO ()
hPutChar              =  primHPutChar
hPutStr               :: Handle -> String -> IO ()
hPutStr               =  primHPutStr
hPutStrLn             :: Handle -> String -> IO ()
hPutStrLn h s         =  hPutStr h s >> hPutChar h '\n'
hPrint                :: Show a => Handle -> a -> IO ()
hPrint h x            =  hPutStrLn h (show x)

hIsOpen               :: Handle -> IO Bool
hIsOpen               =  primHIsOpen
hIsClosed             :: Handle -> IO Bool
hIsClosed             =  primHIsClosed
hIsReadable           :: Handle -> IO Bool
hIsReadable           =  primHIsReadable
hIsWritable           :: Handle -> IO Bool
hIsWritable           =  primHIsWritable
hIsSeekable           :: Handle -> IO Bool
hIsSeekable           =  primHIsSeekable

isAlreadyExistsError  :: IOError -> Bool
isAlreadyExistsError (IOError AlreadyExists _ _ _) = True
isAlreadyExistsError _ = False
isDoesNotExistError   :: IOError -> Bool
isDoesNotExistError (IOError DoesNotExist _ _ _) = True
isDoesNotExistError _  = False
isAlreadyInUseError   :: IOError -> Bool
isAlreadyInUseError (IOError AlreadyInUse _ _ _) = True
isAlreadyInUseError _  = False
isFullError           :: IOError -> Bool
isFullError (IOError Full _ _ _) = True
isFullError _          = False
isEOFError            :: IOError -> Bool
isEOFError (IOError EOF _ _ _) = True
isEOFError _           = False
isIllegalOperation    :: IOError -> Bool
isIllegalOperation (IOError IllegalOperation _ _ _) = True
isIllegalOperation _   = False
isPermissionError     :: IOError -> Bool
isPermissionError (IOError Permission _ _ _) = True
isPermissionError _    = False
isUserError           :: IOError -> Bool
isUserError (IOError User _ _ _) = True
isUserError _          = False

ioeGetErrorString     :: IOError -> String
ioeGetErrorString (IOError _ s _ _) = s
ioeGetHandle          :: IOError -> Maybe Handle
ioeGetHandle (IOError _ _ h _) = h
ioeGetFileName        :: IOError -> Maybe FilePath
ioeGetFileName (IOError _ _ _ f) = f

-- try, bracket and bracket_: their signatures and code are 21.11's, below

-- Just provide an implementation of the system-independent
-- actions that IO exports.

try            :: IO a -> IO (Either IOError a)
try f          =  catch (do r <- f
                            return (Right r))
                        (return . Left)

bracket        :: IO a -> (a -> IO b) -> (a -> IO c) -> IO c
bracket before after m = do
        x  <- before
        rs <- try (m x)
        after x
        case rs of
           Right r -> return r
           Left  e -> ioError e

-- variant of the above where middle computation doesn't want x
bracket_        :: IO a -> (a -> IO b) -> IO c -> IO c
bracket_ before after m = do
         x  <- before
         rs <- try m
         after x
         case rs of
            Right r -> return r
            Left  e -> ioError e
