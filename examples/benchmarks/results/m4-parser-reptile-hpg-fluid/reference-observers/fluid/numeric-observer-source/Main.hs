module Main where
import S_Array
import C_matrix
import S_matrix
import L_matrix
import Jcb_method
import Asb_routs
import Tol_cal
import GHC.Float(castFloatToWord32)
import Data.List(intercalate)
cases :: [((Float,Float,Float),(Float,Float,Float))]
cases=[((1,2,3),(4,5,6)),((0.125,-0.25,0.5),(-0.75,1.25,2.5)),((0,0,0),(0,0,0)),((-3,2,0.33333334),(0.14285715,-5,9))]
dump name values=putStrLn(name++"|"++intercalate ","(map(show . castFloatToWord32)values))
main=do
 dump "mass-row-sums"(s_elems m_r_sum)
 dump "mass-matrix"(concatMap id(s_elems m_mat))
 dump "subnormal"[1.0e-40]
 mapM_ (\(i,factors@(a,b))->do
   dump("diffusion-"++show i)(concatMap($factors)(s_elems s_mat))
   dump("gradient-a-"++show i)(concatMap($a)(s_elems l_mat))
   dump("gradient-b-"++show i)(concatMap($b)(s_elems l_mat'))
   dump("convection-"++show i)(concatMap(\f->f factors([1,2,3,4,5,6],[6,5,4,3,2,1]))(s_elems c_mat))) (zip[0..]cases)
 dump "inner"[list_inner_prod[1,2,3,4][0.125,-0.25,0.5,-0.75]]
 dump "match"[list_match_prod[1,2,3,4][0.125,-0.25,0.5,-0.75]]
 dump "tolerances"[tol_cal[1,2,3][0.1,-0.2,0.3]False,tol_cal[0.1,0.2,0.3][0.01,-0.02,0.03]False,
  tol_cal[0.1,0.2,0.3][0.01,-0.02,0.03]True]
