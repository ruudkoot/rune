-- rows: lex.float.exponent lex.float.expform
-- Report 2.5: float -> decimal . decimal [exponent] | decimal exponent; exponent -> (e | E) [+ | -] decimal.
module Main (main) where

main :: IO ()
main = print ([1.5, 1.5e3, 1e3, 1E3, 1e+3, 1e-3, 0.5E-2] :: [Double])
