module ExactPrepare where
import Data.Array
import Data.List
import Prelude hiding (null, length, or, foldr, maximum, concat, concatMap, foldl, foldr1, foldl1, sum, all, elem)
import Data.Ratio

import RandomFix
import LinearAlgebra
import Types

prepare :: Circuit -> Time -> (Vector Exact, Matrix Exact, Matrix Exact, Matrix Exact, Matrix Exact)
prepare circuit dt = (initial, solve, integrate, correct_state, backdate)
  where
	elements				= matrix element
	derivative				= matrix deriv
	initial					= vector init

	(l1, u1, i1)				= gauss_jordan               elements
	(l2, u2, i2)				= gauss_jordan (m_transpose  elements)
	constraint				=                            m_select_rows l1 i1
	freedom					=               m_transpose (m_select_rows l2 i2)

	(l3, u3, i3)				= gauss_jordan (m_mul constraint (m_mul derivative freedom))
	inverse3		| l3 == []	= i3
				| otherwise	= error "illegal circuit"
	correct			| l1 == []	= m_zero size
				| otherwise	= m_mul freedom (m_mul inverse3 constraint)
	correct_state				= m_sub (m_unit size) (m_mul derivative correct   )
	correct_output				= m_sub (m_unit size) (m_mul correct    derivative)

	solve					= m_mul correct_output (m_mul i1 correct_state)

	scaled_derivative			= m_map (* (dt / 2)) (m_mul derivative solve)
	(l4, u4, i4)				= gauss_jordan (m_sub (m_unit size) scaled_derivative)
	integrate		| l4 == []	= m_mul i4     (m_add (m_unit size) scaled_derivative)
				| otherwise	= error "unlucky choice of dt - try a smaller one"

	backdate				= m_map (/ dt) correct

	matrix f				= accumArray (+) (0 % 1) ((1, 1), (size, size)) ((filter no_ground . concat . map f) circuit)
	vector f				= accumArray (+) (0 % 1) ( 1    ,  size       ) ((                   concat . map f) circuit)

  	element	(i, p, m, Conductor  g       )	= [((p, i), -1 % 1), ((m, i),  1 % 1), ((i, m), -g    ), ((i, p),  g    ), ((i, i), -1 % 1)]
  	element	(i, p, m, Resistor   r       )	= [((p, i), -1 % 1), ((m, i),  1 % 1), ((i, m), -1 % 1), ((i, p),  1 % 1), ((i, i), -r    )]
	element	(i, p, m, Capacitor (c, _)   )	= [((p, i), -1 % 1), ((m, i),  1 % 1), ((i, m), -c    ), ((i, p),  c    )]
	element	(i, p, m, Inductor  (l, _)   )	= [((p, i), -1 % 1), ((m, i),  1 % 1), ((i, i),  l    )]
	element	(i, p, m, Vsource    _       )	= [((p, i), -1 % 1), ((m, i),  1 % 1), ((i, m), -1 % 1), ((i, p),  1 % 1)]
	element	(i, p, m, Isource    _       )	= [((p, i), -1 % 1), ((m, i),  1 % 1), ((i, i),  1 % 1)]
	element	(i, p, m, Junction  (c, _, _))	= [((p, i), -1 % 1), ((m, i),  1 % 1), ((i, m), -c    ), ((i, p),  c    )]

  	deriv 	(i, p, m, Conductor  _       )	= []
  	deriv 	(i, p, m, Resistor   _       )	= []
	deriv 	(i, p, m, Capacitor (_, _)   )	= [((i, i),  1)]
	deriv 	(i, p, m, Inductor  (_, _)   )	= [((i, p),  1), ((i, m), -1)]
	deriv 	(i, p, m, Vsource    _       )	= []
	deriv 	(i, p, m, Isource    _       )	= []
	deriv 	(i, p, m, Junction  (_, _, _))	= [((i, i),  1)]

  	init	(i, p, m, Conductor  _       )	= []
  	init   	(i, p, m, Resistor   _       )	= []
	init    (i, p, m, Capacitor (_, q)   )	= [(i, q)]
	init   	(i, p, m, Inductor  (_, f)   )	= [(i, f)]
	init   	(i, p, m, Vsource    _       )	= []
	init   	(i, p, m, Isource    _       )	= []
	init   	(i, p, m, Junction  (_, _, q))	= [(i, q)]

	no_ground ((r, c), _)			= r /= 0 && c /= 0
	size					= maximum (concat (map (\(p, m, i, _) -> [p, m, i]) circuit))
