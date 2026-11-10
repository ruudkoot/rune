-- rows: exp.list.form exp.tuple.con exp.seq.forms exp.comp.form exp.let.form exp.case.form exp.case.guards exp.case.gd.terminal exp.case.emptyalt exp.case.gd.sigparen exp.do.form exp.do.emptystmt exp.field.con.form exp.field.upd.form exp.sig.form
-- Report 3.6 to 3.16: if, lists, the tuple constructors, arithmetic sequences, comprehensions, let, case with guards,
-- where and empty alternatives and a parenthesised signature in a guard, do with each statement and empty ones,
-- labelled construction and update with qualified names, and expression signatures with a context.
module Main (main) where

import qualified Prelude as P
import Prelude

data R = R { f :: Int, g :: Int } deriving Show

main :: IO ()
main = do { print (if True then 1 else 2 :: Int, [1], [1, 2], (,) 1 2, (,,,) 1 2 3 4)
          ; print ([1 ..] !! 1 :: Int, [1, 2 ..] !! 1 :: Int, [1 .. 3 :: Int], [1, 2 .. 3 :: Int], [ x | x <- [1 .. 3 :: Int], odd x, let y = x ])
          ; print (let {} in 1 :: Int, let { a = 1 ; b = 2 } in a + b :: Int, let a = 1
                                                                                  b = 2 in a + b :: Int)
          ; print (case 1 :: Int of { 1 | False -> 0 | otherwise -> z where { z = 1 } ; ; _ -> 2 ; },
                   case True of
                     y | (y :: Bool) -> 1
                       | True -> 2 :: Int)
          ; ; x <- return 1 ; let { r = Main.R { Main.f = x, g = 2 } } ; print (r { f = 3 }, (1 :: Num a => a) :: Int, x :: Int) ; }
