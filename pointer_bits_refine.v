(* Copyright (c) 2012-2014, Robbert Krebbers. *)
(* This file is distributed under the terms of the BSD license. *)
Require Import fragmented.
Require Export pointer_bits pointers_refine.

Instance ptr_bit_refine `{Env Ti} :
    Refine Ti (env Ti) (ptr_bit Ti) := λ Γ α f Γm1 Γm2 pb1 pb2, ∃ τ,
  frag_item pb1 ⊑{Γ,α,f@Γm1↦Γm2} frag_item pb2 : τ ∧
  frag_index pb1 = frag_index pb2 ∧
  frozen (frag_item pb1) ∧
  frag_index pb1 < bit_size_of Γ (τ.*).

Section pointer_bits.
Context `{EnvSpec Ti}.
Implicit Types Γ : env Ti.
Implicit Types Γm : memenv Ti.
Implicit Types τ : type Ti.
Implicit Types p : ptr Ti.
Implicit Types pb : ptr_bit Ti.
Implicit Types pbs : list (ptr_bit Ti).

Lemma ptr_bit_refine_id Γ α Γm pb : ✓{Γ,Γm} pb → pb ⊑{Γ,α@Γm} pb.
Proof. intros (σ&?&?&?); exists σ; eauto using ptr_refine_id. Qed.
Lemma ptr_bit_refine_compose Γ α1 α2 f1 f2 Γm1 Γm2 Γm3 pb1 pb2 pb3 :
  ✓ Γ → pb1 ⊑{Γ,α1,f1@Γm1↦Γm2} pb2 → pb2 ⊑{Γ,α2,f2@Γm2↦Γm3} pb3 →
  pb1 ⊑{Γ,α1||α2,f2 ◎ f1@Γm1↦Γm3} pb3.
Proof.
  intros ? (τ1&?&?&?&?) (τ2&?&?&?&?); exists τ1.
  assert (τ1 = τ2) by (by erewrite <-(ptr_refine_type_of_r _ _ _ _ _ _ _ τ1),
    <-(ptr_refine_type_of_l _ _ _ _ _ _ _ τ2) by eauto); subst.
  eauto using ptr_refine_compose with congruence.
Qed.
Lemma ptr_bit_refine_weaken Γ Γ' α α' f f' Γm1 Γm2 Γm1' Γm2' pb1 pb2 :
  ✓ Γ → pb1 ⊑{Γ,α,f@Γm1↦Γm2} pb2 → Γ ⊆ Γ' → Γ ⊆ Γ' → Γm1' ⊑{Γ',α',f'} Γm2' →
  Γm1 ⇒ₘ Γm1' → meminj_extend f f' Γm1 Γm2 → pb1 ⊑{Γ',α',f'@Γm1'↦Γm2'} pb2.
Proof.
  intros ? (τ&?&?&?&?) ??. exists τ.
  erewrite <-bit_size_of_weaken by eauto using TBase_valid, TPtr_valid,
    ptr_refine_typed_l, ptr_typed_type_valid; eauto using ptr_refine_weaken.
Qed.
Lemma ptr_bit_refine_valid_l Γ α f Γm1 Γm2 pb1 pb2 :
  ✓ Γ → pb1 ⊑{Γ,α,f@Γm1↦Γm2} pb2 → ✓{Γ,Γm1} pb1.
Proof. intros ? (τ&?&?&?&?). exists τ; eauto using ptr_refine_typed_l. Qed.
Lemma ptr_bit_refine_valid_r Γ α Γm1 Γm2 f pb1 pb2 :
  ✓ Γ → pb1 ⊑{Γ,α,f@Γm1↦Γm2} pb2 → ✓{Γ,Γm2} pb2.
Proof.
  intros ? (τ&?&?&?&?); exists τ; erewrite <-ptr_refine_frozen by eauto;
    eauto using ptr_refine_typed_r with congruence.
Qed.
Lemma ptr_bits_refine_valid_l Γ α f Γm1 Γm2 pbs1 pbs2 :
  ✓ Γ → pbs1 ⊑{Γ,α,f@Γm1↦Γm2}* pbs2 → ✓{Γ,Γm1}* pbs1.
Proof. induction 2; eauto using ptr_bit_refine_valid_l. Qed.
Lemma ptr_bits_refine_valid_r Γ α f Γm1 Γm2 pbs1 pbs2 :
  ✓ Γ → pbs1 ⊑{Γ,α,f@Γm1↦Γm2}* pbs2 → ✓{Γ,Γm2}* pbs2.
Proof. induction 2; eauto using ptr_bit_refine_valid_r. Qed.
Lemma ptr_bit_refine_unique_l Γ f Γm1 Γm2 pb1 pb2 pb3 :
  pb1 ⊑{Γ,false,f@Γm1↦Γm2} pb3 → pb2 ⊑{Γ,false,f@Γm1↦Γm2} pb3 → pb1 = pb2.
Proof.
  destruct pb1, pb2; intros (τ1&?&?&?&?) (τ2&?&?&?&?);
    f_equal'; eauto using ptr_refine_unique_l with congruence.
Qed.
Lemma ptr_bits_refine_unique_l Γ f Γm1 Γm2 pbs1 pbs2 pbs3 :
  pbs1 ⊑{Γ,false,f@Γm1↦Γm2}* pbs3 → pbs2 ⊑{Γ,false,f@Γm1↦Γm2}* pbs3 →
  pbs1 = pbs2.
Proof.
  intros Hpbs. revert pbs2. induction Hpbs; inversion_clear 1;
    f_equal; eauto using ptr_bit_refine_unique_l.
Qed.
Lemma ptr_bit_refine_unique_r Γ α f Γm1 Γm2 pb1 pb2 pb3 :
  pb1 ⊑{Γ,α,f@Γm1↦Γm2} pb2 → pb1 ⊑{Γ,α,f@Γm1↦Γm2} pb3 → pb2 = pb3.
Proof.
  destruct pb2, pb3; intros (τ1&?&?&?&?) (τ2&?&?&?&?);
    f_equal'; eauto using ptr_refine_unique_r with congruence.
Qed.
Lemma ptr_bits_refine_unique_r Γ α f Γm1 Γm2 pbs1 pbs2 pbs3 :
  pbs1 ⊑{Γ,α,f@Γm1↦Γm2}* pbs2 → pbs1 ⊑{Γ,α,f@Γm1↦Γm2}* pbs3 → pbs2 = pbs3.
Proof.
  intros Hpbs. revert pbs3. induction Hpbs; inversion_clear 1;
    f_equal; eauto using ptr_bit_refine_unique_r.
Qed.
Lemma ptr_to_bits_refine Γ α f Γm1 Γm2 p1 p2 σ :
  p1 ⊑{Γ,α,f@Γm1↦Γm2} p2 : σ →
  ptr_to_bits Γ p1 ⊑{Γ,α,f@Γm1↦Γm2}* ptr_to_bits Γ p2.
Proof.
  intros. unfold ptr_to_bits, to_fragments.
  erewrite ptr_refine_type_of_l, ptr_refine_type_of_r by eauto.
  apply Forall2_fmap, Forall2_Forall, Forall_seq; intros j [??].
  exists σ; simpl; split_ands; unfold frozen; auto using ptr_freeze_freeze.
  by apply ptr_freeze_refine.
Qed.
Lemma ptr_of_bits_refine Γ α f Γm1 Γm2 σ pbs1 pbs2 p1 :
  ptr_of_bits Γ σ pbs1 = Some p1 → pbs1 ⊑{Γ,α,f@Γm1↦Γm2}* pbs2 →
  ∃ p2, ptr_of_bits Γ σ pbs2 = Some p2 ∧ p1 ⊑{Γ,α,f@Γm1↦Γm2} p2 : σ.
Proof.
  revert pbs1 pbs2 p1. assert (∀ p1 p2 pbs1 pbs2,
    p1 ⊑{Γ,α,f@Γm1↦Γm2} p2 : σ → frozen p1 → pbs1 ⊑{Γ,α,f@Γm1↦Γm2}* pbs2 →
    fragmented (bit_size_of Γ (σ.*)) p1 1 pbs1 →
    fragmented (bit_size_of Γ (σ.*)) p2 1 pbs2).
  { intros p1 p2 pbs1 pbs2 ??? ->.
    apply (ptr_bits_refine_unique_r Γ α f Γm1 Γm2
      (Fragment p1 <$> seq 1 (bit_size_of Γ (σ.*) - 1))); [done|].
    apply Forall2_fmap, Forall2_Forall, Forall_seq; intros j [??].
    exists σ; simpl; split_ands; auto with lia. }
  intros pbs1 pbs2 p1; unfold ptr_of_bits. destruct 2 as
    [|[p1' []] [p2' []] ?? (?&?&?&?&?)]; simplify_option_equality;
    repeat match goal with
    | H : context [type_of ?p] |- _ =>
      erewrite ?ptr_refine_type_of_l, ?ptr_refine_type_of_r in H by eauto
    end; try done.
  * erewrite ptr_refine_type_of_l by eauto; eauto.
  * exfalso; naive_solver.
Qed.
Lemma ptr_of_bits_refine_None Γ f Γm1 Γm2 σ pbs1 pbs2 :
  ptr_of_bits Γ σ pbs1 = None → pbs1 ⊑{Γ,false,f@Γm1↦Γm2}* pbs2 →
  ptr_of_bits Γ σ pbs2 = None.
Proof.
  revert pbs1 pbs2. assert (∀ p1 p2 pbs1 pbs2,
    p1 ⊑{Γ,false,f@Γm1↦Γm2} p2 : σ → frozen p1 →
    pbs1 ⊑{Γ,false,f@Γm1↦Γm2}* pbs2 →
    fragmented (bit_size_of Γ (σ.* )) p2 1 pbs2 →
    fragmented (bit_size_of Γ (σ.* )) p1 1 pbs1).
  { intros p1 p2 pbs1 pbs2 ??? ->. red.
    apply (ptr_bits_refine_unique_l Γ f Γm1 Γm2 _ _
      (Fragment p2 <$> seq 1 (bit_size_of Γ (σ.*) - 1))); [done|].
    apply Forall2_fmap, Forall2_Forall, Forall_seq; intros j [??].
    exists σ; simpl; split_ands; auto with lia. }
  intros pbs1 pbs2; unfold ptr_of_bits. destruct 2 as
    [|[p1' []] [p2' []] ?? (?&?&?&?&?)]; simplify_option_equality;
    repeat match goal with
    | H : context [type_of ?p] |- _ =>
      erewrite ?ptr_refine_type_of_l, ?ptr_refine_type_of_r in H by eauto
    end; naive_solver.
Qed.
End pointer_bits.
