Require Import Basics.
Require Import Bool.
Require Import List.

Require Import sflib.
Require Import paco.
Require Import respectful5.

Require Import Basic.
Require Import Event.
Require Import Language.
Require Import Time.
Require Import Memory.
Require Import Commit.
Require Import Thread.

Require Import Configuration.
Require Import Simulation.
Require Import Compatibility.
Require Import MemInv.
Require Import ReorderStep.

Require Import Syntax.
Require Import Semantics.

Set Implicit Arguments.


Inductive reorder_load r1 l1 o1: forall (i2:Instr.t), Prop :=
| reorder_load_load
    r2 l2 o2
    (ORD2: Ordering.le o2 Ordering.relaxed)
    (LOC: l1 <> l2)
    (REGS: RegSet.disjoint (Instr.regs_of (Instr.load r1 l1 o1))
                           (Instr.regs_of (Instr.load r2 l2 o2))):
    reorder_load r1 l1 o1 (Instr.load r2 l2 o2)
| reorder_load_store
    l2 v2 o2
    (ORD: Ordering.le Ordering.seqcst o1 -> Ordering.le Ordering.seqcst o2 -> False)
    (LOC: l1 <> l2)
    (REGS: RegSet.disjoint (Instr.regs_of (Instr.load r1 l1 o1))
                           (Instr.regs_of (Instr.store l2 v2 o2))):
    reorder_load r1 l1 o1 (Instr.store l2 v2 o2)
| reorder_load_update
    r2 l2 rmw2 or2 ow2
    (ORDR2: Ordering.le or2 Ordering.relaxed)
    (ORDW2: Ordering.le Ordering.seqcst o1 -> Ordering.le Ordering.seqcst ow2 -> False)
    (LOC: l1 <> l2)
    (REGS: RegSet.disjoint (Instr.regs_of (Instr.load r1 l1 o1))
                           (Instr.regs_of (Instr.update r2 l2 rmw2 or2 ow2))):
    reorder_load r1 l1 o1 (Instr.update r2 l2 rmw2 or2 ow2)
| reorder_load_fence
    or2 ow2
    (ORD1: Ordering.le Ordering.relaxed o1)
    (ORDR2: Ordering.le or2 Ordering.relaxed)
    (ORDW2: Ordering.le ow2 Ordering.acqrel)
    (RLX: Ordering.le Ordering.relaxed ow2 -> Ordering.le o1 Ordering.relaxed):
    reorder_load r1 l1 o1 (Instr.fence or2 ow2)
.

Inductive sim_load: forall (st_src:lang.(Language.state)) (lc_src:Local.t) (sc_k_src:TimeMap.t) (mem_k_src:Memory.t)
                      (st_tgt:lang.(Language.state)) (lc_tgt:Local.t) (sc_k_tgt:TimeMap.t) (mem_k_tgt:Memory.t), Prop :=
| sim_load_intro
    r1 l1 ts1 v1 released1 o1 i2
    rs lc1_src lc1_tgt lc2_src
    sc_k_src sc_k_tgt
    mem_k_src mem_k_tgt
    (REORDER: reorder_load r1 l1 o1 i2)
    (READ: Local.read_step lc1_src mem_k_src l1 ts1 v1 released1 o1 lc2_src)
    (LOCAL: sim_local lc2_src lc1_tgt):
    sim_load
      (State.mk rs [Stmt.instr i2; Stmt.instr (Instr.load r1 l1 o1)]) lc1_src sc_k_src mem_k_src
      (State.mk (RegFun.add r1 v1 rs) [Stmt.instr i2]) lc1_tgt sc_k_tgt mem_k_tgt
.

Lemma sim_load_step
      st1_src lc1_src sc_k_src mem_k_src
      st1_tgt lc1_tgt sc_k_tgt mem_k_tgt
      (SIM: sim_load st1_src lc1_src sc_k_src mem_k_src
                     st1_tgt lc1_tgt sc_k_tgt mem_k_tgt):
  forall sc1_src sc1_tgt mem1_src mem1_tgt
    (SC: TimeMap.le sc1_src sc1_tgt)
    (MEMORY: Memory.sim mem1_tgt mem1_src)
    (SC_FUTURE_SRC: TimeMap.le sc_k_src sc1_src)
    (SC_FUTURE_TGT: TimeMap.le sc_k_tgt sc1_tgt)
    (MEM_FUTURE_SRC: Memory.future mem_k_src mem1_src)
    (MEM_FUTURE_TGT: Memory.future mem_k_tgt mem1_tgt)
    (WF_SRC: Local.wf lc1_src mem1_src)
    (WF_TGT: Local.wf lc1_tgt mem1_tgt)
    (SC_SRC: Memory.closed_timemap sc1_src mem1_src)
    (SC_TGT: Memory.closed_timemap sc1_tgt mem1_tgt)
    (MEM_SRC: Memory.closed mem1_src)
    (MEM_TGT: Memory.closed mem1_tgt),
    _sim_thread_step lang lang ((sim_thread (sim_terminal eq)) \8/ sim_load)
                     st1_src lc1_src sc1_src mem1_src
                     st1_tgt lc1_tgt sc1_tgt mem1_tgt.
Proof.
  inv SIM. ii.
  exploit future_read_step; try apply READ; eauto. i. des.
  inv STEP_TGT; inv STEP0; try (inv STATE; inv INSTR; inv REORDER); ss.
  - (* promise *)
    exploit sim_local_promise; (try by etrans; eauto); eauto.
    { eapply Local.read_step_future; eauto. }
    i. des.
    exploit reorder_read_promise; try apply x0; try apply STEP_SRC; eauto. i. des.
    esplits; try apply SC; eauto.
    + econs. econs. eauto.
    + eauto.
    + right. econs; eauto. etrans; eauto.
  - (* load *)
    exploit sim_local_read; (try by etrans; eauto); eauto.
    { eapply Local.read_step_future; eauto. }
    i. des.
    exploit reorder_read_read; try apply STEP; try apply STEP_SRC; eauto. i. des.
    esplits.
    + econs 2; [|econs 1]. econs.
      * econs 2. econs 2; eauto. econs. econs.
      * eauto.
    + econs 2. econs 2; eauto. econs. econs.
    + eauto.
    + eauto.
    + eauto.
    + left. eapply paco9_mon; [apply sim_stmts_nil|]; ss.
      apply RegFun.add_add. ii. subst. eapply REGS.
      * apply RegSet.singleton_spec. eauto.
      * apply RegSet.singleton_spec. eauto.
      * etrans; eauto.
  - (* store *)
    exploit sim_local_write; try apply SC; try apply LOCAL1; (try by etrans; eauto); eauto.
    { refl. }
    { apply Capability.bot_wf. }
    { eapply Local.read_step_future; eauto. }
    i. des.
    exploit reorder_read_write; try apply STEP; try apply STEP_SRC; eauto. i. des.
    esplits.
    + econs 2; [|econs 1]. econs.
      * econs 2. econs 3; eauto. econs.
        erewrite RegFile.eq_except_value; eauto.
        { econs. }
        { apply RegFile.eq_except_singleton. }
      * eauto.
    + econs 2. econs 2; eauto. econs. econs.
    + eauto.
    + eauto.
    + eauto.
    + left. eapply paco9_mon; [apply sim_stmts_nil|]; ss. etrans; eauto.
  - (* update *)
    exploit sim_local_read; (try by etrans; eauto); eauto.
    { eapply Local.read_step_future; eauto. }
    i. des.
    exploit sim_local_write; try apply SC; try apply LOCAL1; (try by etrans; eauto); eauto.
    { admit. }
    { eapply Local.read_step_future; eauto.
      eapply Local.read_step_future; eauto.
    }
    { eapply Local.read_step_future; eauto. }
    i. des.
    exploit reorder_read_read; try apply STEP; try apply STEP_SRC; eauto. i. des.
    exploit reorder_read_write; try apply STEP2; try apply LOCAL2; eauto.
    { eapply Local.read_step_future; eauto. }
    i. des.
    esplits.
    + econs 2; [|econs 1]. econs.
      * econs 2. econs 4; eauto. econs. econs.
        erewrite <- RegFile.eq_except_rmw; eauto; try apply RegFile.eq_except_singleton.
        ii. eapply REGS; eauto.
        apply RegSet.singleton_spec in LHS. subst.
        apply RegSet.add_spec. auto.
      * eauto.
    + econs 2. econs 2; eauto. econs. econs.
    + eauto.
    + eauto.
    + left. eapply paco9_mon; [apply sim_stmts_nil|]; ss.
      apply RegFun.add_add. ii. subst. eapply REGS.
      * apply RegSet.singleton_spec. eauto.
      * apply RegSet.add_spec. eauto.
  - (* fence *)
    exploit sim_local_fence; eauto.
    { eapply Local.read_step_future; eauto. }
    i. des.
    exploit reorder_read_fence; try apply x0; try apply STEP_SRC; eauto. i. des.
    esplits.
    + econs 2; [|econs 1]. econs.
      * econs 2. econs 5; eauto. econs. econs.
      * eauto.
    + econs 2. econs 2; eauto. econs. econs.
    + eauto.
    + eauto.
    + left. eapply paco9_mon; [apply sim_stmts_nil|]; ss.
Qed.

Lemma sim_load_sim_thread:
  sim_load <6= (sim_thread (sim_terminal eq)).
Proof.
  pcofix CIH. i. pfold. ii. ss. splits; ss.
  - i. inv TERMINAL_TGT. inv PR; ss.
  - i. inv PR. eapply sim_local_future; try apply LOCAL; eauto.
    + eapply Local.read_step_future; eauto.
      eapply Local.future_read_step; eauto.
    + eapply Local.read_step_future; eauto.
      eapply Local.future_read_step; eauto.
      eapply Local.future_read_step; eauto.
  - i. esplits; eauto.
    inv PR. inv READ. inv LOCAL. ss.
    apply MemInv.sem_bot_inv in PROMISES. rewrite PROMISES. auto.
  - ii. exploit sim_load_step; eauto. i. des.
    + esplits; eauto.
      left. eapply paco9_mon; eauto. ss.
    + esplits; eauto.
Qed.
