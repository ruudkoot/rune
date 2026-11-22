-- rows: lib.char.islatin1.def lib.char.iscontrol.def lib.char.isspace.def lib.char.isdigit.def lib.char.isoctdigit.def lib.char.ishexdigit.def lib.char.digittoint lib.char.inttodigit lib.char.ord lib.char.chr lib.char.readlitchar lib.char.readesc lib.char.match lib.char.showlitchar lib.char.protectesc.def lib.char.asciitab.def lib.char.lexlitchar R154
-- Report 19.1: the functions of Char against the Report's own module copied under new names, over the Latin-1 range:
-- the predicates the code defines, the digits, ord and chr, showLitChar (protectEsc, asciiTab) before "", a digit
-- and H, and readLitChar (readEsc, match) and lexLitChar on what it shows and on escapes of each form, each
-- line the inputs where the two differ. lexLitChar is compared where the code and readings.md R154 agree (not on a
-- named escape before an upper-case letter or a digit, an unknown one, or \o or \x with no digit: see
-- lib.r.char.lexlitchar_named). The
-- primitives (isPrint, isUpper, isLower, isAlphaNum, toUpper, toLower) are the library's own.
module Main (main) where

import Char
import Array
import Numeric (readDec, readOct, lexDigits, readHex)
import qualified Char as C

-- Character-testing operations
isAscii_r, isLatin1_r, isControl_r, isPrint_r, isSpace_r, isUpper_r, isLower_r,
 isAlpha_r, isDigit_r, isOctDigit_r, isHexDigit_r, isAlphaNum_r :: Char -> Bool

isAscii_r c                =  c < '\x80'

isLatin1_r c               =  c <= '\xff'

isControl_r c              =  c < ' ' || c >= '\DEL' && c <= '\x9f'

isPrint_r                  =  primUnicodeIsPrint

isSpace_r c                =  c `elem` " \t\n\r\f\v\xA0"
        -- Only Latin-1 spaces recognized

isUpper_r                  =  primUnicodeIsUpper  -- 'A'..'Z'

isLower_r                  =  primUnicodeIsLower  -- 'a'..'z'

isAlpha_r c                =  isUpper_r c || isLower_r c

isDigit_r c                =  c >= '0' && c <= '9'

isOctDigit_r c             =  c >= '0' && c <= '7'

isHexDigit_r c             =  isDigit_r c || c >= 'A' && c <= 'F' ||
                                         c >= 'a' && c <= 'f'

isAlphaNum_r               =  primUnicodeIsAlphaNum


-- Digit conversion operations
digitToInt_r :: Char -> Int
digitToInt_r c
  | isDigit_r c            =  fromEnum c - fromEnum '0'
  | c >= 'a' && c <= 'f' =  fromEnum c - fromEnum 'a' + 10
  | c >= 'A' && c <= 'F' =  fromEnum c - fromEnum 'A' + 10
  | otherwise            =  error "Char.digitToInt_r: not a digit"

intToDigit_r :: Int -> Char
intToDigit_r i
  | i >= 0  && i <=  9   =  toEnum (fromEnum '0' + i)
  | i >= 10 && i <= 15   =  toEnum (fromEnum 'a' + i - 10)
  | otherwise            =  error "Char.intToDigit_r: not a digit"


-- Case-changing operations
toUpper_r :: Char -> Char
toUpper_r =  primUnicodeToUpper

toLower_r :: Char -> Char
toLower_r =  primUnicodeToLower

-- Character code functions
ord_r  :: Char -> Int
ord_r  =  fromEnum

chr_r  :: Int  -> Char
chr_r  =  toEnum

-- Text functions
readLitChar_r          :: ReadS Char
readLitChar_r ('\\':s) =  readEsc_r s
readLitChar_r (c:s)    =  [(c,s)]

readEsc_r          :: ReadS Char
readEsc_r ('a':s)  = [('\a',s)]
readEsc_r ('b':s)  = [('\b',s)]
readEsc_r ('f':s)  = [('\f',s)]
readEsc_r ('n':s)  = [('\n',s)]
readEsc_r ('r':s)  = [('\r',s)]
readEsc_r ('t':s)  = [('\t',s)]
readEsc_r ('v':s)  = [('\v',s)]
readEsc_r ('\\':s) = [('\\',s)]
readEsc_r ('"':s)  = [('"',s)]
readEsc_r ('\'':s) = [('\'',s)]
readEsc_r ('^':c:s) | c >= '@' && c <= '_'
                 = [(chr_r (ord_r c - ord_r '@'), s)]
readEsc_r s@(d:_) | isDigit_r d
                 = [(chr_r n, t) | (n,t) <- readDec s]
readEsc_r ('o':s)  = [(chr_r n, t) | (n,t) <- readOct s]
readEsc_r ('x':s)  = [(chr_r n, t) | (n,t) <- readHex s]
readEsc_r s@(c:_) | isUpper_r c
                 = let table = ('\DEL', "DEL") : assocs asciiTab_r
                   in case [(c,s') | (c, mne) <- table,
                                     ([],s') <- [match_r mne s]]
                      of (pr:_) -> [pr]
                         []     -> []
readEsc_r _        = []

match_r                         :: (Eq a) => [a] -> [a] -> ([a],[a])
match_r (x:xs) (y:ys) | x == y  =  match_r xs ys
match_r xs     ys               =  (xs,ys)

showLitChar_r               :: Char -> ShowS
showLitChar_r c | c > '\DEL' =  showChar '\\' .
                              protectEsc_r isDigit_r (shows (ord_r c))
showLitChar_r '\DEL'         =  showString "\\DEL"
showLitChar_r '\\'           =  showString "\\\\"
showLitChar_r c | c >= ' '   =  showChar c
showLitChar_r '\a'           =  showString "\\a"
showLitChar_r '\b'           =  showString "\\b"
showLitChar_r '\f'           =  showString "\\f"
showLitChar_r '\n'           =  showString "\\n"
showLitChar_r '\r'           =  showString "\\r"
showLitChar_r '\t'           =  showString "\\t"
showLitChar_r '\v'           =  showString "\\v"
showLitChar_r '\SO'          =  protectEsc_r (== 'H') (showString "\\SO")
showLitChar_r c              =  showString ('\\' : asciiTab_r!c)

protectEsc_r p f             = f . cont
                             where cont s@(c:_) | p c = "\\&" ++ s
                                   cont s             = s
asciiTab_r = listArray ('\NUL', ' ')
           ["NUL", "SOH", "STX", "ETX", "EOT", "ENQ", "ACK", "BEL",
            "BS",  "HT",  "LF",  "VT",  "FF",  "CR",  "SO",  "SI",
            "DLE", "DC1", "DC2", "DC3", "DC4", "NAK", "SYN", "ETB",
            "CAN", "EM",  "SUB", "ESC", "FS",  "GS",  "RS",  "US",
            "SP"]

lexLitChar_r          :: ReadS String
lexLitChar_r ('\\':s) =  map (prefix '\\') (lexEsc s)
        where
          lexEsc (c:s)     | c `elem` "abfnrtv\\\"'" = [([c],s)]
          lexEsc ('^':c:s) | c >= '@' && c <= '_'    = [(['^',c],s)]

          -- Numeric escapes
          lexEsc ('o':s)               = [prefix 'o' (span isOctDigit_r s)]
          lexEsc ('x':s)               = [prefix 'x' (span isHexDigit_r s)]
          lexEsc s@(d:_)   | isDigit_r d = [span isDigit_r s]

          -- Very crude approximation to \XYZ.
          lexEsc s@(c:_)   | isUpper_r c = [span isCharName s]
          lexEsc _                     = []

          isCharName c   = isUpper_r c || isDigit_r c
          prefix c (t,s) = (c:t, s)

lexLitChar_r (c:s)    =  [([c],s)]
lexLitChar_r ""       =  []

primUnicodeIsPrint, primUnicodeIsUpper, primUnicodeIsLower, primUnicodeIsAlphaNum :: Char -> Bool
primUnicodeIsPrint = C.isPrint
primUnicodeIsUpper = C.isUpper
primUnicodeIsLower = C.isLower
primUnicodeIsAlphaNum = C.isAlphaNum

primUnicodeToUpper, primUnicodeToLower :: Char -> Char
primUnicodeToUpper = C.toUpper
primUnicodeToLower = C.toLower

cs :: [Char]
cs = ['\0' .. '\255']

escs :: [String]
escs = ["\\a", "\\b", "\\f", "\\n", "\\r", "\\t", "\\v", "\\\\", "\\\"", "\\'", "\\^A", "\\^@", "\\^_", "\\^a", "\\^",
        "\\123", "\\0x", "\\o17", "\\o8", "\\x7f", "\\x7G", "\\xFF", "\\255", "\\NUL", "\\SOH", "\\SO", "\\SOx", "\\DEL",
        "\\SP", "\\ESC1", "\\LF", "\\Q", "\\&", "\\", "a", "\\q"]

main :: IO ()
main = do
  print [c | c <- cs, isAscii c /= isAscii_r c || isLatin1 c /= isLatin1_r c || isControl c /= isControl_r c || isSpace c /= isSpace_r c]
  print [c | c <- cs, isDigit c /= isDigit_r c || isOctDigit c /= isOctDigit_r c || isHexDigit c /= isHexDigit_r c]
  print ([c | c <- cs, isHexDigit_r c, digitToInt c /= digitToInt_r c], [i | i <- [0 .. 15], intToDigit i /= intToDigit_r i])
  print ([c | c <- cs, ord c /= ord_r c], [i | i <- [0 .. 255], chr i /= chr_r i])
  print [(c, s) | c <- cs, s <- ["", "1", "H", "x"], showLitChar c s /= showLitChar_r c s]
  print [s | s <- shown, readLitChar s /= readLitChar_r s]
  print [s | s <- shownL, lexLitChar s /= lexLitChar_r s]
  print [s ++ t | s <- escs, t <- ["", "rest"], readLitChar (s ++ t) /= readLitChar_r (s ++ t)]
  print [s ++ t | s <- escs, s `notElem` ["\\o8", "\\ESC1", "\\Q"], t <- ["", "rest"], lexLitChar (s ++ t) /= lexLitChar_r (s ++ t)]
  where shown = [showLitChar_r c t | c <- cs, t <- ["", "1", "H"]]
        shownL = [showLitChar_r c t | c <- cs, t <- ["", "x"]] ++ ["\\SO\\&H"]
