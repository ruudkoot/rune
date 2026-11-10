-- rows: lex.varsym lex.consym lex.op.colonstart
-- Report 2.4: varsym -> (symbol {symbol | :})<reservedop | dashes>; consym -> (: {symbol | :})<reservedop>:
-- `+:` and `<=>` are varsyms, `:+`, `:::` and `:|` consyms, and a consym is a constructor in a pattern.
module Main (main) where

data T = Int :+ Int | Int ::: Int | Int :| Int

f :: T -> Int
f (a :+ b) = a +: b
f (a ::: b) = a <=> b
f (a :| _) = a

(+:), (<=>) :: Int -> Int -> Int
a +: b = a + b
a <=> b = a - b

main :: IO ()
main = print (map f [1 :+ 2, 3 ::: 4, 5 :| 6])
