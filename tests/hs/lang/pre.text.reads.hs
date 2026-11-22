-- rows: pre.text.shows pre.text.read pre.text.showchar pre.text.showstring pre.text.showparen pre.text.readparen pre.text.lex pre.text.inst.showint pre.text.inst.readint pre.text.inst.showinteger pre.text.inst.readinteger pre.text.inst.showfloat pre.text.inst.readfloat pre.text.inst.showdouble pre.text.inst.readdouble pre.text.inst.show pre.text.inst.read pre.text.inst.showchar pre.text.inst.readchar pre.text.inst.showlista pre.text.inst.readlista pre.text.inst.showacb pre.text.inst.readacb pre.r.inst.verbose pre.r.int.minint
-- Report 8.2 (PreludeText): reads, shows, read, showChar, showString, showParen and readParen against the Report's own
-- definitions; lex; the Read and Show instances of Int, Integer, Float, Double, (), Char, lists and tuples.
module Main (main) where

showChar' :: Char -> ShowS
showChar' = (:)

showString' :: String -> ShowS
showString' = (++)

showParen' :: Bool -> ShowS -> ShowS
showParen' b p = if b then showChar' '(' . p . showChar' ')' else p

reads' :: (Read a) => ReadS a
reads' = readsPrec 0

shows' :: (Show a) => a -> ShowS
shows' = showsPrec 0

read' :: (Read a) => String -> a
read' s = case [x | (x, t) <- reads s, ("", "") <- lex t] of
            [x] -> x
            [] -> error "Prelude.read: no parse"
            _ -> error "Prelude.read: ambiguous parse"

readParen' :: Bool -> ReadS a -> ReadS a
readParen' b g = if b then mandatory else optional
  where optional r = g r ++ mandatory r
        mandatory r = [(x, u) | ("(", s) <- lex r, (x, t) <- optional s, (")", u) <- lex t]

rint :: ReadS Int
rint = reads

main :: IO ()
main = do
  print (showChar 'a' "b" == showChar' 'a' "b")
  print (showString "ab" "c" == showString' "ab" "c")
  print ((showParen True (showString "x") "", showParen False (showString "x") "") == (showParen' True (showString "x") "", showParen' False (showString "x") ""))
  print ((reads "12 rest" :: [(Int, String)]) == reads' "12 rest")
  print (shows (12 :: Int) "!" == shows' (12 :: Int) "!")
  print ((read " 12 " :: Int, read "[1,2]" :: [Int]) == (read' " 12 ", read' "[1,2]"))
  print ((readParen False rint "(1) x", readParen True rint "((2))", readParen True rint "3") == (readParen' False rint "(1) x", readParen' True rint "((2))", readParen' True rint "3"))
  print ((lex "foo bar", lex "123abc", lex "\"s\" t", lex "<= x", lex "'c' d") == ([("foo", " bar")], [("123", "abc")], [("\"s\"", " t")], [("<=", " x")], [("'c'", " d")]))
  print ((show (-5 :: Int), showsPrec 7 (-5 :: Int) "", showsPrec 6 (-5 :: Int) "") == ("-5", "(-5)", "-5"))
  print ((read "-5" :: Int, read "(-5)" :: Int, read " ( 7 ) " :: Int) == (-5, -5, 7))
  print ((show (-12345678901234567890 :: Integer), read "-12345678901234567890" :: Integer) == ("-12345678901234567890", -12345678901234567890))
  print ((show (1.5 :: Float), read "1.5" :: Float, show (0.25 :: Double), read "2.5e2" :: Double) == ("1.5", 1.5, "0.25", 250))
  print ((showsPrec 7 (-1.5 :: Double) "", read "(-1.5)" :: Double) == ("(-1.5)", -1.5))
  print ((show (), read "()" :: (), show 'a', read "'a'" :: Char, show '\n') == ("()", (), "'a'", 'a', "'\\n'"))
  print ((show "ab\n", read "\"ab\"" :: String, show [1, 2 :: Int], read " [ 1 , 2 ] " :: [Int]) == ("\"ab\\n\"", "ab", "[1,2]", [1, 2]))
  print ((show (1 :: Int, 'a'), read "(1,'a')" :: (Int, Char), read " ( 1 , 'a' ) " :: (Int, Char)) == ("(1,'a')", (1, 'a'), (1, 'a')))
  print ((read "(1,2,3)" :: (Int, Int, Int), show (1 :: Int, 2 :: Int, 3 :: Int)) == ((1, 2, 3), "(1,2,3)"))
  print (show (minBound :: Int) == show (minBound :: Int) && (read (show (minBound :: Int)) :: Int) == minBound)
