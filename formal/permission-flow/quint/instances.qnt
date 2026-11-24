// -*- mode: Bluespec; -*-
// gen-instances.sh が生成したファイル。直接編集しない。

module cur_U {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = true, ENV_MSGS_WHILE_PENDING = true, ENV_BG = true,
    ENV_ABORT = true, ENV_NATURAL_END = true, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = true,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = true
  ).* from "./permflow"
}

module cur_U_s {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = true, ENV_MSGS_WHILE_PENDING = true, ENV_BG = true,
    ENV_ABORT = true, ENV_NATURAL_END = true, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = true,
    IDS = Set("a", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_U_3 {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = true, ENV_MSGS_WHILE_PENDING = true, ENV_BG = true,
    ENV_ABORT = true, ENV_NATURAL_END = true, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = true,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_min {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = true
  ).* from "./permflow"
}

module cur_min_s {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_min_3 {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_abort {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = true, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = true
  ).* from "./permflow"
}

module cur_abort_s {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = true, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_abort_3 {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = true, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_bg {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = true,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = true
  ).* from "./permflow"
}

module cur_bg_s {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = true,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_bg_3 {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = true,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_msgs {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = true, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = true
  ).* from "./permflow"
}

module cur_msgs_s {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = true, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_msgs_3 {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = true, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_bgmsgs {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = true, ENV_BG = true,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = true
  ).* from "./permflow"
}

module cur_bgmsgs_s {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = true, ENV_BG = true,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_bgmsgs_3 {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = true, ENV_BG = true,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_end {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = true, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = true
  ).* from "./permflow"
}

module cur_end_s {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = true, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_end_3 {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = true, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_reent {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = true
  ).* from "./permflow"
}

module cur_reent_s {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_reent_3 {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_reab {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = true, ENV_NATURAL_END = false, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = true
  ).* from "./permflow"
}

module cur_reab_s {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = true, ENV_NATURAL_END = false, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_reab_3 {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = true, ENV_NATURAL_END = false, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_dead {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = true,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = true
  ).* from "./permflow"
}

module cur_dead_s {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = true,
    IDS = Set("a", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_dead_3 {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = true,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_bgend {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = true,
    ENV_ABORT = false, ENV_NATURAL_END = true, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = true
  ).* from "./permflow"
}

module cur_bgend_s {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = true,
    ENV_ABORT = false, ENV_NATURAL_END = true, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_bgend_3 {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = true,
    ENV_ABORT = false, ENV_NATURAL_END = true, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_plaus {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = true, ENV_BG = true,
    ENV_ABORT = true, ENV_NATURAL_END = false, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = true,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = true
  ).* from "./permflow"
}

module cur_plaus_s {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = true, ENV_BG = true,
    ENV_ABORT = true, ENV_NATURAL_END = false, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = true,
    IDS = Set("a", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module cur_plaus_3 {
  import permflow(
    M1 = false, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = true, ENV_BG = true,
    ENV_ABORT = true, ENV_NATURAL_END = false, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = true,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module m1_U {
  import permflow(
    M1 = true, M2 = false, M3 = false,
    ENV_ANYTIME = true, ENV_MSGS_WHILE_PENDING = true, ENV_BG = true,
    ENV_ABORT = true, ENV_NATURAL_END = true, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = true,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = true
  ).* from "./permflow"
}

module m1_U_s {
  import permflow(
    M1 = true, M2 = false, M3 = false,
    ENV_ANYTIME = true, ENV_MSGS_WHILE_PENDING = true, ENV_BG = true,
    ENV_ABORT = true, ENV_NATURAL_END = true, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = true,
    IDS = Set("a", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module m1_U_3 {
  import permflow(
    M1 = true, M2 = false, M3 = false,
    ENV_ANYTIME = true, ENV_MSGS_WHILE_PENDING = true, ENV_BG = true,
    ENV_ABORT = true, ENV_NATURAL_END = true, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = true,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module m1_min {
  import permflow(
    M1 = true, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = true
  ).* from "./permflow"
}

module m1_min_s {
  import permflow(
    M1 = true, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module m1_min_3 {
  import permflow(
    M1 = true, M2 = false, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module m2_U {
  import permflow(
    M1 = false, M2 = true, M3 = false,
    ENV_ANYTIME = true, ENV_MSGS_WHILE_PENDING = true, ENV_BG = true,
    ENV_ABORT = true, ENV_NATURAL_END = true, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = true,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = true
  ).* from "./permflow"
}

module m2_U_s {
  import permflow(
    M1 = false, M2 = true, M3 = false,
    ENV_ANYTIME = true, ENV_MSGS_WHILE_PENDING = true, ENV_BG = true,
    ENV_ABORT = true, ENV_NATURAL_END = true, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = true,
    IDS = Set("a", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module m2_U_3 {
  import permflow(
    M1 = false, M2 = true, M3 = false,
    ENV_ANYTIME = true, ENV_MSGS_WHILE_PENDING = true, ENV_BG = true,
    ENV_ABORT = true, ENV_NATURAL_END = true, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = true,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module m2_min {
  import permflow(
    M1 = false, M2 = true, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = true
  ).* from "./permflow"
}

module m2_min_s {
  import permflow(
    M1 = false, M2 = true, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module m2_min_3 {
  import permflow(
    M1 = false, M2 = true, M3 = false,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module m3_U {
  import permflow(
    M1 = false, M2 = false, M3 = true,
    ENV_ANYTIME = true, ENV_MSGS_WHILE_PENDING = true, ENV_BG = true,
    ENV_ABORT = true, ENV_NATURAL_END = true, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = true,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = true
  ).* from "./permflow"
}

module m3_U_s {
  import permflow(
    M1 = false, M2 = false, M3 = true,
    ENV_ANYTIME = true, ENV_MSGS_WHILE_PENDING = true, ENV_BG = true,
    ENV_ABORT = true, ENV_NATURAL_END = true, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = true,
    IDS = Set("a", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module m3_U_3 {
  import permflow(
    M1 = false, M2 = false, M3 = true,
    ENV_ANYTIME = true, ENV_MSGS_WHILE_PENDING = true, ENV_BG = true,
    ENV_ABORT = true, ENV_NATURAL_END = true, ENV_REENTRANT = true,
    ENV_INPUT_AFTER_DEAD = true,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module m3_min {
  import permflow(
    M1 = false, M2 = false, M3 = true,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = true
  ).* from "./permflow"
}

module m3_min_s {
  import permflow(
    M1 = false, M2 = false, M3 = true,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

module m3_min_3 {
  import permflow(
    M1 = false, M2 = false, M3 = true,
    ENV_ANYTIME = false, ENV_MSGS_WHILE_PENDING = false, ENV_BG = false,
    ENV_ABORT = false, ENV_NATURAL_END = false, ENV_REENTRANT = false,
    ENV_INPUT_AFTER_DEAD = false,
    IDS = Set("a", "b", "q"), ASK_IDS = Set("q"), MAX_RESTARTS = 1, TRACE_LABELS = false
  ).* from "./permflow"
}

