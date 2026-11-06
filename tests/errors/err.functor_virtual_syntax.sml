(* functor F = is a virtual or a dynamic functor's, and nothing else's *)
signature S = sig val x : int end
functor F = struct val x = 1 end
