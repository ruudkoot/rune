module Main where
import Board
import Game
import Prog
import Tree
testBoard=[[Empty,O,Empty],[Empty,X,Empty],[Empty,Empty,Empty]]
main=do
 putStr(prog "1")
 putStrLn("LENGTH "++show(length(prog "1")))
 print(map snd(alternate X max' min' testBoard))
 print[(i,j,static b)|i<-[1..3],j<-[1..3],b<-placePiece X testBoard(i,j)]
