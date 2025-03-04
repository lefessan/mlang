(* Copyright (C) 2019-2021 Inria, contributors: Denis Merigoux <denis.merigoux@inria.fr> Raphël
   Monat <raphael.monat@lip6.fr>

   This program is free software: you can redistribute it and/or modify it under the terms of the
   GNU General Public License as published by the Free Software Foundation, either version 3 of the
   License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
   even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License along with this program. If
   not, see <https://www.gnu.org/licenses/>. *)

module StringMap = Map.Make (struct
  type t = string

  let compare = compare
end)

type translation_ctx = {
  new_variables : Mir.Variable.t StringMap.t;
  variables_used_as_inputs : Mir.VariableDict.t;
  rule_instances : Bir.rule Bir.RuleMap.t;
}

let emtpy_translation_ctx : translation_ctx =
  {
    new_variables = StringMap.empty;
    variables_used_as_inputs = Mir.VariableDict.empty;
    rule_instances = Bir.RuleMap.empty;
  }

let ctx_join ctx1 ctx2 =
  {
    new_variables =
      StringMap.union
        (fun _ v1 v2 ->
          assert (Mir.Variable.compare v1 v2 = 0);
          Some v2)
        ctx1.new_variables ctx2.new_variables;
    variables_used_as_inputs =
      Mir.VariableDict.union ctx1.variables_used_as_inputs ctx2.variables_used_as_inputs;
    rule_instances = Bir.RuleMap.union (fun _ r _ -> Some r) ctx1.rule_instances ctx2.rule_instances;
  }

let translate_to_binop (b : Mpp_ast.binop) : Mast.binop =
  match b with And -> And | Or -> Or | _ -> assert false

let translate_to_compop (b : Mpp_ast.binop) : Mast.comp_op =
  match b with
  | Gt -> Gt
  | Gte -> Gte
  | Lt -> Lt
  | Lte -> Lte
  | Eq -> Eq
  | Neq -> Neq
  | _ -> assert false

let rec list_map_opt (f : 'a -> 'b option) (l : 'a list) : 'b list =
  match l with
  | [] -> []
  | hd :: tl -> (
      match f hd with None -> list_map_opt f tl | Some fhd -> fhd :: list_map_opt f tl)

let generate_input_condition (crit : Mir.Variable.t -> bool) (p : Mir_interface.full_program)
    (pos : Pos.t) =
  let variables_to_check = Mir.VariableDict.filter (fun _ var -> crit var) p.program.program_vars in
  let mk_call_present x = (Mir.FunctionCall (PresentFunc, [ (Mir.Var x, pos) ]), pos) in
  let mk_or e1 e2 = (Mir.Binop ((Or, pos), e1, e2), pos) in
  let mk_false = (Mir.Literal (Float 0.), pos) in
  Mir.VariableDict.fold (fun var acc -> mk_or (mk_call_present var) acc) variables_to_check mk_false

let var_is_ (attr : string) (v : Mir.Variable.t) : bool =
  List.exists
    (fun ((attr_name, _), (attr_value, _)) -> attr_name = attr && attr_value = Mast.Float 1.)
    v.Mir.Variable.attributes

let cond_DepositDefinedVariables : Mir_interface.full_program -> Pos.t -> Mir.expression Pos.marked
    =
  generate_input_condition (var_is_ "acompte")

let cond_TaxbenefitDefinedVariables :
    Mir_interface.full_program -> Pos.t -> Mir.expression Pos.marked =
  generate_input_condition (var_is_ "avfisc")

let cond_TaxbenefitCeiledVariables (p : Mir_interface.full_program) (pos : Pos.t) :
    Mir.expression Pos.marked =
  (* commented aliases do not exist in the 2018 version *)
  (* double-commented aliases do not exist in the 2019 version *)
  (* triple-commented aliases do not exist in the 2020 version *)
  let aliases_list =
    [
      (*(*(*"7QK";*)*)*)
      (*(* "7QD"; *)*)
      (*(* "7QB"; *)*)
      (*(* "7QC"; *)*)
      "4BA";
      "4BY";
      "4BB";
      "4BC";
      "7CL";
      (*(*(*"7CM";*)*)*)
      (*(* "7CN"; *)*)
      (*(* "7QE"; *)*)
      (*(* "7QF"; *)*)
      (*(* "7QG"; *)*)
      (*(* "7QH"; *)*)
      (*(*(*"7QI";*)*)*)
      (*(*(*"7QJ";*)*)*)
      "7LG";
      (* "7MA"; *)
      "7QM";
      "2DC";
      (* "7KM"; *)
      (* "7KG"; *)
      "7QP";
      "7QS";
      "7QN";
      "7QO";
      (*(*(*"7QL";*)*)*)
      (*(* "7LS"; *)*)
    ]
  in
  let supp_avfisc =
    List.fold_left
      (fun vmap var -> Mir.VariableMap.add (Mir.find_var_by_name p.program var) () vmap)
      Mir.VariableMap.empty
      (List.map (fun x -> (x, Pos.no_pos)) aliases_list)
  in
  generate_input_condition (fun v -> Mir.VariableMap.mem v supp_avfisc) p pos

let reset_and_add_outputs (p : Mir_interface.full_program) (outputs : string Pos.marked list) :
    Mir_interface.full_program =
  let outputs = List.map (fun out -> Mir.find_var_by_name p.program out) outputs in
  let program =
    Mir.map_vars
      (fun var data ->
        if List.mem var outputs then
          match data.Mir.var_io with
          | Input ->
              raise
                (Bir_interpreter.RegularFloatInterpreter.RuntimeError
                   ( Bir_interpreter.RegularFloatInterpreter.IncorrectOutputVariable
                       ( Format.asprintf "%a is an input" Format_mir.format_variable var,
                         Pos.get_position var.Mir.Variable.name ),
                     Bir_interpreter.RegularFloatInterpreter.empty_ctx ))
          | Output -> data
          | Regular -> { data with var_io = Output }
        else
          match data.Mir.var_io with
          | Input | Regular -> data
          | Output -> { data with var_io = Regular })
      p.program
  in
  { p with program }

let translate_m_code (m_program : Mir_interface.full_program)
    (vars : (Mir.Variable.id * Mir.variable_data) list) =
  list_map_opt
    (fun (vid, (vdef : Mir.variable_data)) ->
      try
        let var = Mir.VariableDict.find vid m_program.program.program_vars in
        match vdef.var_definition with
        | InputVar -> None
        | _ ->
            (* variables used in the context should not be reassigned *)
            Some (Bir.SAssign (var, vdef), var.Mir.Variable.execution_number.pos)
      with Not_found -> None)
    vars

let generate_rule_instance (m_program : Mir_interface.full_program) (rule_id : Mir.rule_id)
    (ctx : translation_ctx) : Mir.rule_id * Pos.t * translation_ctx =
  let instance_id = Mir.fresh_rule_id () in
  let rule = Mir.RuleMap.find rule_id m_program.program.program_rules in
  let rule_stmts = translate_m_code m_program rule.rule_vars in
  let pos, rule_name =
    let pos = Pos.get_position rule.Mir.rule_number in
    let name = string_of_int (Pos.unmark rule.Mir.rule_number) in
    (pos, name ^ "_i" ^ string_of_int instance_id)
  in
  let instance = Bir.{ rule_id = instance_id; rule_name; rule_stmts } in
  ( instance_id,
    pos,
    { ctx with rule_instances = Bir.RuleMap.add instance_id instance ctx.rule_instances } )

let wrap_m_code_call (m_program : Mir_interface.full_program) execution_order
    (args : Mpp_ir.scoped_var list) (ctx : translation_ctx) : translation_ctx * Bir.stmt list =
  let m_program =
    reset_and_add_outputs m_program
      (List.map
         (function Mpp_ir.Mbased (s, _) -> s.Mir.Variable.name | Local l -> (l, Pos.no_pos))
         args)
  in
  let m_program =
    {
      m_program with
      program =
        Bir_interpreter.RegularFloatInterpreter.replace_undefined_with_input_variables
          m_program.program ctx.variables_used_as_inputs;
    }
  in
  let program_stmts, ctx =
    List.fold_left
      (fun (stmts, ctx) rule_id ->
        let instance_id, pos, ctx = generate_rule_instance m_program rule_id ctx in
        ((Bir.SRuleCall instance_id, pos) :: stmts, ctx))
      ([], ctx) execution_order
  in
  let program_stmts = List.rev program_stmts in
  (ctx, program_stmts)

let rec translate_mpp_function (mpp_program : Mpp_ir.mpp_compute list)
    (m_program : Mir_interface.full_program) (compute_decl : Mpp_ir.mpp_compute)
    (args : Mpp_ir.scoped_var list) (ctx : translation_ctx) : translation_ctx * Bir.stmt list =
  List.fold_left
    (fun (ctx, stmts) stmt ->
      let ctx, stmt' = translate_mpp_stmt mpp_program m_program args ctx stmt in
      (ctx, stmts @ stmt'))
    (ctx, []) compute_decl.Mpp_ir.body

and translate_mpp_expr (p : Mir_interface.full_program) (ctx : translation_ctx)
    (expr : Mpp_ir.mpp_expr_kind Pos.marked) : Mir.expression =
  let pos = Pos.get_position expr in
  match Pos.unmark expr with
  | Mpp_ir.Constant i -> Mir.Literal (Float (float_of_int i))
  | Variable (Mbased (var, _)) -> Var var
  | Variable (Local l) -> (
      try Var (StringMap.find l ctx.new_variables)
      with Not_found ->
        Cli.error_print "Local Variable %s not found in ctx" l;
        assert false)
  | Unop (Minus, e) -> Mir.Unop (Mast.Minus, (translate_mpp_expr p ctx e, pos))
  | Binop (e1, ((And | Or) as b), e2) ->
      Mir.Binop
        ( (translate_to_binop b, pos),
          (translate_mpp_expr p ctx e1, pos),
          (translate_mpp_expr p ctx e2, pos) )
  | Binop (e1, b, e2) ->
      Mir.Comparison
        ( (translate_to_compop b, pos),
          (translate_mpp_expr p ctx e1, pos),
          (translate_mpp_expr p ctx e2, pos) )
  | Call (Present, [ l ]) ->
      Pos.unmark @@ Mir_typechecker.expand_functions_expr
      @@ ( Mir.FunctionCall
             (PresentFunc, [ (translate_mpp_expr p ctx (Mpp_ir.Variable l, pos), pos) ]),
           pos )
  | Call (Abs, [ l ]) ->
      Pos.unmark @@ Mir_typechecker.expand_functions_expr
      @@ ( Mir.FunctionCall (AbsFunc, [ (translate_mpp_expr p ctx (Mpp_ir.Variable l, pos), pos) ]),
           pos )
  | Call (Cast, [ l ]) ->
      Mir.Binop
        ( (Mast.Add, pos),
          (translate_mpp_expr p ctx (Mpp_ir.Variable l, pos), pos),
          (Mir.Literal (Float 0.), pos) )
  | Call (DepositDefinedVariables, []) -> Pos.unmark @@ cond_DepositDefinedVariables p pos
  | Call (TaxbenefitCeiledVariables, []) -> Pos.unmark @@ cond_TaxbenefitCeiledVariables p pos
  | Call (TaxbenefitDefinedVariables, []) -> Pos.unmark @@ cond_TaxbenefitDefinedVariables p pos
  | _ -> assert false

and translate_mpp_stmt (mpp_program : Mpp_ir.mpp_compute list)
    (m_program : Mir_interface.full_program) func_args (ctx : translation_ctx) stmt :
    translation_ctx * Bir.stmt list =
  let pos = Pos.get_position stmt in
  match Pos.unmark stmt with
  | Mpp_ir.Assign (Local l, expr) ->
      let ctx, new_l =
        match StringMap.find_opt l ctx.new_variables with
        | None ->
            let new_l =
              Mir.Variable.new_var
                ("mpp_" ^ l, pos)
                None ("", pos)
                (Mast_to_mir.dummy_exec_number pos)
                ~attributes:[] ~is_income:false ~is_table:None
            in
            let ctx = { ctx with new_variables = StringMap.add l new_l ctx.new_variables } in
            (ctx, new_l)
        | Some new_l -> (ctx, new_l)
      in
      ( ctx,
        [
          Pos.same_pos_as
            (Bir.SAssign
               ( new_l,
                 {
                   var_definition = SimpleVar (translate_mpp_expr m_program ctx expr, pos);
                   var_typ = None;
                   var_io = Regular;
                 } ))
            stmt;
        ] )
  | Mpp_ir.Assign (Mbased (var, _), expr) ->
      ( { ctx with variables_used_as_inputs = Mir.VariableDict.add var ctx.variables_used_as_inputs },
        [
          Pos.same_pos_as
            (Bir.SAssign
               ( var,
                 {
                   var_definition = SimpleVar (translate_mpp_expr m_program ctx expr, pos);
                   var_typ = None;
                   var_io = (snd (Mir.find_var_definition m_program.program var)).var_io;
                 } ))
            stmt;
        ] )
  | Mpp_ir.Conditional (e, t, f) ->
      let e' = translate_mpp_expr m_program ctx e in
      let ctx1, rt' = translate_mpp_stmts mpp_program m_program func_args ctx t in
      let ctx2, rf' = translate_mpp_stmts mpp_program m_program func_args ctx f in
      (ctx_join ctx1 ctx2, [ Pos.same_pos_as (Bir.SConditional (e', rt', rf')) stmt ])
  | Mpp_ir.Delete (Mbased (var, _)) ->
      ( ctx,
        [
          Pos.same_pos_as
            (Bir.SAssign
               ( var,
                 {
                   var_definition = SimpleVar (Mir.Literal Undefined, pos);
                   var_typ = None;
                   var_io = (snd (Mir.find_var_definition m_program.program var)).var_io;
                 } ))
            stmt;
        ] )
  | Mpp_ir.Delete (Local l) ->
      let var = StringMap.find l ctx.new_variables in
      ( ctx,
        [
          Pos.same_pos_as
            (Bir.SAssign
               ( var,
                 {
                   var_definition = SimpleVar (Mir.Literal Undefined, pos);
                   var_typ = None;
                   var_io = Regular;
                 } ))
            stmt;
        ] )
  | Mpp_ir.Expr (Call (MppFunction f, args), _) ->
      let real_args = match args with [ Mpp_ir.Local "outputs" ] -> func_args | _ -> args in
      translate_mpp_function mpp_program m_program
        (List.find (fun decl -> decl.Mpp_ir.name = f) mpp_program)
        real_args ctx
  | Mpp_ir.Expr (Call (Program, args), _) ->
      let real_args = match args with [ Mpp_ir.Local "outputs" ] -> func_args | _ -> args in
      let exec_order = m_program.main_execution_order in
      wrap_m_code_call m_program exec_order real_args ctx
  | Mpp_ir.Partition (filter, body) ->
      let func_of_filter = match filter with Mpp_ir.VarIsTaxBenefit -> var_is_ "avfisc" in
      let ctx, partition_pre, partition_post =
        generate_partition mpp_program m_program func_args func_of_filter pos ctx
      in
      let ctx, body = translate_mpp_stmts mpp_program m_program func_args ctx body in
      (ctx, partition_pre @ body @ partition_post)
  | _ -> assert false

and translate_mpp_stmts (mpp_program : Mpp_ir.mpp_compute list)
    (m_program : Mir_interface.full_program) (func_args : Mpp_ir.scoped_var list)
    (ctx : translation_ctx) (stmts : Mpp_ir.mpp_stmt list) : translation_ctx * Bir.stmt list =
  List.fold_left
    (fun (ctx, stmts) stmt ->
      let ctx, stmt = translate_mpp_stmt mpp_program m_program func_args ctx stmt in
      (ctx, stmts @ stmt))
    (ctx, []) stmts

and generate_partition mpp_program m_program func_args (filter : Mir.Variable.t -> bool)
    (pos : Pos.t) (ctx : translation_ctx) : translation_ctx * Bir.stmt list * Bir.stmt list =
  let vars_to_move =
    Mir.VariableDict.fold
      (fun var acc -> if filter var then var :: acc else acc)
      m_program.program.program_vars []
  in
  let mpp_pre, mpp_post =
    List.fold_left
      (fun (stmts_pre, stmts_post) var ->
        let shadow_var_name = "_" ^ Pos.unmark var.Mir.Variable.name in
        let open Mpp_ir in
        let shadow_var = Local shadow_var_name in
        let var = Mbased (var, Output) in
        ( (Assign (shadow_var, (Variable var, pos)), pos) :: (Delete var, pos) :: stmts_pre,
          (Assign (var, (Variable shadow_var, pos)), pos) :: (Delete shadow_var, pos) :: stmts_post
        ))
      ([], []) vars_to_move
  in
  let ctx, pre = translate_mpp_stmts mpp_program m_program func_args ctx mpp_pre in
  let ctx, post = translate_mpp_stmts mpp_program m_program func_args ctx mpp_post in
  (ctx, pre, post)

let generate_verif_conds (conds : Mir.condition_data Mir.VariableMap.t) : Bir.stmt list =
  Mir.VariableMap.fold
    (fun _var data acc -> (Bir.SVerif data, Pos.get_position data.cond_expr) :: acc)
    conds []

let create_combined_program (m_program : Mir_interface.full_program)
    (mpp_program : Mpp_ir.mpp_program) (mpp_function_to_extract : string) : Bir.program =
  try
    let mpp_program = List.rev mpp_program in
    let decl_to_extract =
      try List.find (fun decl -> decl.Mpp_ir.name = mpp_function_to_extract) mpp_program
      with Not_found ->
        Errors.raise_error
          (Format.asprintf "M++ function %s not found in M++ file!" mpp_function_to_extract)
    in
    let ctx, statements =
      translate_mpp_function mpp_program m_program decl_to_extract [] emtpy_translation_ctx
    in
    let conds_verif = generate_verif_conds m_program.program.program_conds in
    {
      rules = ctx.rule_instances;
      statements = statements @ conds_verif;
      (* we append the M verification conditions at the end, when everything has already been
         computed *)
      idmap = m_program.program.program_idmap;
      mir_program = m_program.program;
      outputs = Mir.VariableMap.empty;
    }
  with Bir_interpreter.RegularFloatInterpreter.RuntimeError (r, ctx) ->
    Bir_interpreter.RegularFloatInterpreter.raise_runtime_as_structured r ctx m_program.program
