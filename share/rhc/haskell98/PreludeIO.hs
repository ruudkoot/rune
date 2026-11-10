-- Module PreludeIO, section 8.3 of the Haskell 98 Report.
-- The code of the online Revised Report of December 2002, with its published
-- errata and rhc's overlay applied: a modified version of the Report's code,
-- which does not define Haskell 98. LICENSE says what was changed; errata.tsv
-- and overlay.tsv list each change, and pristine/ holds the code as printed.

module PreludeIO (
    FilePath, IOError, ioError, userError, catch,
    putChar, putStr, putStrLn, print,
    getChar, getLine, getContents, interact,
    readFile, writeFile, appendFile, readIO, readLn
  ) where

import PreludeBuiltin
import PreludeRuntime (IOErrorKind(..), ioErrorKind, ioErrorText, ioErrorFile, ioErrorHandle)  -- (rhc's)
import IO (hSetBuffering, stdin, stdout, BufferMode(..), hGetLine)  -- interact's, getLine's (rhc's)



type  FilePath = String


data IOError    -- The internals of this type are system dependent
                -- (rhc's primitive: Core's Exn, its details PreludeRuntime's)


instance  Show IOError  where
    showsPrec _ e  =  case ioErrorKind e of
                        User -> showString "user error (" . showString (ioErrorText e) . showChar ')'
                        _    -> showString (ioErrorText e)

instance  Eq IOError  where
    e == e'        =  ioErrorKind e == ioErrorKind e' && ioErrorText e == ioErrorText e'
                      && ioErrorFile e == ioErrorFile e' && ioErrorHandle e == ioErrorHandle e'


ioError    ::  IOError -> IO a 
ioError    =   primIOError
	   

userError  ::  String -> IOError
userError  =   primUserError
	   

catch      ::  IO a -> (IOError -> IO a) -> IO a 
catch      =   primCatch
	   

putChar    :: Char -> IO ()
putChar    =  primPutChar
	   

putStr     :: String -> IO ()
putStr s   =  mapM_ putChar s
	   

putStrLn   :: String -> IO ()
putStrLn s =  do putStr s
                 putStr "\n"
	   

print      :: Show a => a -> IO ()
print x    =  putStrLn (show x)
	   

getChar    :: IO Char
getChar    =  primGetChar
	   

getLine    :: IO String
getLine    =  hGetLine stdin   -- 21.9.2: the last line returned at the end of the file (R46)
            

getContents :: IO String
getContents =  primGetContents


interact    ::  (String -> String) -> IO ()
-- The hSetBuffering ensures the expected interactive behaviour
interact f  =  do hSetBuffering stdin  NoBuffering
                  hSetBuffering stdout NoBuffering
                  s <- getContents
                  putStr (f s)


readFile   :: FilePath -> IO String
readFile   =  primReadFile
	   

writeFile  :: FilePath -> String -> IO ()
writeFile  =  primWriteFile
	   

appendFile :: FilePath -> String -> IO ()
appendFile =  primAppendFile

  -- raises an exception instead of an error

readIO   :: Read a => String -> IO a
readIO s =  case [x | (x,t) <- reads s, ("","") <- lex t] of
              [x] -> return x
              []  -> ioError (userError "Prelude.readIO: no parse")
              _   -> ioError (userError "Prelude.readIO: ambiguous parse")


readLn :: Read a => IO a
readLn =  do l <- getLine
             r <- readIO l
             return r
