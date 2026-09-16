datatype 'a box = Box of 'a
val Box id = Box ((fn x => x) (fn x => x))
val _ = (id 1,id true)
