module Main where
import Digraph
main :: IO ()
main = print (head (snd (dfs (\_ -> error "unneeded neighbours") ([],[]) [1::Int])))
