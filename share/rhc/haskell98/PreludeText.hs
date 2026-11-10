-- Module PreludeText, section 8.2 of the Haskell 98 Report.
-- The code of the online Revised Report of December 2002, with its published
-- errata and rhc's overlay applied: a modified version of the Report's code,
-- which does not define Haskell 98. LICENSE says what was changed; errata.tsv
-- and overlay.tsv list each change, and pristine/ holds the code as printed.

module PreludeText (
    ReadS, ShowS,
    Read(readsPrec, readList),
    Show(showsPrec, show, showList),
    reads, shows, read, lex,
    showChar, showString, readParen, showParen ) where

-- The instances of Read and Show for
--      Bool, Maybe, Either, Ordering
-- are done via "deriving" clauses in Prelude.hs

import Char(isSpace, isAlpha, isDigit, isAlphaNum,
            showLitChar, readLitChar, lexLitChar)

import Numeric(showSigned, showInt, readSigned, readDec, showFloat,
               readFloat, lexDigits)


type  ReadS a  = String -> [(a,String)]

type  ShowS    = String -> String


class  Read a  where
    readsPrec        :: Int -> ReadS a
    readList         :: ReadS [a]

        -- Minimal complete definition:
        --      readsPrec
    readList         = readParen False (\r -> [pr | ("[",s)  <- lex r,
                                                    pr       <- readl s])
                       where readl  s = [([],t)   | ("]",t)  <- lex s] ++
                                        [(x:xs,u) | (x,t)    <- reads s,
                                                    (xs,u)   <- readl' t]
                             readl' s = [([],t)   | ("]",t)  <- lex s] ++
                                        [(x:xs,v) | (",",t)  <- lex s,
                                                    (x,u)    <- reads t,
                                                    (xs,v)   <- readl' u]


class  Show a  where
    showsPrec        :: Int -> a -> ShowS
    show             :: a -> String 
    showList         :: [a] -> ShowS

        -- Mimimal complete definition:
        --      show or showsPrec
    showsPrec _ x s   = show x ++ s

    show x            = showsPrec 0 x ""

    showList []       = showString "[]"
    showList (x:xs)   = showChar '[' . shows x . showl xs
                        where showl []     = showChar ']'
                              showl (x:xs) = showChar ',' . shows x .
                                             showl xs


reads            :: (Read a) => ReadS a
reads            =  readsPrec 0


shows            :: (Show a) => a -> ShowS
shows            =  showsPrec 0


read             :: (Read a) => String -> a
read s           =  case [x | (x,t) <- reads s, ("","") <- lex t] of
                         [x] -> x
                         []  -> error "Prelude.read: no parse"
                         _   -> error "Prelude.read: ambiguous parse"


showChar         :: Char -> ShowS
showChar         =  (:)


showString       :: String -> ShowS
showString       =  (++)


showParen        :: Bool -> ShowS -> ShowS
showParen b p    =  if b then showChar '(' . p . showChar ')' else p


readParen        :: Bool -> ReadS a -> ReadS a
readParen b g    =  if b then mandatory else optional
                    where optional r  = g r ++ mandatory r
                          mandatory r = [(x,u) | ("(",s) <- lex r,
                                                 (x,t)   <- optional s,
                                                 (")",u) <- lex t    ]

-- This lexer is not completely faithful to the Haskell lexical syntax.
-- Current limitations:
--    Qualified names are not handled properly
--    Octal and hexidecimal numerics are not recognized as a single token
--    Comments are not treated properly


lex              :: ReadS String
lex ""           =  [("","")]
lex (c:s)
   | isSpace c   =  lex (dropWhile isSpace s)
lex ('\'':s)     =  [('\'':ch++"'", t) | (ch,'\'':t)  <- lexLitChar s,
                                         ch /= "'" ]
lex ('"':s)      =  [('"':str, t)      | (str,t) <- lexString s]
                    where
                    lexString ('"':s) = [("\"",s)]
                    lexString s = [(ch++str, u)
                                         | (ch,t)  <- lexStrItem s,
                                           (str,u) <- lexString t  ]

                    lexStrItem ('\\':'&':s) =  [("\\&",s)]
                    lexStrItem ('\\':c:s) | isSpace c
                                           =  [("\\&",t) | 
                                               '\\':t <-
                                                   [dropWhile isSpace s]]
                    lexStrItem s           =  lexLitChar s

lex (c:s) | isSingle c = [([c],s)]
          | isSym c    = [(c:sym,t)       | (sym,t) <- [span isSym s]]
          | isIdInit c = [(c:nam,t)       | (nam,t) <- [span isIdChar s]]
          | isDigit c  = [(c:ds++fe,t)    | (ds,s)  <- [span isDigit s],
                                            (fe,t)  <- lexFracExp s     ]
          | otherwise  = []    -- bad character
             where
              isSingle c =  c `elem` ",;()[]{}`"
              isSym c    =  c `elem` "!@#$%&*+./<=>?\\^|:-~"
              isIdInit c =  isAlpha c || c == '_'
              isIdChar c =  isAlphaNum c || c `elem` "_'"

              lexFracExp ('.':c:cs) | isDigit c
                            = [('.':ds++e,u) | (ds,t) <- lexDigits (c:cs),
                                               (e,u)  <- lexExp t]
              lexFracExp s  = lexExp s

              lexExp (e:s) | e `elem` "eE"
                       = [(e:c:ds,u) | (c:t)  <- [s], c `elem` "+-",
                                                 (ds,u) <- lexDigits t] ++
                         [(e:ds,t)   | (ds,t) <- lexDigits s]
              lexExp s = [("",s)]


instance  Show Int  where
    showsPrec n = showsPrec n . toInteger
        -- Converting to Integer avoids
        -- possible difficulty with minInt


instance  Read Int  where
  readsPrec p r = [(fromInteger i, t) | (i,t) <- readsPrec p r]
        -- Reading at the Integer type avoids
        -- possible difficulty with minInt


instance  Show Integer  where
    showsPrec           = showSigned showInt


instance  Read Integer  where
    readsPrec p         = readSigned readDec


instance  Show Float  where 
    showsPrec p         = showSigned showFloat p   -- parenthesised (R42)
           

instance  Read Float  where
    readsPrec p         = readSigned readFloat


instance  Show Double  where
    showsPrec p         = showSigned showFloat p   -- parenthesised (R42)


instance  Read Double  where
    readsPrec p         = readSigned readFloat


instance  Show ()  where
    showsPrec p () = showString "()"


instance Read () where
    readsPrec p    = readParen False
                            (\r -> [((),t) | ("(",s) <- lex r,
                                             (")",t) <- lex s ] )

instance  Show Char  where
    showsPrec p '\'' = showString "'\\''"
    showsPrec p c    = showChar '\'' . showLitChar c . showChar '\''

    showList cs = showChar '"' . showl cs
                 where showl ""       = showChar '"'
                       showl ('"':cs) = showString "\\\"" . showl cs
                       showl (c:cs)   = showLitChar c . showl cs


instance  Read Char  where
    readsPrec p      = readParen False
                            (\r -> [(c,t) | ('\'':s,t)<- lex r,
                                            (c,"\'")  <- readLitChar s])

    readList = readParen False (\r -> [(l,t) | ('"':s, t) <- lex r,
                                               (l,_)      <- readl s ])
        where readl ('"':s)      = [("",s)]
              readl ('\\':'&':s) = readl s
              readl s            = [(c:cs,u) | (c ,t) <- readLitChar s,
                                               (cs,u) <- readl t       ]


instance  (Show a) => Show [a]  where
    showsPrec p      = showList


instance  (Read a) => Read [a]  where
    readsPrec p      = readList

-- Tuples


instance  (Show a, Show b) => Show (a,b)  where
    showsPrec p (x,y) = showChar '(' . shows x . showChar ',' .
                                       shows y . showChar ')'


instance  (Read a, Read b) => Read (a,b)  where
    readsPrec p       = readParen False
                            (\r -> [((x,y), w) | ("(",s) <- lex r,
                                                 (x,t)   <- reads s,
                                                 (",",u) <- lex t,
                                                 (y,v)   <- reads u,
                                                 (")",w) <- lex v ] )

-- Other tuples have similar Read and Show instances: to size 15 (6.1.4;
-- overlay ov.tuples.fifteen)

instance  (Show a, Show b, Show c) => Show (a,b,c)  where
    showsPrec p (x1,x2,x3) = showChar '(' . shows x1 .
                             showChar ',' . shows x2 .
                             showChar ',' . shows x3 .
                             showChar ')'

instance  (Read a, Read b, Read c) => Read (a,b,c)  where
    readsPrec p = readParen False
                    (\r -> [((x1,x2,x3), s6) | ("(",s0) <- lex r,
                                 (x1,s1) <- reads s0,
                                 (",",s2) <- lex s1,
                                 (x2,s3) <- reads s2,
                                 (",",s4) <- lex s3,
                                 (x3,s5) <- reads s4,
                                 (")",s6) <- lex s5])

instance  (Show a, Show b, Show c, Show d) => Show (a,b,c,d)  where
    showsPrec p (x1,x2,x3,x4) = showChar '(' . shows x1 .
                                showChar ',' . shows x2 .
                                showChar ',' . shows x3 .
                                showChar ',' . shows x4 .
                                showChar ')'

instance  (Read a, Read b, Read c, Read d) => Read (a,b,c,d)  where
    readsPrec p = readParen False
                    (\r -> [((x1,x2,x3,x4), s8) | ("(",s0) <- lex r,
                                 (x1,s1) <- reads s0,
                                 (",",s2) <- lex s1,
                                 (x2,s3) <- reads s2,
                                 (",",s4) <- lex s3,
                                 (x3,s5) <- reads s4,
                                 (",",s6) <- lex s5,
                                 (x4,s7) <- reads s6,
                                 (")",s8) <- lex s7])

instance  (Show a, Show b, Show c, Show d, Show e) => Show (a,b,c,d,e)  where
    showsPrec p (x1,x2,x3,x4,x5) = showChar '(' . shows x1 .
                                   showChar ',' . shows x2 .
                                   showChar ',' . shows x3 .
                                   showChar ',' . shows x4 .
                                   showChar ',' . shows x5 .
                                   showChar ')'

instance  (Read a, Read b, Read c, Read d, Read e) => Read (a,b,c,d,e)  where
    readsPrec p = readParen False
                    (\r -> [((x1,x2,x3,x4,x5), s10) | ("(",s0) <- lex r,
                                 (x1,s1) <- reads s0,
                                 (",",s2) <- lex s1,
                                 (x2,s3) <- reads s2,
                                 (",",s4) <- lex s3,
                                 (x3,s5) <- reads s4,
                                 (",",s6) <- lex s5,
                                 (x4,s7) <- reads s6,
                                 (",",s8) <- lex s7,
                                 (x5,s9) <- reads s8,
                                 (")",s10) <- lex s9])

instance  (Show a, Show b, Show c, Show d, Show e, Show f) => Show (a,b,c,d,e,f)  where
    showsPrec p (x1,x2,x3,x4,x5,x6) = showChar '(' . shows x1 .
                                      showChar ',' . shows x2 .
                                      showChar ',' . shows x3 .
                                      showChar ',' . shows x4 .
                                      showChar ',' . shows x5 .
                                      showChar ',' . shows x6 .
                                      showChar ')'

instance  (Read a, Read b, Read c, Read d, Read e, Read f) => Read (a,b,c,d,e,f)  where
    readsPrec p = readParen False
                    (\r -> [((x1,x2,x3,x4,x5,x6), s12) | ("(",s0) <- lex r,
                                 (x1,s1) <- reads s0,
                                 (",",s2) <- lex s1,
                                 (x2,s3) <- reads s2,
                                 (",",s4) <- lex s3,
                                 (x3,s5) <- reads s4,
                                 (",",s6) <- lex s5,
                                 (x4,s7) <- reads s6,
                                 (",",s8) <- lex s7,
                                 (x5,s9) <- reads s8,
                                 (",",s10) <- lex s9,
                                 (x6,s11) <- reads s10,
                                 (")",s12) <- lex s11])

instance  (Show a, Show b, Show c, Show d, Show e, Show f, Show g) => Show (a,b,c,d,e,f,g)  where
    showsPrec p (x1,x2,x3,x4,x5,x6,x7) = showChar '(' . shows x1 .
                                         showChar ',' . shows x2 .
                                         showChar ',' . shows x3 .
                                         showChar ',' . shows x4 .
                                         showChar ',' . shows x5 .
                                         showChar ',' . shows x6 .
                                         showChar ',' . shows x7 .
                                         showChar ')'

instance  (Read a, Read b, Read c, Read d, Read e, Read f, Read g) => Read (a,b,c,d,e,f,g)  where
    readsPrec p = readParen False
                    (\r -> [((x1,x2,x3,x4,x5,x6,x7), s14) | ("(",s0) <- lex r,
                                 (x1,s1) <- reads s0,
                                 (",",s2) <- lex s1,
                                 (x2,s3) <- reads s2,
                                 (",",s4) <- lex s3,
                                 (x3,s5) <- reads s4,
                                 (",",s6) <- lex s5,
                                 (x4,s7) <- reads s6,
                                 (",",s8) <- lex s7,
                                 (x5,s9) <- reads s8,
                                 (",",s10) <- lex s9,
                                 (x6,s11) <- reads s10,
                                 (",",s12) <- lex s11,
                                 (x7,s13) <- reads s12,
                                 (")",s14) <- lex s13])

instance  (Show a, Show b, Show c, Show d, Show e, Show f, Show g, Show h) => Show (a,b,c,d,e,f,g,h)  where
    showsPrec p (x1,x2,x3,x4,x5,x6,x7,x8) = showChar '(' . shows x1 .
                                            showChar ',' . shows x2 .
                                            showChar ',' . shows x3 .
                                            showChar ',' . shows x4 .
                                            showChar ',' . shows x5 .
                                            showChar ',' . shows x6 .
                                            showChar ',' . shows x7 .
                                            showChar ',' . shows x8 .
                                            showChar ')'

instance  (Read a, Read b, Read c, Read d, Read e, Read f, Read g, Read h) => Read (a,b,c,d,e,f,g,h)  where
    readsPrec p = readParen False
                    (\r -> [((x1,x2,x3,x4,x5,x6,x7,x8), s16) | ("(",s0) <- lex r,
                                 (x1,s1) <- reads s0,
                                 (",",s2) <- lex s1,
                                 (x2,s3) <- reads s2,
                                 (",",s4) <- lex s3,
                                 (x3,s5) <- reads s4,
                                 (",",s6) <- lex s5,
                                 (x4,s7) <- reads s6,
                                 (",",s8) <- lex s7,
                                 (x5,s9) <- reads s8,
                                 (",",s10) <- lex s9,
                                 (x6,s11) <- reads s10,
                                 (",",s12) <- lex s11,
                                 (x7,s13) <- reads s12,
                                 (",",s14) <- lex s13,
                                 (x8,s15) <- reads s14,
                                 (")",s16) <- lex s15])

instance  (Show a, Show b, Show c, Show d, Show e, Show f, Show g, Show h, Show i) => Show (a,b,c,d,e,f,g,h,i)  where
    showsPrec p (x1,x2,x3,x4,x5,x6,x7,x8,x9) = showChar '(' . shows x1 .
                                               showChar ',' . shows x2 .
                                               showChar ',' . shows x3 .
                                               showChar ',' . shows x4 .
                                               showChar ',' . shows x5 .
                                               showChar ',' . shows x6 .
                                               showChar ',' . shows x7 .
                                               showChar ',' . shows x8 .
                                               showChar ',' . shows x9 .
                                               showChar ')'

instance  (Read a, Read b, Read c, Read d, Read e, Read f, Read g, Read h, Read i) => Read (a,b,c,d,e,f,g,h,i)  where
    readsPrec p = readParen False
                    (\r -> [((x1,x2,x3,x4,x5,x6,x7,x8,x9), s18) | ("(",s0) <- lex r,
                                 (x1,s1) <- reads s0,
                                 (",",s2) <- lex s1,
                                 (x2,s3) <- reads s2,
                                 (",",s4) <- lex s3,
                                 (x3,s5) <- reads s4,
                                 (",",s6) <- lex s5,
                                 (x4,s7) <- reads s6,
                                 (",",s8) <- lex s7,
                                 (x5,s9) <- reads s8,
                                 (",",s10) <- lex s9,
                                 (x6,s11) <- reads s10,
                                 (",",s12) <- lex s11,
                                 (x7,s13) <- reads s12,
                                 (",",s14) <- lex s13,
                                 (x8,s15) <- reads s14,
                                 (",",s16) <- lex s15,
                                 (x9,s17) <- reads s16,
                                 (")",s18) <- lex s17])

instance  (Show a, Show b, Show c, Show d, Show e, Show f, Show g, Show h, Show i, Show j) => Show (a,b,c,d,e,f,g,h,i,j)  where
    showsPrec p (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10) = showChar '(' . shows x1 .
                                                   showChar ',' . shows x2 .
                                                   showChar ',' . shows x3 .
                                                   showChar ',' . shows x4 .
                                                   showChar ',' . shows x5 .
                                                   showChar ',' . shows x6 .
                                                   showChar ',' . shows x7 .
                                                   showChar ',' . shows x8 .
                                                   showChar ',' . shows x9 .
                                                   showChar ',' . shows x10 .
                                                   showChar ')'

instance  (Read a, Read b, Read c, Read d, Read e, Read f, Read g, Read h, Read i, Read j) => Read (a,b,c,d,e,f,g,h,i,j)  where
    readsPrec p = readParen False
                    (\r -> [((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10), s20) | ("(",s0) <- lex r,
                                 (x1,s1) <- reads s0,
                                 (",",s2) <- lex s1,
                                 (x2,s3) <- reads s2,
                                 (",",s4) <- lex s3,
                                 (x3,s5) <- reads s4,
                                 (",",s6) <- lex s5,
                                 (x4,s7) <- reads s6,
                                 (",",s8) <- lex s7,
                                 (x5,s9) <- reads s8,
                                 (",",s10) <- lex s9,
                                 (x6,s11) <- reads s10,
                                 (",",s12) <- lex s11,
                                 (x7,s13) <- reads s12,
                                 (",",s14) <- lex s13,
                                 (x8,s15) <- reads s14,
                                 (",",s16) <- lex s15,
                                 (x9,s17) <- reads s16,
                                 (",",s18) <- lex s17,
                                 (x10,s19) <- reads s18,
                                 (")",s20) <- lex s19])

instance  (Show a, Show b, Show c, Show d, Show e, Show f, Show g, Show h, Show i, Show j, Show k) => Show (a,b,c,d,e,f,g,h,i,j,k)  where
    showsPrec p (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11) = showChar '(' . shows x1 .
                                                       showChar ',' . shows x2 .
                                                       showChar ',' . shows x3 .
                                                       showChar ',' . shows x4 .
                                                       showChar ',' . shows x5 .
                                                       showChar ',' . shows x6 .
                                                       showChar ',' . shows x7 .
                                                       showChar ',' . shows x8 .
                                                       showChar ',' . shows x9 .
                                                       showChar ',' . shows x10 .
                                                       showChar ',' . shows x11 .
                                                       showChar ')'

instance  (Read a, Read b, Read c, Read d, Read e, Read f, Read g, Read h, Read i, Read j, Read k) => Read (a,b,c,d,e,f,g,h,i,j,k)  where
    readsPrec p = readParen False
                    (\r -> [((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11), s22) | ("(",s0) <- lex r,
                                 (x1,s1) <- reads s0,
                                 (",",s2) <- lex s1,
                                 (x2,s3) <- reads s2,
                                 (",",s4) <- lex s3,
                                 (x3,s5) <- reads s4,
                                 (",",s6) <- lex s5,
                                 (x4,s7) <- reads s6,
                                 (",",s8) <- lex s7,
                                 (x5,s9) <- reads s8,
                                 (",",s10) <- lex s9,
                                 (x6,s11) <- reads s10,
                                 (",",s12) <- lex s11,
                                 (x7,s13) <- reads s12,
                                 (",",s14) <- lex s13,
                                 (x8,s15) <- reads s14,
                                 (",",s16) <- lex s15,
                                 (x9,s17) <- reads s16,
                                 (",",s18) <- lex s17,
                                 (x10,s19) <- reads s18,
                                 (",",s20) <- lex s19,
                                 (x11,s21) <- reads s20,
                                 (")",s22) <- lex s21])

instance  (Show a, Show b, Show c, Show d, Show e, Show f, Show g, Show h, Show i, Show j, Show k, Show l) => Show (a,b,c,d,e,f,g,h,i,j,k,l)  where
    showsPrec p (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12) = showChar '(' . shows x1 .
                                                           showChar ',' . shows x2 .
                                                           showChar ',' . shows x3 .
                                                           showChar ',' . shows x4 .
                                                           showChar ',' . shows x5 .
                                                           showChar ',' . shows x6 .
                                                           showChar ',' . shows x7 .
                                                           showChar ',' . shows x8 .
                                                           showChar ',' . shows x9 .
                                                           showChar ',' . shows x10 .
                                                           showChar ',' . shows x11 .
                                                           showChar ',' . shows x12 .
                                                           showChar ')'

instance  (Read a, Read b, Read c, Read d, Read e, Read f, Read g, Read h, Read i, Read j, Read k, Read l) => Read (a,b,c,d,e,f,g,h,i,j,k,l)  where
    readsPrec p = readParen False
                    (\r -> [((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12), s24) | ("(",s0) <- lex r,
                                 (x1,s1) <- reads s0,
                                 (",",s2) <- lex s1,
                                 (x2,s3) <- reads s2,
                                 (",",s4) <- lex s3,
                                 (x3,s5) <- reads s4,
                                 (",",s6) <- lex s5,
                                 (x4,s7) <- reads s6,
                                 (",",s8) <- lex s7,
                                 (x5,s9) <- reads s8,
                                 (",",s10) <- lex s9,
                                 (x6,s11) <- reads s10,
                                 (",",s12) <- lex s11,
                                 (x7,s13) <- reads s12,
                                 (",",s14) <- lex s13,
                                 (x8,s15) <- reads s14,
                                 (",",s16) <- lex s15,
                                 (x9,s17) <- reads s16,
                                 (",",s18) <- lex s17,
                                 (x10,s19) <- reads s18,
                                 (",",s20) <- lex s19,
                                 (x11,s21) <- reads s20,
                                 (",",s22) <- lex s21,
                                 (x12,s23) <- reads s22,
                                 (")",s24) <- lex s23])

instance  (Show a, Show b, Show c, Show d, Show e, Show f, Show g, Show h, Show i, Show j, Show k, Show l, Show m) => Show (a,b,c,d,e,f,g,h,i,j,k,l,m)  where
    showsPrec p (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13) = showChar '(' . shows x1 .
                                                               showChar ',' . shows x2 .
                                                               showChar ',' . shows x3 .
                                                               showChar ',' . shows x4 .
                                                               showChar ',' . shows x5 .
                                                               showChar ',' . shows x6 .
                                                               showChar ',' . shows x7 .
                                                               showChar ',' . shows x8 .
                                                               showChar ',' . shows x9 .
                                                               showChar ',' . shows x10 .
                                                               showChar ',' . shows x11 .
                                                               showChar ',' . shows x12 .
                                                               showChar ',' . shows x13 .
                                                               showChar ')'

instance  (Read a, Read b, Read c, Read d, Read e, Read f, Read g, Read h, Read i, Read j, Read k, Read l, Read m) => Read (a,b,c,d,e,f,g,h,i,j,k,l,m)  where
    readsPrec p = readParen False
                    (\r -> [((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13), s26) | ("(",s0) <- lex r,
                                 (x1,s1) <- reads s0,
                                 (",",s2) <- lex s1,
                                 (x2,s3) <- reads s2,
                                 (",",s4) <- lex s3,
                                 (x3,s5) <- reads s4,
                                 (",",s6) <- lex s5,
                                 (x4,s7) <- reads s6,
                                 (",",s8) <- lex s7,
                                 (x5,s9) <- reads s8,
                                 (",",s10) <- lex s9,
                                 (x6,s11) <- reads s10,
                                 (",",s12) <- lex s11,
                                 (x7,s13) <- reads s12,
                                 (",",s14) <- lex s13,
                                 (x8,s15) <- reads s14,
                                 (",",s16) <- lex s15,
                                 (x9,s17) <- reads s16,
                                 (",",s18) <- lex s17,
                                 (x10,s19) <- reads s18,
                                 (",",s20) <- lex s19,
                                 (x11,s21) <- reads s20,
                                 (",",s22) <- lex s21,
                                 (x12,s23) <- reads s22,
                                 (",",s24) <- lex s23,
                                 (x13,s25) <- reads s24,
                                 (")",s26) <- lex s25])

instance  (Show a, Show b, Show c, Show d, Show e, Show f, Show g, Show h, Show i, Show j, Show k, Show l, Show m, Show n) => Show (a,b,c,d,e,f,g,h,i,j,k,l,m,n)  where
    showsPrec p (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14) = showChar '(' . shows x1 .
                                                                   showChar ',' . shows x2 .
                                                                   showChar ',' . shows x3 .
                                                                   showChar ',' . shows x4 .
                                                                   showChar ',' . shows x5 .
                                                                   showChar ',' . shows x6 .
                                                                   showChar ',' . shows x7 .
                                                                   showChar ',' . shows x8 .
                                                                   showChar ',' . shows x9 .
                                                                   showChar ',' . shows x10 .
                                                                   showChar ',' . shows x11 .
                                                                   showChar ',' . shows x12 .
                                                                   showChar ',' . shows x13 .
                                                                   showChar ',' . shows x14 .
                                                                   showChar ')'

instance  (Read a, Read b, Read c, Read d, Read e, Read f, Read g, Read h, Read i, Read j, Read k, Read l, Read m, Read n) => Read (a,b,c,d,e,f,g,h,i,j,k,l,m,n)  where
    readsPrec p = readParen False
                    (\r -> [((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14), s28) | ("(",s0) <- lex r,
                                 (x1,s1) <- reads s0,
                                 (",",s2) <- lex s1,
                                 (x2,s3) <- reads s2,
                                 (",",s4) <- lex s3,
                                 (x3,s5) <- reads s4,
                                 (",",s6) <- lex s5,
                                 (x4,s7) <- reads s6,
                                 (",",s8) <- lex s7,
                                 (x5,s9) <- reads s8,
                                 (",",s10) <- lex s9,
                                 (x6,s11) <- reads s10,
                                 (",",s12) <- lex s11,
                                 (x7,s13) <- reads s12,
                                 (",",s14) <- lex s13,
                                 (x8,s15) <- reads s14,
                                 (",",s16) <- lex s15,
                                 (x9,s17) <- reads s16,
                                 (",",s18) <- lex s17,
                                 (x10,s19) <- reads s18,
                                 (",",s20) <- lex s19,
                                 (x11,s21) <- reads s20,
                                 (",",s22) <- lex s21,
                                 (x12,s23) <- reads s22,
                                 (",",s24) <- lex s23,
                                 (x13,s25) <- reads s24,
                                 (",",s26) <- lex s25,
                                 (x14,s27) <- reads s26,
                                 (")",s28) <- lex s27])

instance  (Show a, Show b, Show c, Show d, Show e, Show f, Show g, Show h, Show i, Show j, Show k, Show l, Show m, Show n, Show o) => Show (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o)  where
    showsPrec p (x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15) = showChar '(' . shows x1 .
                                                                       showChar ',' . shows x2 .
                                                                       showChar ',' . shows x3 .
                                                                       showChar ',' . shows x4 .
                                                                       showChar ',' . shows x5 .
                                                                       showChar ',' . shows x6 .
                                                                       showChar ',' . shows x7 .
                                                                       showChar ',' . shows x8 .
                                                                       showChar ',' . shows x9 .
                                                                       showChar ',' . shows x10 .
                                                                       showChar ',' . shows x11 .
                                                                       showChar ',' . shows x12 .
                                                                       showChar ',' . shows x13 .
                                                                       showChar ',' . shows x14 .
                                                                       showChar ',' . shows x15 .
                                                                       showChar ')'

instance  (Read a, Read b, Read c, Read d, Read e, Read f, Read g, Read h, Read i, Read j, Read k, Read l, Read m, Read n, Read o) => Read (a,b,c,d,e,f,g,h,i,j,k,l,m,n,o)  where
    readsPrec p = readParen False
                    (\r -> [((x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15), s30) | ("(",s0) <- lex r,
                                 (x1,s1) <- reads s0,
                                 (",",s2) <- lex s1,
                                 (x2,s3) <- reads s2,
                                 (",",s4) <- lex s3,
                                 (x3,s5) <- reads s4,
                                 (",",s6) <- lex s5,
                                 (x4,s7) <- reads s6,
                                 (",",s8) <- lex s7,
                                 (x5,s9) <- reads s8,
                                 (",",s10) <- lex s9,
                                 (x6,s11) <- reads s10,
                                 (",",s12) <- lex s11,
                                 (x7,s13) <- reads s12,
                                 (",",s14) <- lex s13,
                                 (x8,s15) <- reads s14,
                                 (",",s16) <- lex s15,
                                 (x9,s17) <- reads s16,
                                 (",",s18) <- lex s17,
                                 (x10,s19) <- reads s18,
                                 (",",s20) <- lex s19,
                                 (x11,s21) <- reads s20,
                                 (",",s22) <- lex s21,
                                 (x12,s23) <- reads s22,
                                 (",",s24) <- lex s23,
                                 (x13,s25) <- reads s24,
                                 (",",s26) <- lex s25,
                                 (x14,s27) <- reads s26,
                                 (",",s28) <- lex s27,
                                 (x15,s29) <- reads s28,
                                 (")",s30) <- lex s29])



