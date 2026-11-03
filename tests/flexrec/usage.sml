(* a flexible record left to the file after it: tests/errors, err.flex_later_file *)
structure C = struct
  fun usage result = (#wall result : Time.time, Time.+ (#user result, #system result))
end
