-- rows: lay.brace.explicit lay.brace.otherkeywords lay.module.where lay.class.where lay.case.of lay.first.module lay.l.1 lay.l.2 lay.l.3 lay.l.4 lay.l.5 lay.l.11 lay.angle.rule lay.angle.notbrace lay.angle.notfirst lay.col.indentation lay.col.first lay.l.order lit.ext.hs
-- Report 9.3: "If a let, where, do, or of keyword is not followed by the lexeme {, the token {n} is inserted after the
-- keyword, where n is the indentation of the next lexeme"; a lexeme first on its line gets <n>; L opens a context
-- further indented (equations 4, 5), gives ; at its column and } left of it (1, 2), and nothing right of it (3).
-- if, then, else, in, class, instance and data open none; a keyword followed by { opens no implicit one.
module Main (main) where

class C a where
  m :: a -> Int
  n :: a -> Int
  n _ = 0

instance C Bool where
  m b = if b
          then 1
          else 0

data T = A
  | B Int
  deriving Show

f :: Int -> Int
f x = case x of
        0 -> 1
        y | y > 0 ->
              y
          | otherwise -> 0

g :: Int -> Int
g x = let { a = 1 } in let b = 2
                           c = 3 in a + b + c + x

main :: IO ()
main = do
  print (f 1, g 2, m True)
  do { print A; print (B 1) }
  print (n False) where
