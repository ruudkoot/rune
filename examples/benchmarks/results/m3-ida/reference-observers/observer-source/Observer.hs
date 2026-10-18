module Main where
import qualified Ida as I
pos (I.F_POS x y)="("++show x++","++show y++")"
squares xs=concatMap I.f_show_square xs
path(I.F_SEARCH _ _ _ ps)=concatMap pos ps
observe(seed,w,h,n)=
 let conf@(I.F_CONF hole tiles)=I.f_shuffle (I.f_goal w h) n (I.f_cons_rnd_gen seed)
     I.F_SOLUTION search count=I.f_solve_puzzle conf 7 (n+1)
     I.F_SEARCH bound depth _ ps=search
 in putStrLn(show(seed,w,h,n)++" "++I.f_show_pos hole++squares tiles++" | "++show bound++" "++show count++" "++show depth++" "++path search)
main=mapM_ observe [(0,2,3,0),(0,2,3,1),(0,2,3,5),(0,2,3,20),(0,2,4,0),(0,2,4,1),(0,2,4,5),(0,2,4,20),(0,3,3,0),(0,3,3,1),(0,3,3,5),(0,3,3,20),(6,2,3,0),(6,2,3,1),(6,2,3,5),(6,2,3,20),(6,2,4,0),(6,2,4,1),(6,2,4,5),(6,2,4,20),(6,3,3,0),(6,3,3,1),(6,3,3,5),(6,3,3,20),(42,2,3,0),(42,2,3,1),(42,2,3,5),(42,2,3,20),(42,2,4,0),(42,2,4,1),(42,2,4,5),(42,2,4,20),(42,3,3,0),(42,3,3,1),(42,3,3,5),(42,3,3,20),(6,3,4,100)]
