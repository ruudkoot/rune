structure P=BenchStdlibTreePrograms
val baseline=P.denseMap 10000
val _=List.app(fn name=>print(name^" "^P.mapRun name baseline 5^"\n"))
 ["map_iter","map_add","map_add_duplicate","map_remove","map_fold","map_for_all","map_find","map_map"]
val _=List.app(fn name=>print(name^" "^P.setRun name 5^"\n"))["set_fold","set_mem","set_add_rem"]
