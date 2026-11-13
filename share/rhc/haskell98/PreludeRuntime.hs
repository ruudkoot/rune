-- Module PreludeRuntime: rhc's, not the Report's (overlay ov.prelude.runtime).
-- It is in the Prelude's unit, whose types it names, and a program cannot
-- import it.
--
-- PreludeBuiltin and UnicodePrims, the two modules the Report's code imports
-- and never defines, are rhc's runtime in Core (CoreRuntime,
-- lib/language/haskell/coreruntime_sig.sml): the Report's prim* names, an
-- IOError being Core's Exn. This module is what the library needs besides,
-- as Haskell sees it (D26's A: no SML below Haskell):
--   * a type signature with no binding declares a primitive by its name,
--     one of Core's (CorePrim, lib/language/haskell/coreprim_sig.sml) or of
--     the runtime's (CoreRuntime); its Haskell type stands for Core's, with
--     no `!`, and IO t for World -> (utuple World t);
--   * a data declaration with no constructors declares a type of Core's:
--     the Prelude's Int, Integer, Char, Float, Double and IO a, PreludeIO's
--     IOError (Core's Exn), and here Str (bytes), Ref a (a cell) and Arr a
--     (an array).
-- What the library builds on them follows, in Haskell: IOError's details
-- (21.1), the handles of IO (21), and the calls of the system that
-- Directory, System, Time, CPUTime and Random make (22 to 27).

module PreludeRuntime (
    Str, Ref, Arr,

    -- Core's primitives that the library names outside this module
    int_add, int_sub, int_mul, int_quot, int_rem, int_div, int_mod, int_neg,
    int_eq, int_ne, int_lt, int_le, int_gt, int_ge,
    integer_add, integer_sub, integer_mul, integer_quot, integer_rem,
    integer_div, integer_mod, integer_neg,
    integer_eq, integer_ne, integer_lt, integer_le, integer_gt, integer_ge,
    integer_from_int, integer_to_int, char_ord, char_chr,
    double_add, double_sub, double_mul, double_div, double_neg,
    double_eq, double_ne, double_lt, double_le, double_gt, double_ge,
    double_sqrt, double_exp, double_log, double_sin, double_cos, double_tan,
    double_atan, double_atan2, double_sinh, double_cosh, double_tanh,
    double_pow, double_is_nan, double_is_infinite, double_is_negative_zero,
    double_is_denormalized, double_mantissa, double_exponent, double_encode,
    float_add, float_sub, float_mul, float_div, float_neg,
    float_eq, float_ne, float_lt, float_le, float_gt, float_ge,
    float_from_double, float_to_double,
    float_sqrt, float_exp, float_log, float_sin, float_cos, float_tan,
    float_atan, float_atan2, float_sinh, float_cosh, float_tanh,
    float_is_nan, float_is_infinite, float_is_negative_zero,
    float_is_denormalized, float_encode,
    arr_new, arr_read, arr_get, arr_set, unsafe_perform_io,
    ref_new, ref_get, ref_set, str_size,

    -- the runtime's
    primSeq, primReturnIO, primBindIO, primUnpackString, primPackString,

    -- IOError's details (21.1)
    IOErrorKind(..), primMakeIOError, ioErrorKind, ioErrorText, ioErrorFile,
    ioErrorHandle, primFailWith, sys_errno,

    -- Handle (21.2)
    Handle, HandlePosn(..),
    primStdin, primStdout, primStderr,
    primHandleEq, primHandleShow, primOpenFile, primHClose, primHFileSize,
    primHIsEOF, primHSetBuffering, primHGetBuffering, primHFlush,
    primHGetPosn, primHSeek, primHWaitForInput, primHGetChar, primHGetLine,
    primHLookAhead, primHGetContents, primHPutChar, primHPutStr,
    primHIsOpen, primHIsClosed, primHIsReadable, primHIsWritable,
    primHIsSeekable, primExit, primReadFile, primWriteFile, primAppendFile,

    -- the system (22 to 27)
    ClockTime(..), primSystemCall,
    os_mkdir, os_rmdir, os_chdir, os_remove, os_rename, os_getcwd, os_access,
    os_file_kind, os_mod_time, os_open_dir, os_read_dir, os_close_dir,
    os_file_mode, os_set_mode, os_system, os_getenv, os_has_env,
    command_arg_count, command_arg, command_name, time_now, time_cpu,
    date_offset, date_zone_name, date_is_dst, random_seed
  ) where

import PreludeBuiltin (primElided)    -- the reader's binding of a primitive (src/rhc/library.sml, I5 to I7)
import qualified PreludeBuiltin (primReadFile)

-- ---- Core's types that are not the Prelude's ----

data Str
data Ref a
data Arr a

-- ---- Core's primitives (CorePrim) ----

-- Int: Mid's int, 63 bits, on the checked primitives (D22): past Int's
-- range an arithmetic raises Overflow, a division by 0 Div
int_add, int_sub, int_mul, int_quot, int_rem, int_div, int_mod
                  :: Int -> Int -> Int
int_neg           :: Int -> Int
int_eq, int_ne, int_lt, int_le, int_gt, int_ge
                  :: Int -> Int -> Bool

-- Integer: IntInf's representation (D20's D; M31)
integer_add, integer_sub, integer_mul, integer_quot, integer_rem,
 integer_div, integer_mod
                  :: Integer -> Integer -> Integer
integer_neg       :: Integer -> Integer
integer_eq, integer_ne, integer_lt, integer_le, integer_gt, integer_ge
                  :: Integer -> Integer -> Bool
integer_from_int  :: Int -> Integer
integer_to_int    :: Integer -> Int

-- Char: a code point, 0 to 0x10FFFF (D21)
char_ord          :: Char -> Int
char_chr          :: Int -> Char

-- Double: Mid's real, a binary64
double_add, double_sub, double_mul, double_div, double_atan2, double_pow
                  :: Double -> Double -> Double
double_neg, double_sqrt, double_exp, double_log, double_sin, double_cos,
 double_tan, double_atan, double_sinh, double_cosh, double_tanh
                  :: Double -> Double
double_eq, double_ne, double_lt, double_le, double_gt, double_ge
                  :: Double -> Double -> Bool
double_is_nan, double_is_infinite, double_is_negative_zero,
 double_is_denormalized
                  :: Double -> Bool
-- decodeFloat's halves, double_decode's (whose unboxed pair Haskell does
-- not write), and encodeFloat of a mantissa of Int
double_mantissa, double_exponent
                  :: Double -> Int
double_encode     :: Int -> Int -> Double

-- Float: a Double that binary32 represents, each result rounded (D23)
float_add, float_sub, float_mul, float_div, float_atan2
                  :: Float -> Float -> Float
float_neg, float_sqrt, float_exp, float_log, float_sin, float_cos,
 float_tan, float_atan, float_sinh, float_cosh, float_tanh
                  :: Float -> Float
float_eq, float_ne, float_lt, float_le, float_gt, float_ge
                  :: Float -> Float -> Bool
float_is_nan, float_is_infinite, float_is_negative_zero,
 float_is_denormalized
                  :: Float -> Bool
float_from_double :: Double -> Float
float_to_double   :: Float -> Double
float_encode      :: Int -> Int -> Float

-- Str: bytes, a character's in UTF-8
str_size          :: Str -> Int
str_byte          :: Str -> Int -> Int
str_extract       :: Str -> Int -> Int -> Str
str_from_char     :: Char -> Str

-- arrays, Array's representation (ov.array.representation): arr_get reads
-- one that is written no more
arr_new           :: Int -> a -> IO (Arr a)
arr_set           :: Arr a -> Int -> a -> IO ()
arr_read          :: Arr a -> Int -> IO a
arr_get           :: Arr a -> Int -> a

-- cells, and an action run where no state is passed, for the library's own
-- cells (the handles, Random's generator), made the first time they are used
ref_new           :: a -> IO (Ref a)
ref_get           :: Ref a -> IO a
ref_set           :: Ref a -> a -> IO ()
unsafe_perform_io :: IO a -> a
-- an action whose value is a suspension that runs it (D25)
interleave        :: IO a -> IO a
exit              :: Int -> IO a

-- An IOError, Core's Exn of the kind IOError, with its details: the code of
-- its kind (IOErrorKind's, below), its text, its file ("" for none) and the
-- number of its handle (-1 for none). One the runtime makes (userError's,
-- an error of readFile's) has the code 0 (a user's), "" and -1 until it
-- gives them.
exn_io_full       :: Int -> Str -> Str -> Int -> IOError
exn_io_code       :: IOError -> Int
exn_io_file       :: IOError -> Str
exn_io_handle     :: IOError -> Int
exn_message       :: IOError -> Str

-- files, by the number of an open one, 0 to 2 the standard input, output
-- and error: h_open gives -1 where it fails, h_write False, and h_errno
-- the system's error
h_open            :: Str -> Int -> IO Int
h_close           :: Int -> IO ()
h_read            :: Int -> Int -> IO Str
h_write           :: Int -> Str -> IO Bool
h_flush           :: Int -> IO ()
-- a flush and a close that say whether the system's succeeded (a full
-- device fails them), h_errno saying why; the close closes either way
h_flush_ok        :: Int -> IO Bool
h_close_ok        :: Int -> IO Bool
-- the byte a file is at, or -1; to a byte from its start, 0 or -1; the
-- size of the file of a name, or -1
h_tell            :: Int -> IO Int
h_seek            :: Int -> Int -> IO Int
os_file_size      :: Str -> IO Int
h_errno           :: IO Int
-- the system's error of the last call of os_* that failed, and an error's
-- name (ENOENT) and text
sys_errno         :: IO Int
sys_error_name    :: Int -> Str
sys_error_message :: Int -> Str

-- ---- the runtime's (CoreRuntime) ----

primSeq           :: a -> b -> b
primReturnIO      :: a -> IO a
primBindIO        :: IO a -> (a -> IO b) -> IO b
-- a Str's characters, a string literal's (D24's A), and the inverse
primUnpackString  :: Str -> String
primPackString    :: String -> Str
-- whether input waits on a file, or comes within the milliseconds, the
-- runtime's buffer of the standard input first
primReady         :: Int -> Int -> IO Bool

-- ---- IOError's details (21.1) ----

-- The kinds IO's predicates tell apart, by their codes, 0 to 8.
data IOErrorKind  =  User | AlreadyExists | DoesNotExist | AlreadyInUse | Full
                  |  EOF | IllegalOperation | Permission | Other
                     deriving (Eq)

kindCode          :: IOErrorKind -> Int
kindCode k        =  case k of
                       User -> 0; AlreadyExists -> 1; DoesNotExist -> 2
                       AlreadyInUse -> 3; Full -> 4; EOF -> 5
                       IllegalOperation -> 6; Permission -> 7; Other -> 8

codeKind          :: Int -> IOErrorKind
codeKind n        =  case n of
                       0 -> User; 1 -> AlreadyExists; 2 -> DoesNotExist
                       3 -> AlreadyInUse; 4 -> Full; 5 -> EOF
                       6 -> IllegalOperation; 7 -> Permission; _ -> Other

-- `primMakeIOError k text h f`: the IOError of the kind, its text, about the
-- handle and the file
primMakeIOError   :: IOErrorKind -> String -> Maybe Handle -> Maybe FilePath -> IOError
primMakeIOError k text h f =
    exn_io_full (kindCode k) (primPackString text)
                (primPackString (maybe "" id f)) (maybe (-1) handleId h)

ioErrorKind       :: IOError -> IOErrorKind
ioErrorKind e     =  codeKind (exn_io_code e)

ioErrorText       :: IOError -> String
ioErrorText e     =  primUnpackString (exn_message e)

ioErrorFile       :: IOError -> Maybe FilePath
ioErrorFile e     =  case primUnpackString (exn_io_file e) of
                       [] -> Nothing
                       f  -> Just f

-- the handle an IOError is about, among those the program has opened
ioErrorHandle     :: IOError -> Maybe Handle
ioErrorHandle e   =  case [h | h <- unsafe_perform_io (ref_get handles) ++ unsafe_perform_io (ref_get opened),
                               handleId h == n] of
                       (h:_) -> Just h
                       []    -> Nothing
  where n = exn_io_handle e

-- `primErrnoKind n`: the kind of the system's error `n`, by its name
primErrnoKind     :: Int -> IOErrorKind
primErrnoKind n
  | e `elem` ["EEXIST", "ENOTEMPTY"]        = AlreadyExists
  | e `elem` ["ENOENT", "ENOTDIR"]          = DoesNotExist
  | e `elem` ["EBUSY", "ETXTBSY"]           = AlreadyInUse
  | e `elem` ["ENOSPC", "EDQUOT", "EFBIG"]  = Full
  | e `elem` ["EACCES", "EPERM", "EROFS"]   = Permission
  | otherwise                               = IllegalOperation
  where e = primUnpackString (sys_error_name n)

-- `primFailWith what h f errno` raises the IOError of the system's error
-- `errno`, from the operation `what` on the handle `h` or the file `f`
primFailWith      :: String -> Maybe Handle -> Maybe FilePath -> Int -> IO a
primFailWith what h f errno =
    ioError (primMakeIOError (primErrnoKind errno)
                             (what ++ ": " ++ primUnpackString (sys_error_message errno)) h f)

-- ---- Handle (21.2) ----

-- A handle: a number of its own, for Eq; the number of its file; what it
-- shows as; whether it reads, writes, seeks; and its state, whose changes
-- every copy of it sees:
--   * open (0), semi-closed (1, by hGetContents) or closed (2);
--   * the characters read ahead, by hLookAhead and hIsEOF;
--   * its buffering: 0 none, 1 by line, 2 by block (BufferMode's order),
--     with the size of a block, 0 for the system's;
--   * the bytes read from its file and not yet decoded, from an index;
--   * the characters written since the last flush, which BlockBuffering
--     (Just n) holds to n (21.6).
data Handle       =  Handle Int Int String Bool Bool Bool
                            (Ref Int) (Ref [Char]) (Ref Int) (Ref Int)
                            (Ref Str) (Ref Int) (Ref Int)

-- A position: the handle, and the byte from its file's start.
data HandlePosn   =  HandlePosn Handle Integer

handleId     (Handle n _ _ _ _ _ _ _ _ _ _ _ _) = n
handleFd     (Handle _ d _ _ _ _ _ _ _ _ _ _ _) = d
handleName   (Handle _ _ f _ _ _ _ _ _ _ _ _ _) = f
handleReads  (Handle _ _ _ r _ _ _ _ _ _ _ _ _) = r
handleWrites (Handle _ _ _ _ w _ _ _ _ _ _ _ _) = w
handleSeeks  (Handle _ _ _ _ _ s _ _ _ _ _ _ _) = s
handleState  (Handle _ _ _ _ _ _ st _ _ _ _ _ _) = st
handleAhead  (Handle _ _ _ _ _ _ _ a _ _ _ _ _) = a
handleMode   (Handle _ _ _ _ _ _ _ _ m _ _ _ _) = m
handleSize   (Handle _ _ _ _ _ _ _ _ _ z _ _ _) = z
handleBytes  (Handle _ _ _ _ _ _ _ _ _ _ b _ _) = b
handleIndex  (Handle _ _ _ _ _ _ _ _ _ _ _ i _) = i
handleHeld   (Handle _ _ _ _ _ _ _ _ _ _ _ _ k) = k

-- the handles open, holds among them, and the standard ones, open or not,
-- the newest first, which a lock looks through (21.2.3): one closed leaves
-- it when the next is opened (`live`), so that a program that opens many
-- files in turn pays for those open alone; and the number of the next
handles           :: Ref [Handle]
handles           =  unsafe_perform_io (mapM make [(2, "<stderr>", False, True, 0),
                                                   (1, "<stdout>", False, True, 1),
                                                   (0, "<stdin>", True, False, 1)]
                                        >>= ref_new)
  where make (fd, name, r, w, mode) = newHandle fd fd name r w False mode

handleCount       :: Ref Int
handleCount       =  unsafe_perform_io (ref_new 3)

-- every handle openFile has made, closed or not, the newest first: the
-- handle an IOError about one is about (ioeGetHandle), however long ago it
-- was closed
opened            :: Ref [Handle]
opened            =  unsafe_perform_io (ref_new [])

-- the handles of `hs` not closed, and the standard ones
live              :: [Handle] -> IO [Handle]
live []           =  return []
live (h:hs)       = do
    st <- ref_get (handleState h)
    rest <- live hs
    return (if st /= 2 || handleId h <= 2 then h : rest else rest)

newHandle         :: Int -> Int -> String -> Bool -> Bool -> Bool -> Int -> IO Handle
newHandle n fd name r w s mode = do
    st <- ref_new 0
    ahead <- ref_new []
    m <- ref_new mode
    z <- ref_new 0
    b <- ref_new (str_extract (str_from_char ' ') 0 0)
    i <- ref_new 0
    k <- ref_new 0
    return (Handle n fd name r w s st ahead m z b i k)

-- The standard handles. stdin and stdout are buffered by line, as a
-- terminal's are; stderr is not buffered (21.6 leaves it to the system).
primStdin, primStdout, primStderr :: Handle
primStdin         =  standard 0
primStdout        =  standard 1
primStderr        =  standard 2

standard          :: Int -> Handle
standard n        =  head [h | h <- unsafe_perform_io (ref_get handles), handleId h == n]

primHandleEq      :: Handle -> Handle -> Bool
primHandleEq h k  =  handleId h == handleId k

primHandleShow    :: Handle -> String
primHandleShow h  =  "{handle: " ++ handleName h ++ "}"

-- an IOError about a handle
illegal           :: Handle -> String -> IO a
illegal h what    =  ioError (primMakeIOError IllegalOperation (what ++ ": illegal operation")
                                              (Just h) (Just (handleName h)))

endOfFile         :: Handle -> String -> IO a
endOfFile h what  =  ioError (primMakeIOError EOF (what ++ ": end of file") (Just h) (Just (handleName h)))

-- the handle open, neither semi-closed nor closed, and able to do what `ok`
-- says, or an IOError
checkOpen         :: Handle -> String -> (Handle -> Bool) -> IO ()
checkOpen h what ok = do
    st <- ref_get (handleState h)
    if st == 0 && ok h then return () else illegal h what

usable            :: Handle -> String -> IO ()
usable h what     =  checkOpen h what (const True)

-- the handle closed, and an IOError where what it held could not be
-- written (21.3.2: "flushed as for hFlush"; a full device is isFullError)
primHClose        :: Handle -> IO ()
primHClose h      = do
    st <- ref_get (handleState h)
    if st == 2 then return ()
      else do
        flushOk <- if handleWrites h then h_flush_ok (handleFd h) else return True
        flushErr <- if flushOk then return 0 else h_errno
        closeOk <- h_close_ok (handleFd h)
        ref_set (handleState h) 2
        if not flushOk then primFailWith "hClose" (Just h) (Just (handleName h)) flushErr
          else if not closeOk then h_errno >>= primFailWith "hClose" (Just h) (Just (handleName h))
          else return ()

-- what the handle holds written, or the IOError of the system's error (a
-- full device: isFullError)
flushed           :: Handle -> String -> IO ()
flushed h what    =  h_flush_ok (handleFd h) >>= \ok ->
                     if ok then ref_set (handleHeld h) 0
                       else h_errno >>= primFailWith what (Just h) (Just (handleName h))

primHIsOpen, primHIsClosed :: Handle -> IO Bool
primHIsOpen h     =  ref_get (handleState h) >>= \st -> return (st == 0)
primHIsClosed h   =  ref_get (handleState h) >>= \st -> return (st == 2)

primHIsReadable, primHIsWritable, primHIsSeekable :: Handle -> IO Bool
primHIsReadable h =  usable h "hIsReadable" >> return (handleReads h)
primHIsWritable h =  usable h "hIsWritable" >> return (handleWrites h)
primHIsSeekable h =  usable h "hIsSeekable" >> return (handleSeeks h)

-- ---- writing ----

-- a character written, and the buffer flushed as the mode says: none (0),
-- by line (1) at a newline, by block (2) where it overflows
primHPutChar      :: Handle -> Char -> IO ()
primHPutChar h c  = do
    checkOpen h "hPutChar" handleWrites
    if handleReads h then readBack h else return ()
    mode <- ref_get (handleMode h)
    if mode == 2 then overflow h "hPutChar" else return ()
    ok <- h_write (handleFd h) (str_from_char c)
    if not ok then h_errno >>= primFailWith "hPutChar" (Just h) (Just (handleName h))
      else if mode == 0 || (mode == 1 && c == '\n') then flushed h "hPutChar"
      else held h

-- Under BlockBuffering (Just n) a handle holds n characters: what it holds
-- is written out when another comes ("whenever it overflows", 21.6; the
-- lead's ruling 64). Under BlockBuffering Nothing, and to the size of the
-- system's own buffer, the system's buffer does it (a size above that
-- writes out more often, which 21.6 allows).
overflow          :: Handle -> String -> IO ()
overflow h what   = do
    n <- ref_get (handleSize h)
    k <- ref_get (handleHeld h)
    if n > 0 && k >= n then flushed h what else return ()

held              :: Handle -> IO ()
held h            =  ref_get (handleHeld h) >>= \k -> ref_set (handleHeld h) (k + 1)

-- A handle that reads and writes (ReadWriteMode) writes where its reading
-- has got to: what it read of the file and has not given, the bytes and the
-- characters ahead, given back, the file put at that place again.
readBack          :: Handle -> IO ()
readBack h        = do
    s <- ref_get (handleBytes h)
    i <- ref_get (handleIndex h)
    ahead <- ref_get (handleAhead h)
    if i >= str_size s && null ahead then return ()
      else do
        p <- position h "hPutChar"
        r <- h_seek (handleFd h) (fromInteger p)
        if r < 0 then h_errno >>= primFailWith "hPutChar" (Just h) (Just (handleName h))
          else do
            ref_set (handleBytes h) (str_extract s 0 0)
            ref_set (handleIndex h) 0
            ref_set (handleAhead h) []

-- Each character as it is evaluated, so that what comes before a bottom
-- is written. Under BlockBuffering Nothing each goes to the system's buffer
-- with no more checks than the first; under BlockBuffering (Just n) it is
-- counted, as hPutChar counts it.
primHPutStr       :: Handle -> String -> IO ()
primHPutStr h s   = do
    checkOpen h "hPutStr" handleWrites
    mode <- ref_get (handleMode h)
    size <- ref_get (handleSize h)
    if mode /= 2 || handleReads h then mapM_ (primHPutChar h) s
      else if size > 0 then counted s
      else block s
  where
    write c k     = h_write (handleFd h) (str_from_char c) >>= \ok ->
                    if ok then k else h_errno >>= primFailWith "hPutStr" (Just h) (Just (handleName h))
    block []      = return ()
    block (c:cs)  = write c (block cs)
    counted []    = return ()
    counted (c:cs) = overflow h "hPutStr" >> write c (held h >> counted cs)

primHFlush        :: Handle -> IO ()
primHFlush h      =  checkOpen h "hFlush" handleWrites >> flushed h "hFlush"

-- A change to NoBuffering flushes a writable handle, and discards what a
-- handle that is not writable has read ahead and not given (21.6, R158,
-- the lead's ruling 61: the text over the oracles, which keep it); a file's
-- under NoBuffering is then read a byte at a time, so nothing is ahead.
primHSetBuffering :: Handle -> Int -> Int -> IO ()
primHSetBuffering h mode size = do
    usable h "hSetBuffering"
    if handleWrites h then flushed h "hSetBuffering" else return ()
    old <- ref_get (handleMode h)
    if mode == 0 && old /= 0 && not (handleWrites h)
      then do
        ref_set (handleAhead h) []
        s <- ref_get (handleBytes h)
        ref_set (handleBytes h) (str_extract s 0 0)
        ref_set (handleIndex h) 0
      else return ()
    ref_set (handleMode h) mode
    ref_set (handleSize h) size

primHGetBuffering :: Handle -> IO (Int, Int)
primHGetBuffering h = do
    usable h "hGetBuffering"
    mode <- ref_get (handleMode h)
    size <- ref_get (handleSize h)
    return (mode, size)

-- ---- reading ----

-- The next character, the one read ahead first; Nothing at the end, or
-- where a read fails. The standard input's is getChar's, which shares the
-- runtime's buffer with getContents.
readChar          :: Handle -> IO (Maybe Char)
readChar h        = do
    ahead <- ref_get (handleAhead h)
    case ahead of
      (c:cs) -> ref_set (handleAhead h) cs >> return (Just c)
      []     -> if handleFd h == 0
                  then catch (getChar >>= return . Just) (\_ -> return Nothing)
                  else fileChar h

-- the next byte of a file, from the handle's bytes, read 4096 at a time,
-- or one at a time under NoBuffering; -1 at the end
fileByte          :: Handle -> IO Int
fileByte h        = do
    s <- ref_get (handleBytes h)
    i <- ref_get (handleIndex h)
    if i < str_size s then ref_set (handleIndex h) (i + 1) >> return (str_byte s i)
      else do
        mode <- ref_get (handleMode h)
        t <- catch (h_read (handleFd h) (if mode == 0 then 1 else 4096)) (\_ -> return (str_extract s 0 0))
        ref_set (handleBytes h) t
        ref_set (handleIndex h) 0
        if str_size t == 0 then return (-1) else fileByte h

-- whether bytes read from the file wait to be decoded
fileBuffered      :: Handle -> IO Bool
fileBuffered h    = do
    s <- ref_get (handleBytes h)
    i <- ref_get (handleIndex h)
    return (i < str_size s)

-- The next character of a file, UTF-8. A byte that starts no character is
-- the character of its own value, and so is each byte of one cut short (R5).
fileChar          :: Handle -> IO (Maybe Char)
fileChar h        = do
    b <- fileByte h
    if b < 0 then return Nothing
      else if b < 192 || b >= 248 then return (Just (char_chr b))
      else do
        cs <- bytes (need b)
        case decode b cs of
          Just c  -> return (Just c)
          Nothing -> do
            ahead <- ref_get (handleAhead h)
            ref_set (handleAhead h) (map char_chr cs ++ ahead)
            return (Just (char_chr b))
  where
    need :: Int -> Int
    need b = if b < 224 then 1 else if b < 240 then 2 else 3
    bytes :: Int -> IO [Int]
    bytes 0 = return []
    bytes n = fileByte h >>= \c -> if c < 0 then return [] else bytes (n - 1) >>= \cs -> return (c : cs)
    decode b cs
      | length cs /= need b || not (all (\x -> x >= 128 && x < 192) cs) = Nothing
      | c <= 1114111 = Just (char_chr c)
      | otherwise    = Nothing
      where lead = if b < 224 then 192 else if b < 240 then 224 else 240
            c = foldl (\v x -> v * 64 + (x - 128)) (b - lead) cs

primHGetChar      :: Handle -> IO Char
primHGetChar h    = do
    checkOpen h "hGetChar" handleReads
    m <- readChar h
    case m of
      Just c  -> return c
      Nothing -> endOfFile h "hGetChar"

primHLookAhead    :: Handle -> IO Char
primHLookAhead h  = do
    c <- primHGetChar h
    cs <- ref_get (handleAhead h)
    ref_set (handleAhead h) (c : cs)
    return c

primHIsEOF        :: Handle -> IO Bool
primHIsEOF h      = do
    checkOpen h "hIsEOF" handleReads
    m <- readChar h
    case m of
      Nothing -> return True
      Just c  -> do
        cs <- ref_get (handleAhead h)
        ref_set (handleAhead h) (c : cs)
        return False

-- A line: the end of the file ends one as a newline does where it is not
-- the first character (21.9.2); at the very end, an IOError of the end.
primHGetLine      :: Handle -> IO String
primHGetLine h    = do
    c <- primHGetChar h
    if c == '\n' then return [] else rest [c]
  where
    rest acc = do
      m <- readChar h
      case m of
        Nothing   -> return (reverse acc)
        Just '\n' -> return (reverse acc)
        Just c    -> rest (c : acc)

-- The rest of the handle, read as the list is (21.2.2): the handle is
-- semi-closed, and closed at the end of its file or at a read that fails.
-- The standard input's is getContents, which shares the runtime's buffer.
primHGetContents  :: Handle -> IO String
primHGetContents h = do
    checkOpen h "hGetContents" handleReads
    ref_set (handleState h) 1
    ahead <- ref_get (handleAhead h)
    ref_set (handleAhead h) []
    rest <- if handleFd h == 0 then getContents else lazyRead
    return (ahead ++ rest)
  where
    -- the characters of the bytes read, one read of the file at a time
    lazyRead = interleave (do
      cs <- chunk
      if null cs then primHClose h >> return []
        else lazyRead >>= \more -> return (cs ++ more))
    chunk = do
      m <- fileChar h
      case m of
        Nothing -> return []
        Just c  -> do
          ahead <- ref_get (handleAhead h)
          ref_set (handleAhead h) []
          more <- fileBuffered h
          cs <- if more then chunk else return []
          return (c : ahead ++ cs)

-- whether input waits, or comes within `t` milliseconds (21.9.1); at the
-- end of the file, an IOError of the end
primHWaitForInput :: Handle -> Int -> IO Bool
primHWaitForInput h t = do
    checkOpen h "hWaitForInput" handleReads
    ahead <- ref_get (handleAhead h)
    buffered <- fileBuffered h
    ready <- if not (null ahead) || buffered then return True else primReady (handleFd h) t
    if not ready then return False
      else do
        eof <- primHIsEOF h
        if eof then endOfFile h "hWaitForInput" else return True

-- ---- positions ----

-- the byte the next character is read from: the file's, less the bytes
-- read and not decoded and those of the characters read ahead
position          :: Handle -> String -> IO Integer
position h what   = do
    p <- h_tell (handleFd h)
    if p < 0 then h_errno >>= primFailWith what (Just h) (Just (handleName h))
      else do
        s <- ref_get (handleBytes h)
        i <- ref_get (handleIndex h)
        ahead <- ref_get (handleAhead h)
        return (toInteger (p - (str_size s - i) - sum (map (str_size . str_from_char) ahead)))

primHGetPosn      :: Handle -> IO HandlePosn
primHGetPosn h    = do
    checkOpen h "hGetPosn" handleSeeks
    p <- position h "hGetPosn"
    return (HandlePosn h p)

-- to a byte from the start (mode 0), from here (1), from the end (2)
primHSeek         :: Handle -> Int -> Integer -> IO ()
primHSeek h mode n = do
    checkOpen h "hSeek" handleSeeks
    if handleWrites h then flushed h "hSeek" else return ()
    base <- case mode of
              0 -> return 0
              1 -> position h "hSeek"
              _ -> primHFileSize h
    r <- h_seek (handleFd h) (fromInteger (base + n))
    if r < 0 then h_errno >>= primFailWith "hSeek" (Just h) (Just (handleName h))
      else do
        s <- ref_get (handleBytes h)
        ref_set (handleBytes h) (str_extract s 0 0)
        ref_set (handleIndex h) 0
        ref_set (handleAhead h) []

primHFileSize     :: Handle -> IO Integer
primHFileSize h   = do
    checkOpen h "hFileSize" handleSeeks
    if handleWrites h then flushed h "hFileSize" else return ()
    n <- os_file_size (primPackString (handleName h))
    if n < 0 then sys_errno >>= primFailWith "hFileSize" (Just h) (Just (handleName h))
      else return (toInteger n)

-- ---- opening ----

-- `primOpenFile f mode` opens the file `f` by IOMode's order: ReadMode (0),
-- WriteMode (1), AppendMode (2), ReadWriteMode (3) -- h_open's modes, the
-- last a file read and written through one handle, made where it is not
-- there and kept where it is. A file is open for writing once, or for
-- reading as often as is wanted (21.2.3).
primOpenFile      :: FilePath -> Int -> IO Handle
primOpenFile f mode = do
    locked f mode
    hs <- ref_get handles >>= live
    fd <- h_open (primPackString f) mode
    if fd < 0 then h_errno >>= primFailWith ("openFile: " ++ f) Nothing (Just f)
      else do
        n <- ref_get handleCount
        ref_set handleCount (n + 1)
        h <- newHandle n fd f (mode == 0 || mode == 3) (mode /= 0) (mode /= 2) 2   -- AppendMode's writes go to the end
        ref_set handles (h : hs)
        os <- ref_get opened
        ref_set opened (h : os)
        return h

-- readFile, writeFile and appendFile (7.1), under the locks of 21.2.3.
-- readFile is the runtime's, which reads a chunk at a time, its file held
-- for reading until its contents are read (a hold: a handle of no file in
-- the list of those opened); writeFile and appendFile write through a
-- handle, refused a file held elsewhere, so that a failure of the write,
-- the flush or the close is their IOError (a full device: isFullError).
primReadFile      :: FilePath -> IO String
primReadFile f    = do
    locked f 0
    s <- PreludeBuiltin.primReadFile f
    h <- hold f 0
    return (releasing h s)

primWriteFile, primAppendFile :: FilePath -> String -> IO ()
primWriteFile f s  = primOpenFile f 1 >>= \h -> written h s
primAppendFile f s = primOpenFile f 2 >>= \h -> written h s

-- the string to the handle, then closed, an IOError of either the end
-- (writeFile on a full device: isFullError, from the close's flush)
written           :: Handle -> String -> IO ()
written h s       =  catch (primHPutStr h s) (\e -> catch (primHClose h) (\_ -> return ()) >> ioError e) >> primHClose h

-- an IOError where the file is held so that a handle of the mode may not
-- have it: open for writing anywhere, or for anything where the mode writes
locked            :: FilePath -> Int -> IO ()
locked f mode     = do
    hs <- ref_get handles
    open <- mapM (\h -> ref_get (handleState h) >>= \st -> return (st /= 2)) hs
    if or (zipWith (&&) open (map locks hs))
      then ioError (primMakeIOError AlreadyInUse (f ++ ": file is locked") Nothing (Just f))
      else return ()
  where locks h = handleId h > 2 && handleName h == f && (handleWrites h || mode /= 0)

hold              :: FilePath -> Int -> IO Handle
hold f mode       = do
    n <- ref_get handleCount
    ref_set handleCount (n + 1)
    h <- newHandle n (-1) f (mode == 0) (mode /= 0) False 2
    hs <- ref_get handles >>= live
    ref_set handles (h : hs)
    return h

release           :: Handle -> IO ()
release h         =  ref_set (handleState h) 2

-- the list, its hold released when its end is reached
releasing         :: Handle -> [a] -> [a]
releasing h []    =  unsafe_perform_io (release h) `seq` []
releasing h (x:xs) = x : releasing h xs

-- ---- the end of a program ----

-- exitWith: every handle open for writing flushed, then the end, which
-- catch does not see (23)
primExit          :: Int -> IO a
primExit n        = do
    hs <- ref_get handles
    mapM_ (\h -> if handleWrites h && handleFd h >= 0 then catch (h_flush (handleFd h)) (\_ -> return ()) else return ()) hs
    exit n

-- ---- the system (22 to 27) ----

-- A time: seconds since 1970-01-01 00:00 UTC, and picoseconds (24).
data ClockTime    =  ClockTime Integer Integer

-- `primSystemCall what f call` runs a call of the system that gives 0, or
-- -1 with the reason in sys_errno, and raises that as an IOError about the
-- file `f`
primSystemCall    :: String -> FilePath -> IO Int -> IO ()
primSystemCall what f call = do
    r <- call
    if r >= 0 then return () else sys_errno >>= primFailWith (what ++ ": " ++ f) Nothing (Just f)

os_mkdir, os_rmdir, os_chdir, os_remove :: Str -> IO Int
os_rename         :: Str -> Str -> IO Int
os_getcwd         :: IO Str
-- whether a file can be read (1), written (2) or run (4): 1, 0, or -1
os_access         :: Str -> Int -> IO Int
-- 0 a file, 1 a directory, 2 a link, 3 other, -1 none
os_file_kind      :: Str -> IO Int
-- the time of the last change, in seconds since the epoch, or -1
os_mod_time       :: Str -> IO Int
os_open_dir       :: Str -> IO Int
-- the next name of a directory, or the empty string at its end
os_read_dir       :: Int -> IO Str
os_close_dir      :: Int -> IO Int
os_file_mode      :: Str -> IO Int
os_set_mode       :: Str -> Int -> IO Int
os_system         :: Str -> IO Int
os_getenv         :: Str -> IO Str
os_has_env        :: Str -> IO Bool
command_arg_count :: IO Int
command_arg       :: Int -> IO Str
command_name      :: IO Str
-- microseconds since the epoch, and of processor time, the user's and the
-- system's
time_now          :: IO Int
time_cpu          :: IO Int
-- by how many seconds local time is ahead of UTC at a time, the zone's
-- name, and whether it keeps summer time then
date_offset       :: Int -> IO Int
date_zone_name    :: Int -> IO Str
date_is_dst       :: Int -> IO Bool
-- a number from the system's randomness, or from the clock where it has none
random_seed       :: IO Int
