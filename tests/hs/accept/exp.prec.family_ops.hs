-- rows: exp.fix.paren exp.infix.form exp.op.varop exp.op.qvarop exp.op.conop exp.op.qconop exp.var.qualified exp.var.operator exp.con.qualified exp.gcon.unit exp.gcon.nil exp.gcon.tuple exp.app.syntax
-- Report 3: exp is a family by precedence and associativity; 3.2 and 3.4: variables, constructors and operators, qualified
-- or not, symbols in parentheses and identifiers in backquotes, the special constructors, and application of any
-- aexp; parentheses about either pair of a non-associative chain remove its error.
module Main (main) where

import qualified Prelude as P
import Prelude
import qualified Complex as Cx

data T = Int :+: Int | C Int Int deriving Show
infixl 6 :+:

op :: Int -> Int -> Int
op = (+)

main :: IO ()
main = do
  print ((1 == 1) == True, True == (1 == 1), 2 + 3 `op` 4, 1 P.+ 2, 7 `P.div` 2)
  print (P.id 1)
  print (P.map (+ 1) [1], (+) 1 2, (P.+) 1 2, 1 :+: 2, 1 `C` 2)
  print (1 : [], 1 Cx.:+ (2 :: Double), (Cx.:+) 1 (2 :: Double), (:) 1 [], ())
  print ([] :: [Int], (,) 1 2, (,,) 1 2 3, id (id 1), f 1 'c' "s" (+ 1) (1 +) [1] (C 1 2))
  where f _ _ _ _ _ _ _ = ()
