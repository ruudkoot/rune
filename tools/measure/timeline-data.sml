(* Versioned timing coefficients and explicit placeholder categories. *)
structure MeasureTimelineData =
struct
  val coefficients = [("fixed_minor",2000.0), ("fixed_major",20000.0), ("fixed_satb",1000.0), ("slot",8.5), ("frame",20.0), ("stack_ptr",0.0), ("card",30.0), ("card_byte",0.1), ("remset",5.0), ("born_rem_field",2.0), ("mut_scan_byte",0.1), ("copy_obj",5.3), ("copy_byte",0.1), ("mark_obj",2.0), ("mark_field",1.6), ("sweep_byte",0.03), ("move_obj",6.0), ("move_byte",0.4), ("evac_obj",10.0), ("evac_byte",0.55), ("scan_obj_lisp2",3.0), ("scan_byte_lisp2",0.07), ("scan_obj_jonkers",4.0), ("scan_byte_jonkers",0.07), ("ptr_jonkers",3.0), ("satb_byte",0.26)]
  val rates = [("interp",6.9), ("default",3.5), ("jit",2.0)]
  val placeholders = ["fixed_minor", "fixed_major", "fixed_satb", "card", "remset", "born_rem_field", "sweep_byte", "scan_obj_lisp2", "scan_obj_jonkers", "ptr_jonkers"]
end
