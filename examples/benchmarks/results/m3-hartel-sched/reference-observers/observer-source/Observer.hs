module Main where
import SchedSource
import Data.Bits
import Data.Word
input n=case n of
 1->c_solo;3->c_trio;7->c_septiem;10->c_deciem;11->c_undeciem;12->c_duodeciem;14->c_quadrideciem;_->C_EMPTYJOBDEF
mix :: Word32 -> Int -> Word32
mix h n=(xor h (fromIntegral n))*16777619
walk h (F_LEAF n)=(1,n,n,toInteger n,mix h n)
walk h (F_TREE a b)=
 let (ca,la,ha,sa,x)=walk(mix h 1)a
     (cb,lb,hb,sb,y)=walk(mix x 2)b
 in(ca+cb,min la lb,max ha hb,sa+sb,y)
showCase(n,t)=
 let tree=f_sched(input n)t
     (count,low,high,total,hash)=walk 2166136261 tree
 in putStrLn(unwords(map show[n,t,count,low,high])++" "++show total++" "++show hash)
main=mapM_ showCase [(0,0),(0,100),(1,0),(1,100),(2,0),(2,100),(3,0),(3,100),(7,0),(7,4),(7,100),(10,0),(10,7),(10,100),(11,0),(11,8),(11,100),(12,0),(12,9),(12,100),(14,0),(14,11),(14,100)]
