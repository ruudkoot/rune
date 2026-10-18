module Database where
import Main
import Types
import qualified RA
import qualified RC
import qualified RG
import qualified RU
import GHC.Float(castFloatToWord32)
point(Pt x y z)=map castFloatToWord32[x,y,z]
matrix(Tfo a b c d e f g h i j k l)=map castFloatToWord32[a,b,c,d,e,f,g,h,i,j,k,l]
specific(A p0 p1 p2 p3 p4 p5 p6 p7)=(0,concatMap point[p0,p1,p2,p3,p4,p5,p6,p7])
specific(C p0 p1 p2 p3 p4 p5)=(1,concatMap point[p0,p1,p2,p3,p4,p5])
specific(G p0 p1 p2 p3 p4 p5 p6 p7 p8)=(2,concatMap point[p0,p1,p2,p3,p4,p5,p6,p7,p8])
specific(U p0 p1 p2 p3 p4)=(3,concatMap point[p0,p1,p2,p3,p4])
nucleotide(Nuc t0 t1 t2 t3 p0 p1 p2 p3 p4 p5 p6 p7 p8 p9 p10 p11 p12 p13 p14 p15 p16 p17 p18 p19 p20 p21 p22 p23 p24 x)=(concatMap matrix[t0,t1,t2,t3],concatMap point[p0,p1,p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21,p22,p23,p24],specific x)
main=mapM_(print . nucleotide)[RA.rA,RA.rA01,RA.rA02,RA.rA03,RA.rA04,RA.rA05,RA.rA06,RA.rA07,RA.rA08,RA.rA09,RA.rA10,RC.rC,RC.rC01,RC.rC02,RC.rC03,RC.rC04,RC.rC05,RC.rC06,RC.rC07,RC.rC08,RC.rC09,RC.rC10,RG.rG,RG.rG01,RG.rG02,RG.rG03,RG.rG04,RG.rG05,RG.rG06,RG.rG07,RG.rG08,RG.rG09,RG.rG10,RG.rG',RU.rU,RU.rU01,RU.rU02,RU.rU03,RU.rU04,RU.rU05,RU.rU06,RU.rU07,RU.rU08,RU.rU09,RU.rU10,RU.rU']
