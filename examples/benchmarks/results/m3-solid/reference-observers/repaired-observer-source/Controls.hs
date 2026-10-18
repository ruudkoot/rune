module Main where
import Kernel
import Text.Printf
tag C_T_Csg_Fullsolid="F"
tag C_T_Csg_Emptysolid="E"
tag(F_T_Csg_Primitive _)="P"
tag(F_T_Csg_Compose _ _ _)="C"
c r x y=F_T_Csg_Primitive(F_T_Hs2_circle r(f_f_Geom2D_ptmake x y),0)
l a b v=F_T_Csg_Primitive(F_T_Hs2_line a b v,0)
named=[("circle",c 0.5 0.5 0.5),("union",F_T_Csg_Compose(c 0.5 0.5 0.5)C_T_Hs2_Un(c 0.25 0.25 0.25)),("intersect",F_T_Csg_Compose(c 0.5 0.5 0.5)C_T_Hs2_Inter(c 0.25 0.25 0.25)),("diff",F_T_Csg_Compose(c 0.5 0.5 0.5)C_T_Hs2_Diff(c 0.25 0.25 0.25)),("full",C_T_Csg_Fullsolid),("empty",C_T_Csg_Emptysolid)]
main=do
 mapM_(\(op,name)->mapM_(\(a,b)->putStrLn("table "++name++" "++show a++" "++show b++" "++show(f_f_main_combine_classifications a op b)))[(a,b)|a<-[0..3],b<-[0..3]])[(C_T_Hs2_Un,"union"),(C_T_Hs2_Inter,"intersect"),(C_T_Hs2_Diff,"diff")]
 mapM_(\(name,tree)->mapM_(\depth->do
   let spatial=f_f_main_create_sdsm c_f_main_UNIV tree depth
       area=f_f_main_area spatial
   printf "area %s %d %d\n" name depth(round(area*4^depth)::Integer)
  )[0..6])named
 putStrLn("line-source "++show(f_f_Csg_CSGtraverse_2(f_f_Geom2D_ptmake 0.0 1.0)(l 0.0 1.0 0.5)f_f_main_classify_prim f_f_main_combine_classifications c_f_main_IN c_f_main_OUT))
 putStrLn("line-prune "++tag(f_f_Csg_CSGtraverse_2 c_f_main_UNIV(l 0.0 1.0 0.5)f_f_main_prune_hs f_f_main_merge_subtrees C_T_Csg_Fullsolid C_T_Csg_Emptysolid))
