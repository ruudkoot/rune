val () = print (Bool.toString (OS.Process.isSuccess OS.Process.success) ^ " " ^ Bool.toString (OS.Process.isSuccess OS.Process.failure) ^ " " ^ Bool.toString (OS.Process.success = OS.Process.failure) ^ "\n")
val () = OS.Process.exit OS.Process.failure
