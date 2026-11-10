-- rows: pre.r.lex.idinit std.lex.one
-- Report 8.2 (overlay ov.preludetext.lex; M17's bottom probes on the literal Prelude): lex, the erratum's
-- (e.2003.02.lex: an identifier may begin with an underscore); the reference is the printed lex under another name.
-- They agree on every term but lex "_x y", where the printed code gives [("_","x y")] (the erratum's difference). A
-- marker, then the terms, the last character by character, which ends in bottom.
module Main (main) where

s :: String
s = undefined

main :: IO ()
main = do
  putStrLn "probe"
  print (lex "abc def", lex "  x'1 y", lex "(x", lex "'a' b", lex "\"hi\" there", lex "12.5e3x", lex "<= 2")
  print (lex "_x y")
  print (fst (head (lex ("ab" ++ " " ++ s))), length (lex ("a " ++ s)), take 0 (lex s))
  mapM_ print (fst (head (lex ("ab" ++ s))))
