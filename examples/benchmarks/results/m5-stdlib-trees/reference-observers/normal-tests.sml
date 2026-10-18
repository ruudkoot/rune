structure StdlibTreeNormalTests=struct
 structure P=BenchStdlibTreePrograms
 val baseline=P.denseMap 10000
 val _=T.check("stdlib-tree-normal/map_iter",fn()=>P.mapRun "map_iter" baseline 1000="989680")
 val _=T.check("stdlib-tree-normal/map_add",fn()=>P.mapRun "map_add" baseline 100000="540D6AA0")
 val _=T.check("stdlib-tree-normal/map_add_duplicate",fn()=>P.mapRun "map_add_duplicate" baseline 100000="540D6AA0")
 val _=T.check("stdlib-tree-normal/map_remove",fn()=>P.mapRun "map_remove" baseline 1000000="5F5B9F0")
 val _=T.check("stdlib-tree-normal/map_fold",fn()=>P.mapRun "map_fold" baseline 1000="47DE5180")
 val _=T.check("stdlib-tree-normal/map_for_all",fn()=>P.mapRun "map_for_all" baseline 1000="3E8")
 val _=T.check("stdlib-tree-normal/map_find",fn()=>P.mapRun "map_find" baseline 1000000="270F")
 val _=T.check("stdlib-tree-normal/map_map",fn()=>P.mapRun "map_map" baseline 1000="EBCD7A40")
 val _=T.check("stdlib-tree-normal/set_fold",fn()=>P.setRun "set_fold" 10000="2A523D40")
 val _=T.check("stdlib-tree-normal/set_mem",fn()=>P.setRun "set_mem" 1000000="3E8")
 val _=T.check("stdlib-tree-normal/set_add_rem",fn()=>P.setRun "set_add_rem" 100000="0")
end
