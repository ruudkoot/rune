-- rows: lib.r.char.table.lower.print lib.r.char.table.lower.alnum lib.r.char.table.lower.alpha lib.r.char.table.lower.lower lib.r.char.table.other.print lib.r.char.table.other.alnum lib.r.char.table.other.alpha lib.r.char.table.digit.print lib.r.char.table.digit.alnum lib.r.char.table.printable lib.r.char.table.nonprint R38
-- Report 19 and its table: the predicates of Char on characters above ASCII, by Unicode 18.0.0's general category
-- (D21). A letter with no case is upper case, as 19 says ("any alphabetic character which is not lower case is
-- treated as upper case"; R38, where D38 follows the text against GHC and Hugs). Digits other than ASCII's are
-- alphanumeric and no digit; a line separator prints nothing; isSpace is Latin-1's alone.
module Main (main) where

import Char

row :: Char -> String
row c = show (fromEnum c) ++ " " ++ concatMap flag [isPrint c, isAlphaNum c, isAlpha c, isUpper c, isLower c,
                                                   isDigit c, isSpace c]
        ++ " " ++ show (fromEnum (toUpper c)) ++ " " ++ show (fromEnum (toLower c))
  where flag b = if b then "1" else "0"

main :: IO ()
main = mapM_ (putStrLn . row)
  [ '\228'      -- a with diaeresis, Ll
  , '\196'      -- A with diaeresis, Lu
  , '\223'      -- sharp s, Ll, no simple uppercase
  , '\931'      -- capital sigma, Lu
  , '\963'      -- small sigma, Ll
  , '\453'      -- Dz with caron, Lt
  , '\20013'    -- a CJK letter, Lo: upper by 19
  , '\1488'     -- Hebrew alef, Lo
  , '\688'      -- modifier letter small h, Lm
  , '\1633'     -- Arabic-Indic digit one, Nd
  , '\8547'     -- Roman numeral four, Nl
  , '\8232'     -- line separator, Zl
  , '\160'      -- no-break space, Zs
  , '\12288'    -- ideographic space, Zs
  , '\173'      -- soft hyphen, Cf
  , '\57344'    -- private use, Co
  , '\888'      -- unassigned, Cn
  , '\8364'     -- euro sign, Sc
  ]
