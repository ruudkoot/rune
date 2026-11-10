-- rows: exp.field.ex.c2 exp.field.ex.upd exp.field.sel exp.field.sel.shadow exp.field.sel.shadowonly exp.field.con.pos exp.field.con.empty exp.field.con.empty.value tr.field.sel tr.field.con tr.field.pick exp.field.upd.chain exp.field.upd.tight exp.field.upd.nondestructive tr.field.upd R16
-- Report 3.15: the Report's table for data T = C1 {f1,f2 :: Int} | C2 {f1 :: Int, f3,f4 :: Char}: selection,
-- construction with fields in any order or none, update, chained and binding tighter than application.
module Main (main) where

data T = C1 {f1, f2 :: Int} | C2 {f1 :: Int, f3, f4 :: Char}

sh :: T -> String
sh (C1 a b) = "C1 " ++ show a ++ " " ++ show b
sh (C2 a c d) = "C2 " ++ show a ++ " " ++ show c ++ " " ++ show d

main :: IO ()
main = do
  print (f1 (C1 1 2), f2 (C1 1 2), f1 (C2 5 'a' 'b'))
  putStrLn (sh (C2 {f1 = 1, f4 = 'A', f3 = 'B'}))
  print (f1 (C1 {f1 = 3}))
  let x = C1 {f2 = 2, f1 = 1}
  putStrLn (sh (x {f1 = 9}))
  putStrLn (sh x)
  putStrLn (sh (x {f1 = 7} {f2 = 8}))
  print (f1 x {f1 = 4})
  print (let f1 = 10 in f1 :: Int)
  putStrLn (sh (let f1 = 10 in C1 {f1 = f1, f2 = 0}))
  putStrLn (sh (let f2 = 11 in x {f2 = f2}))
  print (case C1 {} of C1 _ _ -> "empty")
  putStrLn (sh ((C2 1 'x' 'y') {f3 = 'z'}))
