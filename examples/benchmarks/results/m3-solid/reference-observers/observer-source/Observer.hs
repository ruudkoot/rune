module Main where
import Kernel
import System.Environment
import Text.Printf
scene=fst(f_f_Csg_CSGget c_aap f_f_Hs2_geths f_f_Hs2_getrop)
shape(F_T_Gd_Terminal(_,C_T_Csg_Fullsolid))="F"
shape(F_T_Gd_Terminal(_,C_T_Csg_Emptysolid))="E"
shape(F_T_Gd_Interior children)="("++concatMap shape children++")"
main=do
 args<-getArgs
 case args of
  ["scene"]->putStr c_aap
  ["areas",n]->mapM_(\depth->do
    let tree=f_f_main_create_sdsm c_f_main_UNIV scene depth
        area=f_f_main_area tree
    printf "%d %.17g %d\n" depth area (round(area*4^depth)::Integer)
    ) [0..read n]
  ["shape",n]->putStrLn(shape(f_f_main_create_sdsm c_f_main_UNIV scene(read n)))
  ["tables"]->mapM_(\(op,name)->mapM_(\(a,b)->print(name,a,b,f_f_main_combine_classifications a op b))[(a,b)|a<-[0..2],b<-[0..2]])[(C_T_Hs2_Un,"union"),(C_T_Hs2_Inter,"intersect"),(C_T_Hs2_Diff,"diff")]
  _->error"expected scene|areas depth|shape depth|tables"
