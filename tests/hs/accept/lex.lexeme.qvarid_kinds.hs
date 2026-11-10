-- rows: lex.lexeme.qconid lex.lexeme.qvarsym lex.lexeme.qconsym lex.lexeme.literal lex.lexeme.special lex.lexeme.reservedop lex.lexeme.reservedid lex.qual.prods lex.qual.scope lex.qual.opsym lex.qual.backquote
-- Report 2.2: lexeme -> qvarid | qconid | qvarsym | qconsym | literal | special | reservedop | reservedid;
-- 2.4: qvarid, qconid, qtycon, qtycls, qvarsym, qconsym -> [modid .] name. A lexeme of each kind.
module Main (main) where

import qualified Prelude as P
import Prelude
import qualified Complex as C

f :: P.Int -> P.Maybe P.Int
f x = P.Just (x P.+ 1)

g :: C.Complex Double -> Double
g (a C.:+ _) = a

h :: P.Eq a => a -> a -> Bool
h = (P.==)

main :: IO ()
main = let { c = 'c'; s = "s"; i = 1 :: Int; d = 1.5 :: Double } in
       if h i (7 `P.div` 7) then print (c, s, f i, g (d C.:+ 0), (id Prelude.. id) d) else return ()
