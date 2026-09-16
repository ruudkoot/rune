datatype 'a box = Box of 'a
val alias = Box
val Box id = alias (fn x => x)
val _ = (id 1,id true)
