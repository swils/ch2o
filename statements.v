(* Copyright (c) 2012-2014, Robbert Krebbers. *)
(* This file is distributed under the terms of the BSD license. *)
(** The small step reduction (as defined in the file [smallstep]) traverses
through the program in small steps by moving the focus on the substatement
that is being executed. Uses of non-local control ([goto] and [return]) are
performed in small steps rather than in big steps as well. *)

(** In order to model the concept of focusing on the substatement that is being
executed, this file defines program contexts as an extension of Huet's zipper
data structure. Program contexts extend the zipper data structure by annotating
each block scope variable with its associated memory index, and they furthermore
contain the full call stack of the program. Program contexts can also be seen
as a generalization of continuations (as for example being used in CompCert).
However, there are some notable differences.

- Program contexts implicitly contain the stack, whereas a continuation
  semantics typically stores the stack separately.
- Program contexts also contain the part of the program that has been
  executed, whereas continuations only contain the part that remains to be done.
- Since the complete program is preserved, looping constructs (e.g. while and
  for) do not have to duplicate code.

The fact that program contexts do not throw away the parts of the statement
that have been executed is essential for our treatment of goto. Upon an
invocation of a goto, the semantics traverses through the program context until
the corresponding label has been found. During this traversal it passes all
block scope variables that went out of scope, allowing it to perform required
allocations and deallocations in a natural way. Hence, the point of this
traversal is not so much to search for the label, but much more to incrementally
calculate the required allocations and deallocations. *)

(** In a continuation semantics, upon the use of a goto, one typically computes,
or looks up, the statement and continuation corresponding to the target label.
However, it is not very natural to reconstruct the required allocations and
deallocations from the current and target continuations. *)

Require Import nmap mapset.
Require Export expressions.

(** * Labels and gotos *)
(** We use the type [N] of binary natural numbers for labels, and the
implementation [Nmap] for efficient finite sets, and finite maps indexed by
labels. We define type classes [Gotos] and [Labels] to collect the labels of
gotos respectively the labels of labeled statements. *)
Definition label := N.
Definition labelmap := Nmap.
Notation labelset := (mapset labelmap).

Instance label_dec: ∀ i1 i2 : label, Decision (i1 = i2) := decide_rel (=).
Instance label_fresh_`{FinCollection label C} : Fresh label C := _.
Instance label_fresh_spec `{FinCollection label C} : FreshSpec label C := _.
Instance label_inhabited: Inhabited label := populate 0%N.

Instance labelmap_dec {A} `{∀ a1 a2 : A, Decision (a1 = a2)} :
  ∀ m1 m2 : labelmap A, Decision (m1 = m2) := decide_rel (=).
Instance labelmap_empty {A} : Empty (labelmap A) := @empty (Nmap A) _.
Instance labelmap_lookup {A} : Lookup label A (labelmap A) :=
  @lookup _ _ (Nmap A) _.
Instance labelmap_partial_alter {A} : PartialAlter label A (labelmap A) :=
  @partial_alter _ _ (Nmap A) _.
Instance labelmap_to_list {A} : FinMapToList label A (labelmap A) :=
  @map_to_list _ _ (Nmap A) _.
Instance labelmap_omap: OMap labelmap := λ A B f, @omap Nmap _ _ f _.
Instance labelmap_merge: Merge labelmap := @merge Nmap _.
Instance labelmap_fmap: FMap labelmap := λ A B f, @fmap Nmap _ _ f _.
Instance: FinMap label labelmap := _.

Instance labelmap_dom {A} : Dom (labelmap A) labelset := mapset_dom.
Instance: FinMapDom label labelmap labelset := mapset_dom_spec.

Typeclasses Opaque label labelmap.

Class Gotos A := gotos: A → labelset.
Arguments gotos {_ _} !_ / : simpl nomatch.
Class Labels A := labels: A → labelset.
Arguments labels {_ _} !_ / : simpl nomatch.

(** We lift instances of the above type classes to lists. *)
Instance list_gotos `{Gotos A} : Gotos (list A) :=
  fix go (l : list A) : labelset := let _ : Gotos _ := @go in
  match l with [] => ∅ | a :: l => gotos a ∪ gotos l end.
Instance list_labels `{Labels A} : Labels (list A) :=
  fix go (l : list A) : labelset := let _ : Labels _ := @go in
  match l with [] => ∅ | a :: l => labels a ∪ labels l end.

(** * Statements *)
(** The construct [SDo e] executes the expression [e] and ignores the result.
The construct [SBlock s] opens a new scope with one variable. Since we use De
Bruijn indexes for variables, it does not contain the name of the variable. *)
Inductive stmt (Ti : Set) :=
  | SDo : expr Ti → stmt Ti
  | SSkip : stmt Ti
  | SGoto : label → stmt Ti
  | SReturn : expr Ti → stmt Ti
  | SBlock : type Ti → stmt Ti → stmt Ti
  | SComp : stmt Ti → stmt Ti → stmt Ti
  | SLabel : label → stmt Ti → stmt Ti
  | SWhile : expr Ti → stmt Ti → stmt Ti
  | SIf : expr Ti → stmt Ti → stmt Ti → stmt Ti.
Notation funenv Ti := (funmap (stmt Ti)).

Instance stmt_eq_dec {Ti : Set} `{∀ k1 k2 : Ti, Decision (k1 = k2)}
  (s1 s2 : stmt Ti) : Decision (s1 = s2).
Proof. solve_decision. Defined.

(** We use the scope [stmt_scope] for notations of statements. *)
Delimit Scope stmt_scope with S.
Bind Scope stmt_scope with stmt.
Open Scope stmt_scope.

Arguments SDo {_} _.
Arguments SSkip {_}.
Arguments SGoto {_} _%N.
Arguments SReturn {_} _.
Arguments SBlock {_} _ _%S.
Arguments SComp {_}_%S _%S.
Arguments SLabel {_} _%N _%S.
Arguments SWhile {_}_ _%S.
Arguments SIf {_} _ _%S _%S.

Notation "'do' e" := (SDo e) (at level 10) : stmt_scope.
Notation "'skip'" := SSkip : stmt_scope.
Notation "'goto' l" := (SGoto l) (at level 10) : stmt_scope.
Notation "'ret' e" := (SReturn e) (at level 10) : stmt_scope.
Notation "'blk{' τ } s" := (SBlock τ s)
  (at level 10, format "'blk{' τ }  s") : stmt_scope.
Notation "s1 ;; s2" := (SComp s1 s2)
  (at level 80, right associativity,
   format "'[' s1  ;;  '/' s2 ']'") : stmt_scope.
Notation "l :; s" := (SLabel l s)
  (at level 81, format "l  :;  s") : stmt_scope.
Notation "'while' '(' e ')' s" := (SWhile e s)
  (at level 10, format "'while'  '(' e ')'  s") : stmt_scope.
Notation "'IF' e 'then' s1 'else' s2" := (SIf e s1 s2) : stmt_scope.

Instance: Injective (=) (=) (@SDo Ti).
Proof. by injection 1. Qed.
Instance: Injective (=) (=) (@SGoto Ti).
Proof. by injection 1. Qed.
Instance: Injective (=) (=) (@SReturn Ti).
Proof. by injection 1. Qed.
Instance: Injective2 (=) (=) (=) (@SBlock Ti).
Proof. by injection 1. Qed.

Instance stmt_gotos {Ti} : Gotos (stmt Ti) :=
  fix go s := let _ : Gotos _ := @go in
  match s with
  | goto l => {[ l ]}
  | blk{_} s => gotos s
  | s1 ;; s2 => gotos s1 ∪ gotos s2
  | _ :; s => gotos s
  | while (_) s => gotos s
  | (IF _ then s1 else s2) => gotos s1 ∪ gotos s2
  | _ => ∅
  end.
Instance stmt_labels {Ti} : Labels (stmt Ti) :=
  fix go s := let _ : Labels _ := @go in
  match s with
  | blk{_} s => labels s
  | s1 ;; s2 => labels s1 ∪ labels s2
  | l :; s => {[ l ]} ∪ labels s
  | while (_) s => labels s
  | (IF _ then s1 else s2) => labels s1 ∪ labels s2
  | _ => ∅
  end.
Instance stmt_locks {Ti} : Locks (stmt Ti) :=
  fix go s := let _ : Locks _ := @go in
  match s with
  | do e => locks e
  | skip => ∅
  | goto _ => ∅
  | ret e => locks e
  | blk{_} s => locks s
  | s1 ;; s2 => locks s1 ∪ locks s2
  | _ :; s => locks s
  | while (e) s => locks e ∪ locks s
  | (IF e then s1 else s2) => locks e ∪ locks s1 ∪ locks s2
  end.

(** * Program contexts *)
(** We first define the data type [sctx_item] of singular statement contexts. A
pair [(E, s)] consisting of a list of singular statement contexts [E] and a
statement [s] forms a zipper for statements without block scope variables. *)
Inductive sctx_item Ti : Type :=
  | CCompL : stmt Ti → sctx_item Ti
  | CCompR : stmt Ti → sctx_item Ti
  | CLabel : label → sctx_item Ti
  | CWhile : expr Ti → sctx_item Ti
  | CIfL : expr Ti → stmt Ti → sctx_item Ti
  | CIfR : expr Ti → stmt Ti → sctx_item Ti.

Instance sctx_item_eq_dec {Ti : Set} `{∀ k1 k2 : Ti, Decision (k1 = k2)}
  (E1 E2 : sctx_item Ti) : Decision (E1 = E2).
Proof. solve_decision. Defined.

Arguments CCompL {_} _.
Arguments CCompR {_} _.
Arguments CLabel {_} _%N.
Arguments CWhile {_} _.
Arguments CIfL {_} _ _.
Arguments CIfR {_} _ _.

Bind Scope stmt_scope with sctx_item.
Notation "□ ;; s" := (CCompL s) (at level 80, format "□  ;;  s") : stmt_scope.
Notation "s ;; □" := (CCompR s) (at level 80, format "s  ;;  □") : stmt_scope.
Notation "l :; □" := (CLabel l) (at level 81, format "l  :;  □") : stmt_scope.
Notation "'while' ( e ) □" := (CWhile e)
  (at level 10, format "'while'  '(' e ')'  □") : stmt_scope.
Notation "'IF' e 'then' □ 'else' s2" := (CIfL e s2)
  (at level 200, format "'IF'  e  'then'  □  'else'  s2") : stmt_scope.
Notation "'IF' e 'then' s1 'else' □" := (CIfR e s1)
  (at level 200, format "'IF'  e  'then'  s1  'else'  □") : stmt_scope.

Instance sctx_item_subst {Ti} : Subst (sctx_item Ti) (stmt Ti) (stmt Ti) := λ E s,
  match E with
  | □ ;; s2 => s ;; s2
  | s1 ;; □ => s1 ;; s
  | l :; □ => l :; s
  | while (e) □ => while (e) s
  | (IF e then □ else s2) => IF e then s else s2
  | (IF e then s1 else □) => IF e then s1 else s
  end.
Instance: DestructSubst (@sctx_item_subst Ti).

Instance: ∀ E : sctx_item Ti, Injective (=) (=) (subst E).
Proof. destruct E; repeat intro; simpl in *; by simplify_equality. Qed.

Instance sctx_item_gotos {Ti} : Gotos (sctx_item Ti) := λ E,
  match E with
  | s2 ;; □ => gotos s2
  | □ ;; s1 => gotos s1
  | l :; □ => ∅
  | while (_) □ => ∅
  | (IF _ then □ else s2) => gotos s2
  | (IF _ then s1 else □) => gotos s1
  end.
Instance sctx_item_labels {Ti} : Labels (sctx_item Ti) := λ E,
  match E with
  | s2 ;; □ => labels s2
  | □ ;; s1 => labels s1
  | l :; □ => {[ l ]}
  | while (_) □ => ∅
  | (IF _ then □ else s2) => labels s2
  | (IF _ then s1 else □) => labels s1
  end.

Lemma sctx_item_gotos_spec {Ti} (E : sctx_item Ti) (s : stmt Ti) :
  gotos (subst E s) = gotos E ∪ gotos s.
Proof. apply elem_of_equiv_L. intros. destruct E; solve_elem_of. Qed.
Lemma sctx_item_labels_spec {Ti} (E : sctx_item Ti) (s : stmt Ti) :
  labels (subst E s) = labels E ∪ labels s.
Proof. apply elem_of_equiv_L. intros. destruct E; solve_elem_of. Qed.

Instance sctx_item_locks {Ti} : Locks (sctx_item Ti) := λ E,
  match E with
  | □ ;; s2 => locks s2
  | s1 ;; □ => locks s1
  | l :; □ => ∅
  | while (e) □ => locks e
  | (IF e then □ else s2) => locks e ∪ locks s2
  | (IF e then s1 else □) => locks e ∪ locks s1
  end.

Lemma sctx_item_subst_locks {Ti} (E : sctx_item Ti) s :
  locks (subst E s) = locks E ∪ locks s.
Proof. apply elem_of_equiv_L. destruct E; esolve_elem_of. Qed.

(** Next, we define the data type [esctx_item] of expression in statement
contexts. These contexts are used to store the statement to which an expression
that is being executed belongs to. *)
Inductive esctx_item (Ti : Set) :=
  | CDoE : esctx_item Ti
  | CReturnE : esctx_item Ti
  | CWhileE : stmt Ti → esctx_item Ti
  | CIfE : stmt Ti → stmt Ti → esctx_item Ti.

Instance esctx_item_eq_dec {Ti : Set} `{∀ k1 k2 : Ti, Decision (k1 = k2)}
  (E1 E2 : esctx_item Ti) : Decision (E1 = E2).
Proof. solve_decision. Defined.

Arguments CDoE {_}.
Arguments CReturnE {_}.
Arguments CWhileE {_} _.
Arguments CIfE {_} _ _.
Notation "'do' □" := CDoE (at level 10, format "'do'  □") : stmt_scope.
Notation "'ret' □" := CReturnE (at level 10, format "'ret'  □") : stmt_scope.
Notation "'while' ( □ ) s" := (CWhileE s)
  (at level 10, format "'while'  '(' □ ')'  s") : stmt_scope.
Notation "'IF' □ 'then' s1 'else' s2" := (CIfE s1 s2)
  (at level 200, format "'IF'  □  'then'  s1  'else'  s2") : stmt_scope.

Instance esctx_item_subst {Ti} : Subst (esctx_item Ti) (expr Ti) (stmt Ti) := λ E e,
  match E with
  | do □ => do e
  | ret □ => ret e
  | while (□) s => while (e) s
  | (IF □ then s1 else s2) => IF e then s1 else s2
  end.
Instance: DestructSubst (@esctx_item_subst Ti).

Instance: ∀ E : esctx_item Ti, Injective (=) (=) (subst E).
Proof. destruct E; intros ???; simpl in *; by simplify_equality. Qed.

Instance esctx_item_locks {Ti} : Locks (esctx_item Ti) := λ E,
  match E with
  | do □  | ret □ => ∅
  | while (□) s => locks s
  | (IF □ then s1 else s2) => locks s1 ∪ locks s2
  end.

Lemma esctx_item_subst_locks {Ti} (E : esctx_item Ti) e :
  locks (subst E e) = locks E ∪ locks e.
Proof. apply elem_of_equiv_L. destruct E; esolve_elem_of. Qed.

(** Finally, we define the type [ctx_item] to extends [sctx_item] with some
additional singular contexts. These contexts will be used as follows.

- When entering a block, [block s], the context [CBlock b] is appended to the
  head of the program context. It associates the block scope variable with its
  corresponding memory index [b].
- To execute a statement [subst E e] containing an expression [e], the context
  [CExpr e E] is appended to the head of the program context. It stores the
  expression [e] itself and its location [E]. The expression itself is needed
  to restore the statement when execution of the expression is finished. The
  location is needed to determine what to do with the result of the expression.
- Upon a function call, [subst E (call f @ vs)], the context [CFun E] is
  appended to the head of the program context. It contains the location [E]
  of the caller so that it can be restored when the called function [f] returns.
- When a function body is entered, the context [CParams bs] is appended to the
  head of the program context. It contains a list of memory indexes of the
  function parameters.

Program contexts [ctx] are then defined as lists of singular contexts. *)
Inductive ctx_item (Ti : Set) :=
  | CStmt : sctx_item Ti → ctx_item Ti
  | CBlock : index → type Ti → ctx_item Ti
  | CExpr : expr Ti → esctx_item Ti → ctx_item Ti
  | CFun : ectx Ti → ctx_item Ti
  | CParams : list index → ctx_item Ti.
Notation ctx Ti := (list (ctx_item Ti)).

Arguments CStmt {_} _.
Arguments CBlock {_} _ _.
Arguments CExpr {_} _ _.
Arguments CFun {_} _.
Arguments CParams {_} _.

Instance ctx_item_eq_dec {Ti : Set} `{∀ k1 k2 : Ti, Decision (k1 = k2)}
  (E1 E2 : ctx_item Ti) : Decision (E1 = E2).
Proof. solve_decision. Defined.

Instance ctx_item_subst {Ti} : Subst (ctx_item Ti) (stmt Ti) (stmt Ti) := λ E s,
  match E with CStmt E => subst E s | CBlock _ τ => blk{τ} s | _ => s end.

Instance: ∀ E : ctx_item Ti, Injective (=) (=) (subst E).
Proof.
  destruct E; intros ???; auto.
  * eapply (injective (subst (CStmt _))); eauto.
  * eapply (injective (SBlock _)); eauto.
Qed.

Instance ctx_item_locks {Ti} : Locks (ctx_item Ti) := λ E,
  match E with
  | CStmt s => locks s
  | CBlock _ _ => ∅
  | CExpr e E => locks e ∪ locks E
  | CFun E => locks E
  | CParams _ => ∅
  end.

Inductive ctx_item_or_block {Ti} : ctx_item Ti → Prop :=
  | ctx_item_or_block_item E : ctx_item_or_block (CStmt E)
  | ctx_item_or_block_block o τ : ctx_item_or_block (CBlock o τ).

(** Given a context, we can construct a stack using the following erasure
function. We define [get_stack (CFun _ :: k)] as [[]] instead of [getstack k],
as otherwise it would be possible to refer to the local variables of the
calling function. *)
Fixpoint get_stack {Ti} (k : ctx Ti) : stack :=
  match k with
  | [] => []
  | CStmt _ :: k => get_stack k
  | CExpr _ _ :: k => get_stack k
  | CBlock o _ :: k => o :: get_stack k
  | CFun _ :: _ => []
  | CParams bs :: k => bs ++ get_stack k
  end.

Lemma get_stack_app {Ti} (k1 k2 k3 : ctx Ti) :
  get_stack k2 = get_stack k3 → get_stack (k1 ++ k2) = get_stack (k1 ++ k3).
Proof. induction k1 as [|[] ?]; intros; simpl; auto with f_equal. Qed.