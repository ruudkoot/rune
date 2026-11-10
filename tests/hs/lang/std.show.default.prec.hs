-- rows: std.show.default.show std.show.prec.arg std.show.show.zero std.show.list std.show.string std.reads.def std.shows.def std.read.def std.lex.one std.lex.space std.lex.empty std.lex.bad der.show.infix.style R43
-- Report 6.3.3: Show's defaults from show alone or showsPrec alone; showsPrec 11 parenthesises, show does not; a
-- user showList; reads, shows, read and lex as defined; a derived infix constructor shows infix.
module Main (main) where

data S1 = S1

instance Show S1 where
  show _ = "s1"

data S2 = S2

instance Show S2 where
  showsPrec d _ = showString ("s2@" ++ show d)

data L = L

instance Show L where
  show _ = "L"
  showList _ = showString "<Ls>"

data T = Int :+: Int deriving Show

main :: IO ()
main = do
  print S1
  print [S1]
  putStrLn (showsPrec 5 S1 "")
  putStrLn (show S2)
  print [L, L]
  putStrLn (showsPrec 11 (Just (1 :: Int)) "")
  putStrLn (show (Just (1 :: Int)))
  putStrLn (show "a")
  print (reads "1 x" :: [(Int, String)])
  putStrLn (shows (1 :: Int) "x")
  print (read " 1 " :: Int)
  print (lex " foo bar", lex "  ", lex "", lex "\1")
  print (1 :+: 2)
