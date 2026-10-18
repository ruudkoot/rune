module Fingerprints where
import qualified Main as N
import Types
import GHC.Float(castFloatToWord32)
point(Pt x y z)=map castFloatToWord32[x,y,z]
matrix(Tfo a b c d e f g h i j k l)=map castFloatToWord32[a,b,c,d,e,f,g,h,i,j,k,l]
kind(A _ _ _ _ _ _ _ _)=0::Int
kind(C _ _ _ _ _ _)=1
kind(G _ _ _ _ _ _ _ _ _)=2
kind(U _ _ _ _ _)=3
fingerprint(Nuc t0 t1 t2 t3 p0 p1 p2 p3 p4 p5 p6 p7 p8 p9 p10 p11 p12 p13 p14 p15 p16 p17 p18 p19 p20 p21 p22 p23 p24 x)=(kind x,concatMap matrix[t0,t1,t2,t3])
atoms v@(N.Var i t n)=(i,fingerprint n,map(point . N.absolute_pos v)(N.list_of_atoms n))
main=mapM_(print . map atoms)(N.pseudoknot "1")
