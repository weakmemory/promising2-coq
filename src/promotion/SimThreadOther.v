Require Import Omega.
Require Import RelationClasses.

From sflib Require Import sflib.
From Paco Require Import paco.

From PromisingLib Require Import Axioms.
From PromisingLib Require Import Basic.
From PromisingLib Require Import DataStructure.
From PromisingLib Require Import DenseOrder.
From PromisingLib Require Import Loc.
From PromisingLib Require Import Language.

Require Import Event.
Require Import Time.
Require Import View.
Require Import Cell.
Require Import Memory.
Require Import TView.
Require Import Local.
Require Import Thread.
Require Import Configuration.

Require Import Syntax.
Require Import Semantics.

Require Import PromiseConsistent.

Require Import Promotion.
Require Import SimCommon.

Set Implicit Arguments.


Inductive opt_lang_step: forall (e:ProgramEvent.t) (st1 st2:State.t), Prop :=
| opt_lang_step_none
    st:
    opt_lang_step ProgramEvent.silent st st
| opt_lang_step_some
    e st1 st2
    (STEP: lang.(Language.step) e st1 st2):
    opt_lang_step e st1 st2
.

Inductive opt_promise_step: forall (e:ThreadEvent.t) (e1 e2:Thread.t lang), Prop :=
| opt_promise_step_none
    e1:
    opt_promise_step ThreadEvent.silent e1 e1
| opt_promise_step_some
    pf e e1 e2
    (STEP: Thread.promise_step pf e e1 e2):
    opt_promise_step e e1 e2
.

Inductive opt_program_step: forall (e:ThreadEvent.t) (e1 e2:Thread.t lang), Prop :=
| opt_program_step_none
    e1:
    opt_program_step ThreadEvent.silent e1 e1
| opt_program_step_some
    e e1 e2
    (STEP: Thread.program_step e e1 e2):
    opt_program_step e e1 e2
.


Inductive sim_thread_other (l: Loc.t) (e_src e_tgt: Thread.t lang): Prop :=
| sim_thread_other_intro
    (LOCFREE: loc_free_stmts l e_src.(Thread.state).(State.stmts))
    (STATE: e_src.(Thread.state) = e_tgt.(Thread.state))
    (LOCAL: sim_local l e_src.(Thread.local) e_tgt.(Thread.local))
    (SC: sim_timemap l e_src.(Thread.sc) e_tgt.(Thread.sc))
    (MEMORY: sim_memory l e_src.(Thread.memory) e_tgt.(Thread.memory))
    (PROMISES: forall to, Memory.get l to e_src.(Thread.local).(Local.promises) = None)
.
Hint Constructors sim_thread_other.


Lemma sim_thread_promise_step
      l e1_src
      pf e_tgt e1_tgt e2_tgt
      (SIM1: sim_thread_other l e1_src e1_tgt)
      (STEP_TGT: Thread.promise_step pf e_tgt e1_tgt e2_tgt):
  exists e_src e2_src,
    <<STEP_SRC: opt_promise_step e_src e1_src e2_src>> /\
    <<SIM2: sim_thread_other l e2_src e2_tgt>>.
Proof.
  inv STEP_TGT. inv LOCAL.
  destruct (Loc.eq_dec loc l).
  { subst. esplits; [econs 1|].
    destruct e1_src. inv SIM1. ss. econs; eauto; ss.
    - destruct local, lc1. ss.
      inv LOCAL. econs; eauto. ss.
      admit.
    - admit.
  }
Admitted.

Lemma sim_thread_step
      l e1_src
      pf e_tgt e1_tgt e2_tgt
      (SIM1: sim_thread_other l e1_src e1_tgt)
      (STEP_TGT: Thread.step pf e_tgt e1_tgt e2_tgt):
  exists e_src e2_src,
    <<STEP_SRC: Thread.opt_step e_src e1_src e2_src>> /\
    <<SIM2: sim_thread_other l e2_src e2_tgt>> /\
    <<EVENT: ThreadEvent.get_machine_event e_src = ThreadEvent.get_machine_event e_tgt>>.
Proof.
Admitted.
