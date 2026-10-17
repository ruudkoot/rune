module Main where
import Board
import Game
piece 'X'=X
piece 'O'=O
piece '.'=Empty
board s=map(map piece)[take 3 s,take 3(drop 3 s),drop 6 s]
emit s=let b=board s in putStrLn(s++":"++show(static b)++":"++show(bestMove X max' min' b)++":"++show(bestMove O min' max' b))
main=mapM_ emit [".O..X....", "XO.XO....", "XOXXO.O..", "XXXOO....", "OOOXX....", "XOXOXOXOX", "XXXOOO...", "OOOXXX...", ".XO.OXX..", "XX.OO....", "X.O.O.X.."]
