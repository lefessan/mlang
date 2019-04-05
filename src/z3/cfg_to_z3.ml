(*
Copyright Inria, contributor: Denis Merigoux <denis.merigoux@inria.fr> (2019)

This software is a computer program whose purpose is to compile and analyze
programs written in the M langage, created by thge DGFiP.

This software is governed by the CeCILL-B license under French law and
abiding by the rules of distribution of free software.  You can  use,
modify and/ or redistribute the software under the terms of the CeCILL-B
license as circulated by CEA, CNRS and INRIA at the following URL
http://www.cecill.info.

As a counterpart to the access to the source code and  rights to copy,
modify and redistribute granted by the license, users are provided only
with a limited warranty  and the software's author,  the holder of the
economic rights,  and the successive licensors  have only  limited
liability.

In this respect, the user's attention is drawn to the risks associated
with loading,  using,  modifying and/or developing or reproducing the
software by the user in light of its specific status of free software,
that may mean  that it is complicated to manipulate,  and  that  also
therefore means  that it is reserved for developers  and  experienced
professionals having in-depth computer knowledge. Users are therefore
encouraged to load and test the software's suitability as regards their
requirements in conditions enabling the security of their systems and/or
data to be ensured and,  more generally, to use and operate it in the
same conditions as regards security.

The fact that you are presently reading this means that you have had
knowledge of the CeCILL-B license and that you accept its terms.
*)

let bv_repr_ints_base = 20

let declare_var (var: Cfg.Variable.t) (typ: Z3_repr.repr) (ctx: Z3.context) : Z3.Expr.expr =
  match typ with
  | Z3_repr.Boolean ->
    Z3.Boolean.mk_const_s ctx (Ast.unmark var.Cfg.Variable.name)
  | Z3_repr.Integer o ->
    Z3.BitVector.mk_const_s ctx (Ast.unmark var.Cfg.Variable.name) (bv_repr_ints_base * o)
  | Z3_repr.Real o ->
    Z3.BitVector.mk_const_s ctx (Ast.unmark var.Cfg.Variable.name) (bv_repr_ints_base * o)

let translate_program
    (p: Cfg.program)
    (typing: Z3_repr.repr_info)
    (ctx: Z3.context)
    (s: Z3.Solver.solver)
  : (Z3.Expr.expr * Z3_repr.repr) Cfg.VariableMap.t =
  (* first we declare to Z3 all the variables *)
  let z3_vars = Cfg.VariableMap.mapi (fun var typ ->
      try
        (declare_var var typ ctx, typ)
      with
      | Not_found -> assert false (* should not happen *)
    ) typing.Z3_repr.repr_info_var in
  z3_vars
