-- rows: lex.comment.legallexeme lex.comment.arrow lex.comment.bardash lex.comment.foo lex.comment.inline.brace
-- Report 2.3: an ordinary comment begins with two or more dashes and extends to the newline; "the sequence of dashes
-- must not form part of a legal lexeme": `-->` and `|--` are operators, `--foo` and `-----` begin comments, and
-- in one `{-` and `-}` mean nothing.
module Main (main) where

main :: IO ()
main = print (1 --> 2, 3 |-- 4) --foo is a comment
  where ----- so is this
    (-->), (|--) :: Int -> Int -> Int -- {- opens nothing
    a --> b = a + b -- -} closes nothing
    a |-- b = a * b
