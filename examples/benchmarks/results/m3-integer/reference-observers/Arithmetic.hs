module Main where
import Data.Bits
import Data.Word
import Data.Char
import Numeric
import Control.Exception
pairs :: [(Int,Int)]
pairs=[(-7,3),(7,-3),(-7,-3),(0,3),(2147483647,17),(-2147483648,17),(2100000000,-2100000000)]
ops :: [(String,Int->Int->Int)]
ops=[("add",(+)),("sub",(-)),("mul",(*)),("div",div),("mod",mod),("quot",quot),("rem",rem),("gcd",gcd),("lcm",lcm),("eq",\a b->if a==b then 1 else 0),("lt",\a b->if a<b then 1 else 0),("le",\a b->if a<=b then 1 else 0),("gt",\a b->if a>b then 1 else 0),("ge",\a b->if a>=b then 1 else 0)]
main=do
 if finiteBitSize(0::Int)/=64 then error "64-bit original reference required" else return ()
 mapM_ (\(a,b)->mapM_ (\(name,op)->putStrLn(show a++" "++show b++" "++name++" "++map toUpper(showHex(fromIntegral(op a b)::Word64)"")))ops)pairs
 print ((maxBound::Int)+1,(minBound::Int)-1,(maxBound::Int)*2)
