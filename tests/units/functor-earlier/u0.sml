(* the first unit (`flags`: --functors=functions, the lint, G marked to
   be inlined): a polymorphic function that the second unit's arguments
   pass to functors, and a functor marked to be inlined *)
structure A = struct fun mk n = n end
functor G (X : sig val mk : int -> int end) = struct fun mk n = X.mk n + 1 end
