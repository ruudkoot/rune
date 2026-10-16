module Main where
import Data.Ratio
import GHC.Float
main=mapM_ print [(numerator x,denominator x,castDoubleToWord64(fromRational x)) | x<-xs]
 where
  xs=[0,1,(-1),1%3,(-1)%3,1%10,(2^53+1)%1,(2^53+3)%1,(2^54+2)%3,
      1%(2^1074),1%(2^1075),3%(2^1075),(-1)%(2^1075),(2^52-1)%(2^1074),
      (2^53-1)*2^971,(2^54-1)*2^970,10^100%3,3%10^100]
