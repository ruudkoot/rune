module Main where
import Kernel
import System.Environment
emit p1@(x1,y1) p2@(x2,y2) tree=case tree of
 Leaf c->putStrLn(unwords["L",show x1,show y1,show x2,show y2,show c])
 NS left right->do
  putStrLn(unwords["NS",show x1,show y1,show x2,show y2])
  let split=(x1+x2)`div`2
  emit p1(split,y2)left
  emit(split+1,y1)p2 right
 EW left right->do
  putStrLn(unwords["EW",show x1,show y1,show x2,show y2])
  let split=(y1+y2)`div`2
  emit p1(x2,split)left
  emit(x1,split+1)p2 right
main=do
 [arg]<-getArgs
 let width=read arg
 emit(0,0)(width,width`div`2)(build_tree(0,0)(width,width`div`2))
