-- Module PreludeBuiltin: rhc's primitives, the module the Report's code
-- imports ("Contains all `prim' values") and defines nowhere. It is rhc's,
-- not the Report's (overlay ov.prelude.imports), and a program cannot import
-- it. It is in the Prelude's unit, whose types its signatures name.
--
-- The convention of rhc's library for a primitive (the haskell98 roadmap's
-- D26, A: no SML below Haskell):
--   * a type signature with no binding declares a primitive of Core
--     (lib/language/haskell/coreprim_sig.sml), under CorePrim's own name;
--     its Haskell type stands for CorePrim's, with no `!`, and IO t for
--     Core's World -> (utuple World t);
--   * a data declaration with no constructors declares a type of Core's:
--     the Prelude's Int, Integer, Char, Float, Double and IO a, and here
--     Str (bytes), Exn (an exception), Ref a (a cell) and Arr a (an array).
-- What the library builds on them is below, in Haskell: the Report's prim*
-- names, strings of bytes, and the representations of Handle and IOError,
-- which IO and PreludeIO share (overlay ov.io.handles, ov.preludeio.ioerror).

module PreludeBuiltin (
    Str, Exn, Ref, Arr,

    -- Core's primitives that the library names outside this module
    int_add, int_sub, int_mul, int_quot, int_rem, int_div, int_mod, int_neg,
    int_eq, int_ne, int_lt, int_le, int_gt, int_ge, int_min, int_max,
    integer_add, integer_sub, integer_mul, integer_quot, integer_rem,
    integer_div, integer_mod, integer_neg,
    integer_eq, integer_ne, integer_lt, integer_le, integer_gt, integer_ge,
    integer_from_int, integer_to_int, integer_to_double, char_ord, char_chr,
    double_add, double_sub, double_mul, double_div, double_neg, double_abs,
    double_eq, double_ne, double_lt, double_le, double_gt, double_ge,
    double_from_int, double_sqrt, double_exp, double_log, double_sin,
    double_cos, double_tan, double_atan, double_atan2, double_sinh,
    double_cosh, double_tanh, double_pow, double_is_nan,
    double_mantissa, double_exponent, double_encode,
    float_from_double, float_to_double,
    arr_new, arr_read, arr_get, arr_set, arr_size,
    io_return, io_bind, io_interleave, unsafe_perform_io,
    ref_new, ref_get, ref_set,
    str_size, str_byte, str_concat, str_from_char, str_empty,
    file_open, file_close, file_write, file_flush, file_read, file_avail,
    file_tell, file_seek, file_errno, file_error, file_size, file_wait,
    sys_errno, sys_error_message,

    -- the Report's prim* names
    primError, primIntToChar, primCharToInt, primSeq,
    primIOError, primUserError, primCatch, primPutChar, primGetChar,
    primGetContents, primReadFile, primWriteFile, primAppendFile,

    -- strings of bytes
    primPackStr, primUnpackStr, primUnpackStrFrom, primDecode,

    -- Handle and IOError
    Handle(..), HandlePosn(..), IOError(..), IOErrorKind(..),
    primNewHandle, primStdin, primStdout, primStderr,
    primFailWith, primErrnoKind,
    primHandleEq, primHandleShow, primOpenFile, primHClose, primHFileSize,
    primHIsEOF, primHSetBuffering, primHGetBuffering, primHFlush,
    primHGetPosn, primHSeek, primHWaitForInput, primHGetChar, primHGetLine,
    primHLookAhead, primHGetContents, primHPutChar, primHPutStr,
    primHIsOpen, primHIsClosed, primHIsReadable, primHIsWritable,
    primHIsSeekable, primExit, primFlushAll,

    -- the system (22 to 27)
    ClockTime(..), primSystemCall,
    os_mkdir, os_rmdir, os_chdir, os_remove, os_rename, os_getcwd, os_access,
    os_file_kind, os_mod_time, os_open_dir, os_read_dir, os_close_dir,
    os_file_mode, os_set_mode, os_system, os_getenv, os_has_env,
    command_arg_count, command_arg, command_name, time_now, time_cpu,
    date_offset, date_zone_name, date_is_dst, random_seed,

    -- the end of a program (3.1, 7.3, 23)
    primRunMain,

    -- what rhc's interim reader (src/rhc/library.sml, M12) binds a signature
    -- with no binding to, here and in M18's modules until their code is
    -- written; it goes when the reader takes the convention above
    primElided
  ) where

import Prelude (Bool(..), Int, Integer, Char, Float, Double, IO, String,
                Maybe(..), FilePath, (.), ($), (++), (&&), (||), not, otherwise, map)

-- ---- Core's types that are not the Prelude's ----

data Str
data Exn
data Ref a
data Arr a

-- ---- Core's primitives ----

-- Int: Mid's int, on the checked primitives (D22): past Int's range an
-- arithmetic raises Overflow, a division by 0 Div
int_add, int_sub, int_mul, int_quot, int_rem, int_div, int_mod
                  :: Int -> Int -> Int
int_neg           :: Int -> Int
int_eq, int_ne, int_lt, int_le, int_gt, int_ge
                  :: Int -> Int -> Bool
int_min, int_max  :: Int

-- Integer: IntInf's representation, an immediate small value and IntInf's
-- signed magnitudes (D20, D; M31)
integer_add, integer_sub, integer_mul, integer_quot, integer_rem,
 integer_div, integer_mod
                  :: Integer -> Integer -> Integer
integer_neg       :: Integer -> Integer
integer_eq, integer_ne, integer_lt, integer_le, integer_gt, integer_ge
                  :: Integer -> Integer -> Bool
integer_from_int  :: Int -> Integer
integer_to_int    :: Integer -> Int
integer_to_double :: Integer -> Double

-- Char: a code point in a Mid int, 0 to 0x10FFFF (D21)
char_ord          :: Char -> Int
char_chr          :: Int -> Char

-- Double: Mid's real, a binary64
double_add, double_sub, double_mul, double_div, double_pow, double_atan2
                  :: Double -> Double -> Double
double_neg, double_abs, double_sqrt, double_exp, double_log, double_sin,
 double_cos, double_tan, double_atan, double_sinh, double_cosh, double_tanh
                  :: Double -> Double
double_eq, double_ne, double_lt, double_le, double_gt, double_ge
                  :: Double -> Double -> Bool
double_is_nan     :: Double -> Bool
double_from_int   :: Int -> Double
-- decodeFloat's two halves, and encodeFloat (6.4.6)
double_mantissa   :: Double -> Integer
double_exponent   :: Double -> Int
double_encode     :: Integer -> Int -> Double

-- Float: a binary64 rounded to binary32 after each operation (D23, B)
float_from_double :: Double -> Float
float_to_double   :: Float -> Double

-- Str: bytes, a character's in UTF-8
str_size          :: Str -> Int
str_byte          :: Str -> Int -> Int
str_concat        :: Str -> Str -> Str
str_from_char     :: Char -> Str
str_empty         :: Str

-- arrays, for Array's representation (ov.array.representation)
arr_new           :: Int -> a -> IO (Arr a)
arr_set           :: Arr a -> Int -> a -> IO ()
arr_read          :: Arr a -> Int -> IO a
arr_get           :: Arr a -> Int -> a
arr_size          :: Arr a -> Int

-- IO: an action takes the state and gives it back with its value (D25, B)
io_return         :: a -> IO a
io_bind           :: IO a -> (a -> IO b) -> IO b
io_interleave     :: IO a -> IO a
unsafe_perform_io :: IO a -> a
seq               :: a -> b -> b
exit              :: Int -> IO a
ref_new           :: a -> IO (Ref a)
ref_get           :: Ref a -> IO a
ref_set           :: Ref a -> a -> IO ()

-- files, by the number of an open one: 0, 1 and 2 are the standard input,
-- output and error; a failure is -1, or False, and file_errno says why
file_open         :: Str -> Int -> IO Int
file_close        :: Int -> IO ()
file_write        :: Int -> Str -> IO Bool
file_flush        :: Int -> IO ()
file_read         :: Int -> Int -> IO Str
file_avail        :: Int -> IO Int
-- whether input comes within some milliseconds (os_poll's)
file_wait         :: Int -> Int -> IO Bool
file_tell         :: Int -> IO Int
file_seek         :: Int -> Int -> IO Int
file_size         :: Str -> IO Integer
file_errno        :: IO Int
file_error        :: IO Str
sys_errno         :: IO Int
sys_error_message :: Int -> Str
sys_error_name    :: Int -> Str

-- the interim reader's (above)
primElided        :: a

-- exceptions
raise             :: Exn -> a
raise_io          :: Exn -> IO a
exn_error         :: Str -> Exn
exn_io_with       :: a -> Str -> Exn
exn_has_value     :: Exn -> Bool
exn_value         :: Exn -> a
exn_kind          :: Exn -> Int
exn_message       :: Exn -> Str
-- CorePrim's catch, which takes every exception (renamed, L asks of B: a
-- primitive named catch would make a second fixpoint of names with PreludeIO's)
catch_all         :: IO a -> (Exn -> IO a) -> IO a

-- ---- helpers of this module ----

(>>>=) :: IO a -> (a -> IO b) -> IO b
(>>>=) = io_bind
infixl 1 >>>=

(>>>) :: IO a -> IO b -> IO b
m >>> k = m `io_bind` \_ -> k
infixl 1 >>>

-- ---- strings of bytes ----

-- `primPackStr s` is the bytes of the characters `s` in UTF-8.
primPackStr       :: String -> Str
primPackStr []    =  str_empty
primPackStr (c:cs) = str_concat (str_from_char c) (primPackStr cs)

-- `primUnpackStr s` is the characters of the bytes `s`, decoded as UTF-8
-- and unpacked lazily: what a string literal is (D24, A).
primUnpackStr     :: Str -> String
primUnpackStr s   =  primUnpackStrFrom s 0

primUnpackStrFrom :: Str -> Int -> String
primUnpackStrFrom s i =
    if int_ge i (str_size s) then []
    else case primDecode s i of
           (c, j) -> c : primUnpackStrFrom s j

-- `primDecode s i` is the character of UTF-8 at byte `i` of `s` and the
-- index after it. A byte that starts no character, or a character cut
-- short by the end, is the character of its own value (R5: a character of
-- a file is never refused).
primDecode        :: Str -> Int -> (Char, Int)
primDecode s i
  | int_lt b 128                       = (char_chr b, int_add i 1)
  | int_ge b 240 && int_lt b 248 && ok 3 = (char_chr (four ()), int_add i 4)
  | int_ge b 224 && int_lt b 240 && ok 2 = (char_chr (three ()), int_add i 3)
  | int_ge b 192 && int_lt b 224 && ok 1 = (char_chr (two ()), int_add i 2)
  | otherwise                          = (char_chr b, int_add i 1)
  where
    b = str_byte s i
    cont k = int_sub (str_byte s (int_add i k)) 128
    isCont k = int_ge (cont k) 0 && int_lt (cont k) 64
    conts k = if int_eq k 0 then True else isCont k && conts (int_sub k 1)
    ok k = int_lt (int_add i k) (str_size s) && conts k
           && (int_lt k 3 || int_le (four ()) 1114111)
    two ()   = int_add (int_mul (int_sub b 192) 64) (cont 1)
    three () = int_add (int_mul (int_sub b 224) 4096) (int_add (int_mul (cont 1) 64) (cont 2))
    four ()  = int_add (int_mul (int_sub b 240) 262144)
                       (int_add (int_mul (cont 1) 4096) (int_add (int_mul (cont 2) 64) (cont 3)))

-- ---- the Report's prim* names ----

primSeq           :: a -> b -> b
primSeq           =  seq

primIntToChar     :: Int -> Char
primIntToChar     =  char_chr

primCharToInt     :: Char -> Int
primCharToInt     =  char_ord

-- error: ErrorCall, which catch does not see (3.1, R36)
primError         :: String -> a
primError s       =  raise (exn_error (primPackStr s))

-- ---- IOError (7.3, 21.1) ----

-- The kinds of 21.1's predicates, and a user's error.
data IOErrorKind  =  AlreadyExists | DoesNotExist | AlreadyInUse | Full
                  |  EOF | IllegalOperation | Permission | User | Other

-- An IOError: its kind, its text, the handle and the file it is about.
data IOError      =  IOError IOErrorKind String (Maybe Handle) (Maybe FilePath)

primUserError     :: String -> IOError
primUserError s   =  IOError User s Nothing Nothing

-- ioError: an exception of Core's kind IOError, which carries the IOError
-- and its text
primIOError       :: IOError -> IO a
primIOError e     =  raise_io (exn_io_with e (primPackStr (text e)))
  where text (IOError _ s _ _) = s

-- catch sees an IOError and nothing else, which it raises again (7.3)
primCatch         :: IO a -> (IOError -> IO a) -> IO a
primCatch m h     =  catch_all m handler
  where
    handler x
      | int_eq (exn_kind x) 1 =
          if exn_has_value x then h (exn_value x)
          else h (IOError Other (primUnpackStr (exn_message x)) Nothing Nothing)
      | otherwise             = raise_io x

-- `primErrnoKind n` is the kind of an IOError of the system's error `n`,
-- by its name, as the system's library names it (sys_error_name)
primErrnoKind     :: Int -> IOErrorKind
primErrnoKind n   =  kind (primUnpackStr (sys_error_name n))
  where
    kind e
      | e `is` ["EEXIST", "ENOTEMPTY"]          = AlreadyExists
      | e `is` ["ENOENT", "ENOTDIR"]            = DoesNotExist
      | e `is` ["EBUSY", "ETXTBSY"]             = AlreadyInUse
      | e `is` ["ENOSPC", "EDQUOT", "EFBIG"]    = Full
      | e `is` ["EACCES", "EPERM", "EROFS"]     = Permission
      | otherwise                               = IllegalOperation
    is e names = any (same e) names
    any p []     = False
    any p (x:xs) = p x || any p xs
    same [] []         = True
    same (a:as) (b:bs) = int_eq (char_ord a) (char_ord b) && same as bs
    same _ _           = False

-- `primFailWith what h f errno` raises the IOError of the system's error
-- `errno`, from the operation `what` on the handle `h` or the file `f`
primFailWith      :: String -> Maybe Handle -> Maybe FilePath -> Int -> IO a
primFailWith what h f errno =
    primIOError (IOError (primErrnoKind errno)
                         (what ++ ": " ++ primUnpackStr (sys_error_message errno))
                         h f)

-- ---- Handle (21.2) ----

-- A handle: a number of its own, for Eq; the number of its file; what it
-- shows as; whether it reads, writes, seeks; and its state, whose changes
-- every copy of it sees:
--   * open (0), semi-closed (1, by hGetContents) or closed (2);
--   * the characters read ahead, by hLookAhead, or the bytes of a
--     character cut by the end of a block;
--   * its buffering: 0 none, 1 by line, 2 by block (BufferMode's order),
--     with the size of a block, 0 for the system's;
--   * whether it has met the end of its file.
data Handle       =  Handle Int Int String Bool Bool Bool
                            (Ref Int) (Ref [Char]) (Ref Int) (Ref Int) (Ref Bool)

-- A position: the handle, and the byte from its file's start.
data HandlePosn   =  HandlePosn Handle Integer

handleCount       :: Ref Int
handleCount       =  unsafe_perform_io (ref_new 3)

primNewHandle     :: Int -> String -> Bool -> Bool -> Bool -> Int -> IO Handle
primNewHandle fd name r w s buffering =
    ref_get handleCount                     >>>= \n ->
    ref_set handleCount (int_add n 1)       >>>
    ref_new 0                               >>>= \state ->
    ref_new []                              >>>= \ahead ->
    ref_new buffering                       >>>= \mode ->
    ref_new 0                               >>>= \size ->
    ref_new False                           >>>= \eof ->
    io_return (Handle n fd name r w s state ahead mode size eof)

-- The standard handles: created once, the first time a program names one.
-- stdin and stdout are buffered by line, as a terminal's are; stderr is
-- not buffered (21.6 leaves the default to the implementation).
primStdin, primStdout, primStderr :: Handle
primStdin         =  unsafe_perform_io (primStandard 0 "<stdin>" True False 1)
primStdout        =  unsafe_perform_io (primStandard 1 "<stdout>" False True 1)
primStderr        =  unsafe_perform_io (primStandard 2 "<stderr>" False True 0)

primStandard      :: Int -> String -> Bool -> Bool -> Int -> IO Handle
primStandard fd name r w mode =
    ref_new 0                               >>>= \state ->
    ref_new []                              >>>= \ahead ->
    ref_new mode                            >>>= \m ->
    ref_new 0                               >>>= \size ->
    ref_new False                           >>>= \eof ->
    io_return (Handle fd fd name r w False state ahead m size eof)

-- ---- the end of a program ----

-- `primRunMain main` runs a program's `main`, and ends the program: with
-- status 0, or with 1 where an exception escapes `main`, whose text is
-- written to the standard error, an IOError's as the Prelude shows it
-- (7.3) and an error's (3.1) after the program's own output. The standard
-- output is flushed before the program ends (23).
primRunMain       :: (IOError -> String) -> IO a -> IO ()
primRunMain showIOError main =
    catch_all (main >>> primFlushAll >>> exit 0) failure
  where
    failure x =
      primFlushAll                          >>>
      file_write 2 (primPackStr (message x ++ "\n")) >>>
      exit 1
    message x
      | int_eq (exn_kind x) 1 && exn_has_value x = showIOError (exn_value x)
      | otherwise = primUnpackStr (exn_message x)

-- ---- the operations of handles (21; IO binds the Report's names to them) ----

handleId (Handle n _ _ _ _ _ _ _ _ _ _) = n
handleFd (Handle _ fd _ _ _ _ _ _ _ _ _) = fd
handleName (Handle _ _ name _ _ _ _ _ _ _ _) = name
handleReads (Handle _ _ _ r _ _ _ _ _ _ _) = r
handleWrites (Handle _ _ _ _ w _ _ _ _ _ _) = w
handleSeeks (Handle _ _ _ _ _ s _ _ _ _ _) = s
handleState (Handle _ _ _ _ _ _ st _ _ _ _) = st
handleAhead (Handle _ _ _ _ _ _ _ a _ _ _) = a
handleMode (Handle _ _ _ _ _ _ _ _ m _ _) = m
handleSize (Handle _ _ _ _ _ _ _ _ _ sz _) = sz
handleEof (Handle _ _ _ _ _ _ _ _ _ _ e) = e

primHandleEq      :: Handle -> Handle -> Bool
primHandleEq h k  =  int_eq (handleId h) (handleId k)

primHandleShow    :: Handle -> String
primHandleShow h  =  "{handle: " ++ handleName h ++ "}"

-- an IOError of this handle's
illegal           :: Handle -> String -> IO a
illegal h what    =  primIOError (IOError IllegalOperation (what ++ ": illegal operation")
                                          (Just h) (Just (handleName h)))

endOfFile         :: Handle -> String -> IO a
endOfFile h what  =  primIOError (IOError EOF (what ++ ": end of file") (Just h) (Just (handleName h)))

-- the handle open (0) or semi-closed (1, which reads nothing), and able to
-- do what `ok` says, or an IOError
checkOpen         :: Handle -> String -> (Handle -> Bool) -> IO ()
checkOpen h what ok =
    ref_get (handleState h)                 >>>= \st ->
    if int_eq st 0 && ok h then io_return () else illegal h what

primHClose        :: Handle -> IO ()
primHClose h      =
    ref_get (handleState h)                 >>>= \st ->
    if int_eq st 2 then io_return ()
    else (if handleWrites h then file_flush (handleFd h) else io_return ()) >>>
         file_close (handleFd h)            >>>
         ref_set (handleState h) 2          >>>
         primForget h

primHIsOpen, primHIsClosed :: Handle -> IO Bool
primHIsOpen h     =  ref_get (handleState h) >>>= \st -> io_return (int_eq st 0)
primHIsClosed h   =  ref_get (handleState h) >>>= \st -> io_return (int_eq st 2)

primHIsReadable, primHIsWritable, primHIsSeekable :: Handle -> IO Bool
primHIsReadable h =  usable h "hIsReadable" >>> io_return (handleReads h)
primHIsWritable h =  usable h "hIsWritable" >>> io_return (handleWrites h)
primHIsSeekable h =  usable h "hIsSeekable" >>> io_return (handleSeeks h)

-- neither closed nor semi-closed
usable            :: Handle -> String -> IO ()
usable h what     =  checkOpen h what (\_ -> True)

-- ---- writing ----

-- a character written, and the buffer flushed as the mode says: none (0),
-- at a newline (1)
primHPutChar      :: Handle -> Char -> IO ()
primHPutChar h c  =
    checkOpen h "hPutChar" handleWrites     >>>
    file_write (handleFd h) (str_from_char c) >>>= \ok ->
    if not ok then file_errno >>>= primFailWith "hPutChar" (Just h) (Just (handleName h))
    else ref_get (handleMode h)             >>>= \mode ->
         if int_eq mode 0 || (int_eq mode 1 && int_eq (char_ord c) 10)
         then file_flush (handleFd h)
         else io_return ()

-- the characters, each as it is evaluated, so that what comes before a
-- bottom is written
primHPutStr       :: Handle -> String -> IO ()
primHPutStr h []     =  io_return ()
primHPutStr h (c:cs) =  primHPutChar h c >>> primHPutStr h cs

primHFlush        :: Handle -> IO ()
primHFlush h      =  checkOpen h "hFlush" handleWrites >>> file_flush (handleFd h)

primHSetBuffering :: Handle -> Int -> Int -> IO ()
primHSetBuffering h mode size =
    usable h "hSetBuffering"                >>>
    (if handleWrites h then file_flush (handleFd h) else io_return ()) >>>
    ref_set (handleMode h) mode             >>>
    ref_set (handleSize h) size

primHGetBuffering :: Handle -> IO (Int, Int)
primHGetBuffering h =
    usable h "hGetBuffering"                >>>
    ref_get (handleMode h)                  >>>= \mode ->
    ref_get (handleSize h)                  >>>= \size ->
    io_return (mode, size)

-- ---- reading ----

-- the next byte of the file, or -1 at its end
readByte          :: Handle -> IO Int
readByte h        =
    file_read (handleFd h) 1                >>>= \s ->
    if int_eq (str_size s) 0 then ref_set (handleEof h) True >>> io_return (-1)
    else io_return (str_byte s 0)

-- the next character, UTF-8, read byte by byte; Nothing at the end. A
-- byte that starts no character is the character of its own value, and
-- so is each byte of a character cut short (R5).
readChar          :: Handle -> IO (Maybe Char)
readChar h        =
    readByte h                              >>>= \b ->
    if int_lt b 0 then io_return Nothing
    else if int_lt b 192 || int_ge b 248 then io_return (Just (char_chr b))
    else bytes (if int_lt b 224 then 1 else if int_lt b 240 then 2 else 3) [] >>>= \cs ->
         case decodeUtf8 b cs of
           Just c  -> io_return (Just c)
           Nothing -> ref_get (handleAhead h) >>>= \ahead ->
                      ref_set (handleAhead h) (map char_chr cs ++ ahead) >>>
                      io_return (Just (char_chr b))
  where
    bytes n acc = if int_eq n 0 then io_return (rev acc [])
                  else readByte h >>>= \c ->
                       if int_lt c 0 then io_return (rev acc [])
                       else bytes (int_sub n 1) (c : acc)
    rev [] a = a
    rev (x:xs) a = rev xs (x:a)

-- the character of a lead byte and its continuation bytes, if they are one
decodeUtf8        :: Int -> [Int] -> Maybe Char
decodeUtf8 b cs   =
    if not (all cont cs) || not (int_eq (length cs) need) then Nothing
    else let c = foldl (\v x -> int_add (int_mul v 64) (int_sub x 128)) (int_sub b lead) cs
         in if int_le c 1114111 then Just (char_chr c) else Nothing
  where
    need = if int_lt b 224 then 1 else if int_lt b 240 then 2 else 3
    lead = if int_lt b 224 then 192 else if int_lt b 240 then 224 else 240
    cont x = int_ge x 128 && int_lt x 192
    all p [] = True
    all p (x:xs) = p x && all p xs
    length [] = 0
    length (_:xs) = int_add 1 (length xs)
    foldl f z [] = z
    foldl f z (x:xs) = foldl f (f z x) xs

-- the next character, the one read ahead first
primHGetChar      :: Handle -> IO Char
primHGetChar h    =
    checkOpen h "hGetChar" handleReads      >>>
    ref_get (handleAhead h)                 >>>= \ahead ->
    case ahead of
      (c:cs) -> ref_set (handleAhead h) cs >>> io_return c
      []     -> readChar h >>>= \m ->
                case m of
                  Just c  -> io_return c
                  Nothing -> endOfFile h "hGetChar"

primHLookAhead    :: Handle -> IO Char
primHLookAhead h  =
    primHGetChar h                          >>>= \c ->
    ref_get (handleAhead h)                 >>>= \cs ->
    ref_set (handleAhead h) (c : cs)        >>>
    io_return c

primHIsEOF        :: Handle -> IO Bool
primHIsEOF h      =
    checkOpen h "hIsEOF" handleReads        >>>
    ref_get (handleAhead h)                 >>>= \ahead ->
    case ahead of
      (_:_) -> io_return False
      []    -> readChar h >>>= \m ->
               case m of
                 Nothing -> io_return True
                 Just c  -> ref_set (handleAhead h) [c] >>> io_return False

-- a line, the end of the file ending it as a newline does where it is not
-- the first character (21.9.2); at the very end, an IOError of EOF
primHGetLine      :: Handle -> IO String
primHGetLine h    =
    primHGetChar h                          >>>= \c ->
    if int_eq (char_ord c) 10 then io_return [] else rest [c]
  where
    rest acc = primHIsEOF h >>>= \eof ->
               if eof then io_return (reverse acc)
               else primHGetChar h >>>= \c ->
                    if int_eq (char_ord c) 10 then io_return (reverse acc) else rest (c : acc)
    reverse xs = rev xs []
    rev [] a = a
    rev (x:xs) a = rev xs (x:a)

-- the rest of the handle, read as it is needed (21.2.2): the handle is
-- semi-closed, and a read that fails ends the list
primHGetContents  :: Handle -> IO String
primHGetContents h =
    checkOpen h "hGetContents" handleReads  >>>
    ref_set (handleState h) 1               >>>
    ref_get (handleAhead h)                 >>>= \ahead ->
    ref_set (handleAhead h) []              >>>
    lazyRead str_empty                      >>>= \rest ->
    io_return (ahead ++ rest)
  where
    -- at the end, or at a read that fails, the handle is closed (21.2.2)
    lazyRead carry = io_interleave (
        catch_all (file_read (handleFd h) 4096) (\_ -> io_return str_empty) >>>= \s ->
        if int_eq (str_size s) 0
        then primHClose h >>> io_return (primUnpackStr carry)
        else case complete (str_concat carry s) of
               (done, left) -> lazyRead left >>>= \more -> io_return (done ++ more))
    -- the characters of all but a character cut short by the end, and the
    -- bytes of that character
    complete s = let k = cut s in (primUnpackPrefix s k, str_suffix s k)
    -- where a character cut short at the end starts, or the size
    cut s = back (int_sub (str_size s) 1) 0
      where
        back i n
          | int_lt i 0 || int_gt n 3 = str_size s
          | int_ge b 128 && int_lt b 192 = back (int_sub i 1) (int_add n 1)
          | int_ge b 192 && int_lt b 248 && int_gt (int_add i (need b)) (str_size s) = i
          | otherwise = str_size s
          where b = str_byte s i
    need b = if int_lt b 224 then 2 else if int_lt b 240 then 3 else 4

-- the characters of the first `k` bytes of `s`
primUnpackPrefix  :: Str -> Int -> String
primUnpackPrefix s k = go 0
  where go i = if int_ge i k then [] else case primDecode s i of (c, j) -> c : go j

-- the bytes of `s` from `k` on
str_suffix        :: Str -> Int -> Str
str_suffix s k    =  str_slice s k (int_sub (str_size s) k)

str_slice         :: Str -> Int -> Int -> Str

-- whether input waits, or comes within `t` milliseconds (21.9.1); at the
-- end of the file, an IOError of EOF
primHWaitForInput :: Handle -> Int -> IO Bool
primHWaitForInput h t =
    checkOpen h "hWaitForInput" handleReads >>>
    ref_get (handleAhead h)                 >>>= \ahead ->
    case ahead of
      (_:_) -> io_return True
      []    -> file_wait (handleFd h) t >>>= \ready ->
               if not ready then io_return False
               else primHIsEOF h >>>= \eof ->
                    if eof then endOfFile h "hWaitForInput" else io_return True

-- ---- positions ----

primHGetPosn      :: Handle -> IO HandlePosn
primHGetPosn h    =
    usable h "hGetPosn"                     >>>
    file_tell (handleFd h)                  >>>= \p ->
    if int_lt p 0 then illegal h "hGetPosn"
    else ref_get (handleAhead h)            >>>= \ahead ->
         io_return (HandlePosn h (integer_sub (integer_from_int p) (integer_from_int (bytesOf ahead))))
  where bytesOf [] = 0
        bytesOf (c:cs) = int_add (str_size (str_from_char c)) (bytesOf cs)

-- seek to a byte from the start (mode 0), from here (1), from the end (2)
primHSeek         :: Handle -> Int -> Integer -> IO ()
primHSeek h mode n =
    checkOpen h "hSeek" handleSeeks         >>>
    (if handleWrites h then file_flush (handleFd h) else io_return ()) >>>
    base                                    >>>= \b ->
    file_seek (handleFd h) (integer_to_int (integer_add b n)) >>>= \r ->
    if int_lt r 0 then file_errno >>>= primFailWith "hSeek" (Just h) (Just (handleName h))
    else ref_set (handleAhead h) [] >>> ref_set (handleEof h) False
  where
    base | int_eq mode 0 = io_return 0
         | int_eq mode 1 = file_tell (handleFd h) >>>= \p ->
                           ref_get (handleAhead h) >>>= \ahead ->
                           io_return (integer_from_int (int_sub p (int_lenBytes ahead)))
         | otherwise     = file_size (primPackStr (handleName h))
    int_lenBytes [] = 0
    int_lenBytes (c:cs) = int_add (str_size (str_from_char c)) (int_lenBytes cs)

primHFileSize     :: Handle -> IO Integer
primHFileSize h   =  checkOpen h "hFileSize" handleSeeks >>> file_size (primPackStr (handleName h))

-- ---- opening ----

-- the files open, by name and whether for writing: a file is open for
-- writing once, or for reading as often as is wanted (21.2.3)
openFiles         :: Ref [(String, Bool, Handle)]
openFiles         =  unsafe_perform_io (ref_new [])

primForget        :: Handle -> IO ()
primForget h      =  ref_get openFiles >>>= \fs -> ref_set openFiles (drop fs)
  where drop [] = []
        drop ((n, w, k) : fs) = if int_eq (handleId k) (handleId h) then fs else (n, w, k) : drop fs

-- `primOpenFile f mode` opens the file `f` by IOMode's order: ReadMode (0),
-- WriteMode (1), AppendMode (2), ReadWriteMode (3)
primOpenFile      :: FilePath -> Int -> IO Handle
primOpenFile f mode =
    ref_get openFiles                       >>>= \fs ->
    if locked fs then primIOError (IOError AlreadyInUse ("openFile: " ++ f ++ ": file is locked")
                                           Nothing (Just f))
    else if int_eq mode 3 then primIOError (IOError IllegalOperation
                                   ("openFile: " ++ f ++ ": ReadWriteMode is not supported") Nothing (Just f))
    else file_open (primPackStr f) mode     >>>= \fd ->
         if int_lt fd 0 then file_errno >>>= primFailWith ("openFile: " ++ f) Nothing (Just f)
         else primNewHandle fd f (int_eq mode 0) (not (int_eq mode 0)) (int_eq mode 0) 2 >>>= \h ->
              ref_set openFiles ((f, writes, h) : fs) >>>
              io_return h
  where
    writes = not (int_eq mode 0)
    locked [] = False
    locked ((g, w, _) : fs) = (same f g && (w || writes)) || locked fs
    same [] [] = True
    same (a:as) (b:bs) = int_eq (char_ord a) (char_ord b) && same as bs
    same _ _ = False

-- ---- the Report's prim* names of PreludeIO, on the standard handles ----

primPutChar       :: Char -> IO ()
primPutChar       =  primHPutChar primStdout

primGetChar       :: IO Char
primGetChar       =  primHGetChar primStdin

primGetContents   :: IO String
primGetContents   =  primHGetContents primStdin

primReadFile      :: FilePath -> IO String
primReadFile f    =  primOpenFile f 0 >>>= primHGetContents

primWriteFile     :: FilePath -> String -> IO ()
primWriteFile f s =  primOpenFile f 1 >>>= \h -> primHPutStr h s >>> primHClose h

primAppendFile    :: FilePath -> String -> IO ()
primAppendFile f s = primOpenFile f 2 >>>= \h -> primHPutStr h s >>> primHClose h

-- ---- the end of a program, and the system (22 to 27) ----

-- every handle open for writing flushed, and the standard output (23)
primFlushAll      :: IO ()
primFlushAll      =  ref_get openFiles >>>= \fs -> flush fs >>> file_flush 1 >>> file_flush 2
  where flush [] = io_return ()
        flush ((_, w, h) : fs) = (if w then catch_all (file_flush (handleFd h)) (\_ -> io_return ()) else io_return ()) >>> flush fs

-- exitWith: the handles flushed, the program ended, which catch does not see
primExit          :: Int -> IO a
primExit n        =  primFlushAll >>> exit n

-- A time: seconds since 1970-01-01 00:00 UTC, and picoseconds (24).
data ClockTime    =  ClockTime Integer Integer

-- `primSystemCall what f call` runs a call of the system that gives 0, or
-- -1 with the reason in sys_errno, and raises that as an IOError about the
-- file `f`
primSystemCall    :: String -> FilePath -> IO Int -> IO ()
primSystemCall what f call =
    call                                    >>>= \r ->
    if int_ge r 0 then io_return ()
    else sys_errno >>>= primFailWith (what ++ ": " ++ f) Nothing (Just f)

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
-- microseconds since the epoch; of processor time, the user's and the system's
time_now          :: IO Int
time_cpu          :: IO Int
-- by how many seconds local time is ahead of UTC at a time, the zone's
-- name and whether it keeps summer time then
date_offset       :: Int -> IO Int
date_zone_name    :: Int -> IO Str
date_is_dst       :: Int -> IO Bool
-- a number from the system's randomness, or from the clock where it has none
random_seed       :: IO Int
