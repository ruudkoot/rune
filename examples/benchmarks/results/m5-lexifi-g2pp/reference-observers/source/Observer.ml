module D=Data
open G2pp_calibration
let run limit=
 let result=calibrate ~max_global:limit ~today:D.today ~swaption_quotes:D.swaption_quotes ~variables:D.variables ~zc:D.zc()in
 let {Optimization.cr_parameters=p;cr_root_mean_squared_error=rms;cr_quoted_prices=quotes;cr_calibrated_prices=prices}=result in
 Printf.printf "limit %d\nparameters %.17g %.17g %.17g %.17g %.17g\nrms %.17g\n"limit p.g_a p.g_b p.g_sigma p.g_nu p.g_rho rms;
 Array.iteri(fun i value->Printf.printf "price %d %.17g %.17g\n"i value quotes.(i))prices
let ()=List.iter run[40;2000;20000]
