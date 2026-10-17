module Main where
import Board
import Move
import Problem
main = do
 input <- getContents
 let (bd,(c,n))=readProblem input
 putStr (showBoard bd)
 putStrLn (show (kingincheck White bd,kingincheck Black bd))
 mapM_ (\(m,b)->putStrLn(showMoveInFull m) >> putStr(showBoard b)) (moveDetailsFor c bd)
