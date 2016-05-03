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

Require Import Syntax.
Require Import Semantics.

Set Implicit Arguments.

Inductive sim_write (loc:Loc.t) (val:Const.t) (ord:Ordering.t) (th_src th_tgt:Local.t): Prop :=
| sim_write_intro
    commit2_src from to released
    (COMMIT1: Commit.write th_src.(Local.commit) loc to released ord commit2_src)
    (COMMIT2: Commit.le commit2_src th_tgt.(Local.commit))
    (LT: Time.lt from to)
    (PROMISE: MemInv.sem (Memory.singleton loc (Message.mk val released) LT) th_src.(Local.promise) th_tgt.(Local.promise))
.

Lemma sim_write_begin
      loc from to val released ord
      th1_src mem1_src
      th1_tgt mem1_tgt
      th2_tgt mem2_tgt
      (LOCAL1: sim_local th1_src th1_tgt)
      (MEMORY1: sim_memory mem1_src mem1_tgt)
      (WF1_SRC: Local.wf th1_src mem1_src)
      (WF1_TGT: Local.wf th1_tgt mem1_tgt)
      (STEP_TGT: Local.write_step th1_tgt mem1_tgt loc from to val released ord th2_tgt mem2_tgt):
  (<<LOCAL2: sim_write loc val ord th1_src th2_tgt>> /\
   <<MEMORY2: sim_memory mem1_src mem2_tgt>>) \/
  (exists th2_src mem2_src,
      <<STEP_SRC: Local.promise_step th1_src mem1_src th2_src mem2_src>> /\
      <<LOCAL2: sim_write loc val ord th2_src th2_tgt>> /\
      <<MEMORY2: sim_memory mem2_src mem2_tgt>>).
Proof.
  inv STEP_TGT. inv MEMORY.
  - left. splits; auto.
    inversion LOCAL1. apply MemInv.sem_bot_inv in PROMISE.
    destruct th1_src, th1_tgt. ss. subst.
    inv FULFILL.
    econs; s.
    + eapply CommitFacts.write_mon; eauto.
    + reflexivity.
    + econs. memtac.
  - right. inv ADD.
    exploit MemInv.promise; eauto.
    { apply WF1_SRC. }
    { apply WF1_TGT. }
    { apply LOCAL1. }
    i. des.
    apply MemInv.sem_bot_inv in INV2. subst.
    exploit Memory.promise_future; try apply PROMISE_SRC; eauto.
    { apply WF1_SRC. }
    { apply WF1_SRC. }
    i. des.
    eexists _, _. splits.
    + econs; try apply PROMISE_SRC; eauto.
      * reflexivity.
      * eapply Commit.future_wf; eauto. apply WF1_SRC.
    + inversion LOCAL1. apply MemInv.sem_bot_inv in PROMISE0.
      destruct th1_src, th1_tgt. ss. subst.
      inv FULFILL.
      econs; s.
      * eapply CommitFacts.write_mon; eauto.
      * reflexivity.
      * econs. memtac.
    + auto.
Qed.

Lemma sim_write_end
      loc val ord
      th1_src mem1_src
      th1_tgt mem1_tgt
      (ORD: Ordering.le ord Ordering.relaxed)
      (LOCAL1: sim_write loc val ord th1_src th1_tgt)
      (MEMORY1: sim_memory mem1_src mem1_tgt)
      (WF1_SRC: Local.wf th1_src mem1_src)
      (WF1_TGT: Local.wf th1_tgt mem1_tgt):
  exists from to released th2_src mem2_src,
    <<STEP_SRC: Local.write_step th1_src mem1_src loc from to val released ord th2_src mem2_src>> /\
    <<LOCAL2: sim_local th2_src th1_tgt>> /\
    <<MEMORY2: sim_memory mem2_src mem1_tgt>>.
Proof.
  destruct (Ordering.le Ordering.release ord) eqn:ORD2.
  { destruct ord; ss. }
  inv LOCAL1. inversion COMMIT1.
  exploit Memory.le_get.
  { apply WF1_SRC. }
  { inv PROMISE. eapply Memory.le_get.
    - apply Memory.le_join_r. memtac.
    - apply Memory.singleton_get.
  }
  intro GET_SRC.
  exploit CommitFacts.write_min_spec; eauto.
  { etransitivity; [apply MONOTONE|apply RELEASED]. }
  { instantiate (1 := ord). destruct ord; ss. }
  { apply WF1_SRC. }
  { apply WF1_SRC. }
  { inv WF1_SRC. inv MEMORY. exploit WF; eauto. }
  i. des.
  eexists _, _, _, _, _. splits; eauto.
  - econs; eauto. econs 1.
    + inv PROMISE. econs; eauto.
    + destruct ord; ss.
  - econs; s.
    + etransitivity; eauto.
      eapply CommitFacts.write_min_min. eauto.
    + apply MemInv.sem_bot.
Qed.

Lemma sim_write_promise
      loc val ord
      th1_src mem1_src
      th1_tgt mem1_tgt
      th2_tgt mem2_tgt
      (ORD: Ordering.le ord Ordering.relaxed)
      (LOCAL1: sim_write loc val ord th1_src th1_tgt)
      (MEMORY1: sim_memory mem1_src mem1_tgt)
      (WF1_SRC: Local.wf th1_src mem1_src)
      (WF1_TGT: Local.wf th1_tgt mem1_tgt)
      (STEP_TGT: Local.promise_step th1_tgt mem1_tgt th2_tgt mem2_tgt):
  exists th2_src mem2_src,
    <<STEP_SRC: Local.promise_step th1_src mem1_src th2_src mem2_src>> /\
    <<LOCAL2: sim_write loc val ord th2_src th2_tgt>> /\
    <<MEMORY2: sim_memory mem2_src mem2_tgt>>.
Proof.
  inv LOCAL1. inv STEP_TGT.
  exploit MemInv.promise; eauto.
  { apply WF1_SRC. }
  { apply WF1_TGT. }
  i. des.
  exploit Memory.promise_future; try apply PROMISE_SRC; eauto.
  { apply WF1_SRC. }
  { apply WF1_SRC. }
  i. des.
  eexists _, _. splits; eauto.
  - econs; eauto.
    + reflexivity.
    + eapply Commit.future_wf; eauto. apply WF1_SRC.
  - econs; s; eauto. etransitivity; eauto.
Qed.

Lemma sim_write_read
      loc1 val1 ord1
      loc2 ts2 val2 released2 ord2
      th1_src mem1_src
      th1_tgt mem1_tgt
      th2_tgt
      (LOC: loc1 <> loc2)
      (ORD1: Ordering.le ord1 Ordering.relaxed)
      (ORD2: Ordering.le ord2 Ordering.release)
      (LOCAL1: sim_write loc1 val1 ord1 th1_src th1_tgt)
      (MEMORY1: sim_memory mem1_src mem1_tgt)
      (WF1_SRC: Local.wf th1_src mem1_src)
      (WF1_TGT: Local.wf th1_tgt mem1_tgt)
      (STEP_TGT: Local.read_step th1_tgt mem1_tgt loc2 ts2 val2 released2 ord2 th2_tgt):
  exists th2_src,
    <<STEP_SRC: Local.read_step th1_src mem1_src loc2 ts2 val2 released2 ord2 th2_src>> /\
    <<LOCAL2: sim_write loc1 val1 ord1 th2_src th2_tgt>>.
Proof.
  inv LOCAL1. inv STEP_TGT.
  exploit Memory.le_get.
  { apply WF1_SRC. }
  { inv PROMISE. eapply Memory.le_get.
    - apply Memory.le_join_r. memtac.
    - apply Memory.singleton_get.
  }
  intro GET1_SRC.
  exploit Memory.splits_get; try apply GET; eauto.
  { apply MEMORY1. }
  intro GET2_SRC.
  exploit CommitFacts.read_min_spec; try apply GET2_SRC; eauto.
  { inv COMMIT. eapply Snapshot.readable_mon; eauto.
    etransitivity; [|apply COMMIT2]. apply COMMIT1.
  }
  { apply WF1_SRC. }
  { apply WF1_SRC. }
  i. des.
  destruct (Ordering.le Ordering.release ord1) eqn:ORD1'.
  { destruct ord1; ss. }
  assert (RELEASED_SRC: Memory.wf_snapshot released mem1_src).
  { inv WF1_SRC. inv MEMORY. exploit WF0; try apply GET1_SRC; eauto. }
  exploit CommitFacts.write_min_spec; try apply RELEASED_SRC; eauto.
  { eapply Snapshot.le_on_writable; eauto. apply COMMIT1. }
  { ss. inv COMMIT1. etransitivity; eauto. apply MONOTONE. }
  { instantiate (1 := ord1). destruct ord1; ss. }
  { apply WF1_SRC. }
  i. des.
  eexists _. splits; eauto.
  - econs; eauto. inv PROMISE.
    match goal with
    | [|- ?x = None] => destruct x eqn:X; auto
    end.
    apply Memory.join_get in X; memtac; try congruence.
    apply Memory.singleton_get_inv in X. des. congruence.
  - econs; eauto. s.
    exploit CommitFacts.write_min_min; try apply COMMIT1; eauto. i.
    exploit CommitFacts.read_min_min; try apply COMMIT; eauto. i.
    unfold CommitFacts.read_min in *.
    destruct (Ordering.le Ordering.acquire ord2) eqn:ORD2'.
    { destruct ord2; ss. }
    inv x0. inv x1.
    apply Snapshot.incr_writes_inv in CURRENT1.
    apply Snapshot.incr_reads_inv in CURRENT2. des.
    econs; ss.
    + apply Snapshot.incr_writes_spec.
      * apply Snapshot.incr_reads_spec; ss.
        etransitivity; [apply COMMIT1|].
        etransitivity; [apply COMMIT2|].
        apply COMMIT.
      * etransitivity; [apply COMMIT1|].
        etransitivity; [apply COMMIT2|].
        apply COMMIT.
    + i. unfold LocFun.add, LocFun.find.
      destruct (Loc.eq_dec loc loc1).
      * subst. rewrite ORD1'.
        etransitivity; [apply COMMIT1|].
        etransitivity; [apply COMMIT2|].
        apply COMMIT.
      * etransitivity; [apply COMMIT1|].
        etransitivity; [apply COMMIT2|].
        apply COMMIT.
    + etransitivity; eauto.
      apply Snapshot.join_spec.
      * apply Snapshot.join_l.
      * etransitivity; [|apply Snapshot.join_r].
        etransitivity; [apply COMMIT1|].
        apply COMMIT2.
Qed.

Lemma sim_write_write
      loc1 val1 ord1
      loc2 from2 to2 val2 released2 ord2
      th1_src mem1_src
      th1_tgt mem1_tgt
      th2_tgt mem2_tgt
      (LOC: loc1 <> loc2)
      (ORD1: Ordering.le ord1 Ordering.relaxed)
      (LOCAL1: sim_write loc1 val1 ord1 th1_src th1_tgt)
      (MEMORY1: sim_memory mem1_src mem1_tgt)
      (WF1_SRC: Local.wf th1_src mem1_src)
      (WF1_TGT: Local.wf th1_tgt mem1_tgt)
      (STEP_TGT: Local.write_step th1_tgt mem1_tgt loc2 from2 to2 val2 released2 ord2 th2_tgt mem2_tgt):
  exists th2_src mem2_src,
    <<STEP_SRC: Local.write_step th1_src mem1_src loc2 from2 to2 val2 released2 ord2 th2_src mem2_src>> /\
    <<LOCAL2: sim_write loc1 val1 ord1 th2_src th2_tgt>> /\
    <<MEMORY2: sim_memory mem2_src mem2_tgt>>.
Proof.
  destruct (Ordering.le Ordering.release ord1) eqn:ORD1'.
  { destruct ord1; ss. }
  inv LOCAL1. inv STEP_TGT.
  exploit MemInv.write; eauto.
  { apply WF1_SRC. }
  { apply WF1_TGT. }
  { inv PROMISE. unfold Memory.join.
    unfold Memory.singleton, LocFun.add, LocFun.find.
    destruct (Loc.eq_dec loc2 loc1); [congruence|].
    unfold LocFun.init. rewrite Cell.bot_join. auto.
  }
  i. des.
  exploit Memory.write_future; try apply WRITE_SRC; eauto.
  { apply WF1_SRC. }
  { apply WF1_SRC. }
  i. des.
  exploit Memory.write_get; try apply WRITE_SRC; eauto.
  { apply WF1_SRC. }
  intro GET2_SRC.
  exploit CommitFacts.write_min_spec; eauto.
  { eapply Snapshot.writable_mon; [|apply COMMIT].
    etransitivity; [|apply COMMIT2]. apply COMMIT1.
  }
  { etransitivity; [apply COMMIT1|].
    etransitivity; [apply COMMIT2|].
    etransitivity; [apply COMMIT|]. apply COMMIT.
  }
  { instantiate (1 := ord2). inv COMMIT. i.
    rewrite <- RELEASED, <- RELEASE; auto.
    apply Snapshot.incr_writes_spec; auto.
    etransitivity; [apply COMMIT1|].
    etransitivity; [apply COMMIT2|].
    apply MONOTONE.
  }
  { eapply Commit.future_wf; eauto. apply WF1_SRC. }
  { inv WF2. exploit WF; eauto. }
  i. des.
  exploit Memory.le_get.
  { apply WF1_SRC. }
  { inv PROMISE. eapply Memory.le_get.
    - apply Memory.le_join_r. memtac.
    - apply Memory.singleton_get.
  }
  intro GET1_SRC.
  exploit Memory.future_get; try apply GET1_SRC; eauto.
  intro GET1_SRC'.
  exploit CommitFacts.write_min_spec; try apply GET1_SRC'; eauto.
  { eapply Snapshot.le_on_writable; eauto. apply COMMIT1. }
  { inv COMMIT1. rewrite <- RELEASED, RELEASED1; auto.
    apply MONOTONE.
  }
  { instantiate (1 := ord1). destruct ord1; ss. }
  { inv WF2. exploit WF0; eauto. }
  i. des.
  eexists _, _. splits; eauto.
  - econs; eauto.
  - econs; eauto. s.
    exploit CommitFacts.write_min_min; try apply COMMIT1; eauto. i.
    exploit CommitFacts.write_min_min; try apply COMMIT; eauto. i.
    inv x0. inv x1.
    apply Snapshot.incr_writes_inv in CURRENT1.
    apply Snapshot.incr_writes_inv in CURRENT2. des.
    econs; ss.
    + repeat apply Snapshot.incr_writes_spec; ss.
      * etransitivity; [apply COMMIT1|].
        etransitivity; [apply COMMIT2|].
        apply COMMIT.
      * etransitivity; [apply COMMIT1|].
        etransitivity; [apply COMMIT2|].
        apply COMMIT.
    + i. unfold LocFun.add, LocFun.find. rewrite ORD1'.
      etransitivity; [|apply RELEASED2].
      unfold LocFun.add, LocFun.find.
      destruct (Loc.eq_dec loc loc1).
      * subst. destruct (Loc.eq_dec loc1 loc2); [congruence|].
        etransitivity; [apply COMMIT1|]. apply COMMIT2.
      * destruct (Loc.eq_dec loc loc2).
        { subst.
          match goal with
          | [|- context[if ?c then _ else _]] => destruct c
          end.
          - apply Snapshot.join_spec.
            + etransitivity; [|apply Snapshot.join_l].
              apply Snapshot.incr_writes_mon.
              etransitivity; [apply COMMIT1|]. apply COMMIT2.
            + etransitivity; [|apply Snapshot.join_r].
              etransitivity; [apply COMMIT1|]. apply COMMIT2.
          - etransitivity; [apply COMMIT1|]. apply COMMIT2.
        }
        { etransitivity; [apply COMMIT1|]. apply COMMIT2. }
    + etransitivity; [apply COMMIT1|].
      etransitivity; [apply COMMIT2|]. eauto.
Qed.

Inductive reorder l2 v2 o2: forall (i1:Instr.t), Prop :=
| reorder_load
    r1 l1 o1
    (ORD1: Ordering.le o1 Ordering.relaxed)
    (ORD2: Ordering.le o2 Ordering.relaxed)
    (LOC: l2 <> l1)
    (DISJOINT: RegSet.disjoint (Instr.regs_of (Instr.load r1 l1 o1))
                               (Instr.regs_of (Instr.store l2 v2 o2))):
    reorder l2 v2 o2 (Instr.load r1 l1 o1)
| reorder_store
    l1 v1 o1
    (ORD2: Ordering.le o2 Ordering.relaxed)
    (LOC: l2 <> l1)
    (DISJOINT: RegSet.disjoint (Instr.regs_of (Instr.store l1 v1 o1))
                               (Instr.regs_of (Instr.store l2 v2 o2))):
    reorder l2 v2 o2 (Instr.store l1 v1 o1)
| reorder_update
    r1 l1 rmw1 o1
    (ORD1: Ordering.le o1 Ordering.release)
    (ORD2: Ordering.le o2 Ordering.relaxed)
    (LOC: l2 <> l1)
    (DISJOINT: RegSet.disjoint (Instr.regs_of (Instr.update r1 l1 rmw1 o1))
                               (Instr.regs_of (Instr.store l2 v2 o2))):
    reorder l2 v2 o2 (Instr.update r1 l1 rmw1 o1)
.

Inductive sim: forall (st_src:lang.(Language.state)) (th_src:Local.t) (mem_k_src:Memory.t)
                 (st_tgt:lang.(Language.state)) (th_tgt:Local.t) (mem_k_tgt:Memory.t), Prop :=
| sim_begin
    i1 l2 v2 o2
    rs th_src th_tgt
    mem_k_src mem_k_tgt
    (REORDER: reorder l2 v2 o2 i1)
    (LOCAL: sim_local th_src th_tgt):
    sim
      (State.mk rs [Stmt.instr Instr.skip; Stmt.instr i1; Stmt.instr (Instr.store l2 v2 o2)]) th_src mem_k_src
      (State.mk rs [Stmt.instr (Instr.store l2 v2 o2); Stmt.instr i1]) th_tgt mem_k_tgt
| sim_end
    rs th_src th_tgt
    mem_k_src mem_k_tgt
    (LOCAL: sim_local th_src th_tgt):
    sim
      (State.mk rs []) th_src mem_k_src
      (State.mk rs []) th_tgt mem_k_tgt
| sim_intermediate
    i1 l2 v2 o2
    rs th_src th_tgt
    mem_k_src mem_k_tgt
    (REORDER: reorder l2 v2 o2 i1)
    (LOCAL: sim_write l2 (RegFile.eval_value rs v2) o2 th_src th_tgt):
    sim
      (State.mk rs [Stmt.instr i1; Stmt.instr (Instr.store l2 v2 o2)]) th_src mem_k_src
      (State.mk rs [Stmt.instr i1]) th_tgt mem_k_tgt
.

Lemma Memory_write_bot
      mem1 loc from to msg ord promise2 mem2
      (WRITE: Memory.write Memory.bot mem1 loc from to msg ord promise2 mem2):
  promise2 = Memory.bot.
Proof.
Admitted.

Lemma sim_reorder_sim_stmts:
  sim <6= (sim_thread (sim_terminal eq)).
Proof.
  pcofix CIH. i. pfold. ii. ss. splits; ss.
  - i. inv TERMINAL_TGT. inv PR; ss.
    eexists _, _, _. splits; eauto. econs; ss.
  - admit.
    (* future; https://github.com/jeehoonkang/memory-model-explorer/blob/86c803103989f87a17f50e6349aa9f285104af09/formalization/src/opt/Reorder.v#L100 *)
  - i. inv PR.
    + inv LOCAL. apply MemInv.sem_bot_inv in PROMISE.
      eexists _, _, _. splits; eauto. etransitivity; eauto.
    + inv LOCAL. apply MemInv.sem_bot_inv in PROMISE.
      eexists _, _, _. splits; eauto. etransitivity; eauto.
    + inv REORDER.
      * assert (STEP: exists ts val released th2_tgt, Local.read_step x4 mem1_tgt l1 ts val released o1 th2_tgt).
        { admit.
          (* https://github.com/jeehoonkang/memory-model-explorer/blob/86c803103989f87a17f50e6349aa9f285104af09/formalization/src/opt/Reorder.v#L116 *)
        }
        des.
        exploit sim_write_read; eauto.
        { destruct o1; ss. }
        i. des.
        exploit sim_write_end; eauto.
        { eapply Local.read_step_future; eauto. }
        { eapply Local.read_step_future; eauto. }
        i. des.
        eexists _, _, _. splits.
        { econs 2; [|econs 2; [|econs 1]].
          - econs 3; eauto. econs. econs.
          - econs 4; s; eauto.
            econs. erewrite <- RegFile.eq_except_value; eauto.
            + econs.
            + apply RegFile.eq_except_singleton.
        }
        inv LOCAL0. apply MemInv.sem_bot_inv in PROMISE.
        etransitivity; eauto.
        inv STEP. ss.
      * assert (STEP: exists from to released th2_tgt mem2_tgt,
                   Local.write_step x4 mem1_tgt l1 from to (RegFile.eval_value rs v1) released o1 th2_tgt mem2_tgt).
        { admit. }
        des.
        exploit sim_write_write; eauto. i. des.
        exploit sim_write_end; eauto.
        { eapply Local.write_step_future; eauto. }
        { eapply Local.write_step_future; eauto. }
        i. des.
        eexists _, _, _. splits.
        { econs 2; [|econs 2; [|econs 1]].
          - econs 4; eauto. econs. econs.
          - econs 4; eauto. econs. econs.
        }
        inv LOCAL0. apply MemInv.sem_bot_inv in PROMISE.
        etransitivity; eauto.
        inv STEP. ss.
        rewrite PROMISE_TGT in *. eapply Memory_write_bot. eauto.
      * admit. (* update *)
  - i. inv PR; ss.
    + (* begin *)
      inv STEP_TGT; inv STEP; try (inv STATE; inv INSTR); ss.
      * (* promise *)
        exploit sim_local_promise; eauto. i. des.
        eexists _, _, _, _, _, _. splits; eauto.
        { econs. econs 1. eauto. }
        right. apply CIH. econs 1; ss.
      * (* store *)
        exploit sim_write_begin; eauto. i. des.
        { eexists _, _, _, _, _, _. splits; try apply MEMORY2; eauto.
          { econs. econs 6; ss.
            - econs. econs.
            - apply Local.fence_relaxed. ss.
          }
          right. apply CIH. econs 3; eauto.
        }
        { eexists _, _, _, _, _, _. splits; try apply MEMORY2.
          { econs 2; [|econs 1].
            econs 6; ss.
            - econs. econs.
            - apply Local.fence_relaxed. ss.
          }
          { econs. s. econs 1. eauto. }
          right. apply CIH. econs 3; eauto.
        }
    + (* end *)
      inv STEP_TGT; inv STEP; try (inv STATE; inv INSTR); ss.
      exploit sim_local_promise; eauto. i. des.
      eexists _, _, _, _, _, _. splits; eauto.
      { econs. econs 1. eauto. }
      right. apply CIH. econs 2; ss.
    + (* intermediate *)
      inv STEP_TGT; inv STEP; try (inv STATE; inv INSTR; inversion REORDER); subst; ss.
      * (* promise *)
        exploit sim_write_promise; eauto.
        { inv REORDER; ss. }
        i. des.
        eexists _, _, _, _, _, _. splits; eauto.
        { econs. econs 1. eauto. }
        right. apply CIH. econs 3; ss.
      * (* read *)
        exploit sim_write_read; eauto.
        { destruct ord; ss. }
        i. des.
        exploit sim_write_end; eauto.
        { eapply Local.read_step_future; eauto. }
        { eapply Local.read_step_future; eauto. }
        i. des.
        eexists _, _, _, _, _, _. splits.
        { econs 2; [|econs 1].
          econs 3; eauto. econs. econs.
        }
        { econs. econs 4; eauto. econs.
          erewrite <- RegFile.eq_except_value; eauto.
          - econs.
          - apply RegFile.eq_except_singleton.
        }
        { eauto. }
        right. apply CIH. econs 2; eauto.
      * (* write *)
        exploit sim_write_write; eauto. i. des.
        exploit sim_write_end; eauto.
        { eapply Local.write_step_future; eauto. }
        { eapply Local.write_step_future; eauto. }
        i. des.
        eexists _, _, _, _, _, _. splits.
        { econs 2; [|econs 1].
          econs 4; eauto. econs. econs.
        }
        { econs. econs 4; eauto. econs. econs. }
        { eauto. }
        right. apply CIH. econs 2; eauto.
      * (* update *)
        exploit sim_write_read; eauto. i. des.
        exploit sim_write_write; eauto.
        { eapply Local.read_step_future; eauto. }
        { eapply Local.read_step_future; eauto. }
        i. des.
        exploit sim_write_end; eauto.
        { eapply Local.write_step_future; eauto.
          eapply Local.read_step_future; eauto.
        }
        { eapply Local.write_step_future; eauto.
          eapply Local.read_step_future; eauto.
        }
        i. des.
        eexists _, _, _, _, _, _. splits.
        { econs 2; [|econs 1].
          econs 5; eauto. econs. econs. eauto.
        }
        { econs. econs 4; eauto. econs.
          erewrite <- RegFile.eq_except_value; eauto.
          - econs.
          - admit. (* regfile disjoint *)
        }
        { eauto. }
        right. apply CIH. econs 2; eauto.
Admitted.

Lemma reorder_sim_stmts
      i1 l2 v2 o2 (REORDER: reorder l2 v2 o2 i1):
  sim_stmts eq
            [Stmt.instr Instr.skip; Stmt.instr i1; Stmt.instr (Instr.store l2 v2 o2)]
            [Stmt.instr (Instr.store l2 v2 o2); Stmt.instr i1]
            eq.
Proof.
  ii. subst.
  eapply sim_reorder_sim_stmts; eauto. econs 1; auto.
Qed.
