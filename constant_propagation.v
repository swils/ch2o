(* Copyright (c) 2012-2014, Robbert Krebbers. *)
(* This file is distributed under the terms of the BSD license. *)
Require Export memory_refine.

Lemma mem_constant_prop `{EnvSpec Ti} Γ Γm m a v τ :
  ✓ Γ → ✓{Γ,Γm} m →
  (Γ,Γm) ⊢ a : τ → mem_writable Γ a m → (Γ,Γm) ⊢ v : τ → τ ≠ voidT%T →
  ∃ v', <[a:=v]{Γ}>m !!{Γ} a = Some v' ∧ v' ⊑{Γ,true@Γm} v : τ.
Proof.
  unfold insertE, lookupE, mem_insert, mem_lookup. intros ??? (w&?&Hw) ??.
  assert (ctree_Forall (λ xb, Some Writable ⊆ pbit_kind xb)
    (of_val Γ (tagged_perm <$> ctree_flatten w) v)).
  { erewrite ctree_flatten_of_val by (rewrite ?fmap_length;
      eauto using ctree_flatten_length, cmap_lookup_typed).
    generalize (val_flatten Γ v).
    induction Hw; intros [|??]; simpl; constructor; auto. }
  destruct (cmap_lookup_alter_refine Γ Γm
    (λ w, of_val Γ (tagged_perm <$> ctree_flatten w) v) m a w τ)
    as (w'&->&?); simpl; eauto using of_val_flatten_typed,
    cmap_lookup_typed, of_val_flatten_unshared.
  exists (to_val Γ w'); split.
  { by rewrite option_guard_True by eauto using pbits_kind_weaken,
      pbits_refine_kind_subseteq_inv, ctree_flatten_refine. }
  apply (val_refine_compose _ true true meminj_id meminj_id _ Γm _ _
    (val_map (freeze true) v) _ τ τ); auto using val_freeze_refine_l.
  erewrite <-(to_of_val _ _ (tagged_perm <$> ctree_flatten w)) by
    (rewrite ?fmap_length;
    eauto using ctree_flatten_length, cmap_lookup_typed).
  auto using to_val_refine.
Qed.
