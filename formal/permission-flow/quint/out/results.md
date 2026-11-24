凡例: ✓ N = シミュレーター (ID 3 個, 20000 本 x 25 ステップ) で反例なし、かつ TLC が ID 2 個の全状態 N 個を探索して成立。
✗ sim(k) = シミュレーターが反例を発見 (トレースの状態数 k)。✗ TLCのみ(k) = シミュレーターは見つけられず TLC が発見。

### 現行コード (安全性)

| 性質 | cur_min | cur_abort | cur_bg | cur_msgs | cur_bgmsgs | cur_end | cur_reent | cur_reab | cur_dead | cur_bgend | cur_plaus | cur_U |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P1a | ✓ 41672 | ✓ 41672 | ✓ 58376 | ✗ sim(17) | ✗ sim(6) | ✓ 72800 | ✓ 41672 | ✓ 61240 | ✓ 43976 | ✗ sim(6) | ✗ sim(21) | ✗ sim(12) |
| P1b | ✗ sim(23) | ✗ sim(4) | ✗ sim(7) | ✗ sim(16) | ✗ sim(7) | ✗ sim(20) | ✗ sim(14) | ✗ sim(13) | ✗ sim(9) | ✗ sim(8) | ✗ sim(3) | ✗ sim(7) |
| P2 | ✓ 41672 | ✓ 41672 | ✓ 58376 | ✓ 53192 | ✓ 69896 | ✓ 72800 | ✓ 41672 | ✓ 61240 | ✓ 43976 | ✓ 127148 | ✓ 103672 | ✓ 347160 |
| P3 | ✓ 41672 | ✓ 41672 | ✓ 58376 | ✓ 53192 | ✓ 69896 | ✓ 72800 | ✓ 41672 | ✗ sim(12) | ✓ 43976 | ✓ 127148 | ✗ sim(5) | ✗ sim(2) |
| P4_resolved | ✗ sim(6) | ✗ sim(4) | ✗ sim(5) | ✗ sim(6) | ✗ sim(5) | ✗ sim(6) | ✗ sim(12) | ✗ sim(9) | ✗ sim(6) | ✗ sim(5) | ✗ sim(7) | ✗ sim(7) |
| P4_view | ✗ sim(6) | ✗ sim(4) | ✗ sim(5) | ✗ sim(6) | ✗ sim(5) | ✗ sim(6) | ✗ sim(12) | ✗ sim(9) | ✗ sim(6) | ✗ sim(5) | ✗ sim(7) | ✗ sim(7) |
| P4_userDecision | ✓ 41672 | ✓ 41672 | ✓ 58376 | ✓ 53192 | ✓ 69896 | ✓ 72800 | ✓ 41672 | ✓ 61240 | ✓ 43976 | ✓ 127148 | ✓ 103672 | ✓ 347160 |
| P4_app | ✗ sim(23) | ✗ sim(4) | ✗ sim(7) | ✗ sim(16) | ✗ sim(7) | ✗ sim(20) | ✗ sim(14) | ✗ sim(9) | ✗ sim(9) | ✗ sim(6) | ✗ sim(3) | ✗ sim(7) |
| P4_aux_registered | ✓ 41672 | ✓ 41672 | ✓ 58376 | ✓ 53192 | ✓ 69896 | ✓ 72800 | ✓ 41672 | ✓ 61240 | ✓ 43976 | ✓ 127148 | ✓ 103672 | ✓ 347160 |
| P5_state | ✓ 41672 | ✓ 41672 | ✓ 58376 | ✓ 53192 | ✓ 69896 | ✓ 72800 | ✓ 41672 | ✓ 61240 | ✗ sim(12) | ✓ 127148 | ✗ sim(12) | ✗ sim(12) |
| P5_noEffect | ✓ 41672 | ✓ 41672 | ✓ 58376 | ✓ 53192 | ✓ 69896 | ✓ 72800 | ✓ 41672 | ✓ 61240 | ✓ 43976 | ✓ 127148 | ✓ 103672 | ✓ 347160 |
| P6 | ✓ 41672 | ✓ 41672 | ✓ 58376 | ✓ 53192 | ✓ 69896 | ✓ 72800 | ✓ 41672 | ✓ 61240 | ✓ 43976 | ✓ 127148 | ✓ 103672 | ✓ 347160 |
| P8_noLostInput | ✓ 41672 | ✓ 41672 | ✓ 58376 | ✓ 53192 | ✓ 69896 | ✗ sim(10) | ✓ 41672 | ✓ 61240 | ✓ 43976 | ✗ sim(8) | ✓ 103672 | ✗ sim(11) |

### 退行 (安全性)

| 性質 | m1_min | m1_U | m2_min | m2_U | m3_min | m3_U |
|---|---|---|---|---|---|---|
| P1a | ✓ 28104 | ✗ sim(12) | ✓ 62408 | ✗ sim(12) | ✓ 64760 | ✗ sim(12) |
| P1b | ✗ sim(23) | ✗ sim(7) | ✗ sim(23) | ✗ sim(7) | ✗ sim(23) | ✗ sim(7) |
| P2 | ✗ sim(6) | ✗ sim(10) | ✓ 62408 | ✓ 343268 | ✓ 64760 | ✓ 573880 |
| P3 | ✓ 28104 | ✗ sim(2) | ✓ 62408 | ✓ 343268 | ✓ 64760 | ✗ sim(2) |
| P4_resolved | ✓ 28104 | ✗ sim(7) | ✗ sim(6) | ✗ sim(3) | ✗ sim(6) | ✗ sim(7) |
| P4_view | ✗ sim(6) | ✗ sim(7) | ✗ sim(6) | ✗ sim(3) | ✗ sim(6) | ✗ sim(7) |
| P4_userDecision | ✓ 28104 | ✓ 578860 | ✗ sim(22) | ✗ sim(6) | ✓ 64760 | ✓ 573880 |
| P4_app | ✗ sim(23) | ✗ sim(7) | ✗ sim(23) | ✗ sim(7) | ✗ sim(23) | ✗ sim(7) |
| P4_aux_registered | ✓ 28104 | ✓ 578860 | ✗ sim(4) | ✗ sim(2) | ✓ 64760 | ✓ 573880 |
| P5_state | ✓ 28104 | ✗ sim(12) | ✓ 62408 | ✗ sim(12) | ✓ 64760 | ✗ sim(12) |
| P5_noEffect | ✓ 28104 | ✓ 578860 | ✓ 62408 | ✓ 343268 | ✓ 64760 | ✓ 573880 |
| P6 | ✓ 28104 | ✓ 578860 | ✓ 62408 | ✓ 343268 | ✗ sim(20) | ✗ sim(19) |
| P8_noLostInput | ✓ 28104 | ✗ sim(11) | ✓ 62408 | ✗ sim(11) | ✓ 64760 | ✗ sim(11) |

### 活性 (TLC の時相検査、ID 2 個)

| 性質 | cur_min_s | cur_bg_s | cur_bgend_s | cur_plaus_s | cur_U_s | m1_min_s | cur_abort_s | cur_msgs_s | cur_end_s | m2_min_s | m3_min_s |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P7_sdkFairOnly | ✗ (11) | ✗ (10) | ✗ (8) | ✗ (8) | ✗ (7) | ✗ (6) | – | – | – | – | – |
| P7_fair | ✓ 41672 | ✓ 58376 | ✗ (5) | ✓ 103672 | ✗ (7) | ✗ (8) | ✓ 41672 | ✓ 53192 | ✓ 72800 | ✓ 62408 | ✓ 64760 |
| P7_table_fair | ✓ 41672 | ✓ 58376 | ✗ (9) | ✓ 103672 | ✗ (7) | ✓ 28104 | – | – | – | – | – |
| P8_sdkFairOnly | ✗ (15) | ✗ (9) | ✗ (8) | ✗ (9) | ✓ 347160 | ✗ (13) | – | – | – | – | – |
| P8_fair | ✓ 41672 | ✗ (10) | ✗ (6) | ✗ (8) | ✓ 347160 | ✗ (14) | ✓ 41672 | ✓ 53192 | ✗ (11) | ✓ 62408 | ✓ 64760 |
| P8_stoppedOnly_fair | ✓ 41672 | ✗ (10) | ✗ (5) | ✗ (7) | ✗ (8) | ✗ (11) | – | – | – | – | – |

### その他の段

| 段 | インスタンス | 性質 | 結果 | 詳細 |
|---|---|---|---|---|
| traces | cur_min_s | P1b | violation | trace states=5 |
| traces | cur_min_s | P4_view | violation | trace states=5 |
| traces | cur_min_s | P4_app | violation | trace states=6 |
| traces | cur_abort_s | P1b | violation | trace states=5 |
| traces | cur_abort_s | P4_app | violation | trace states=6 |
| traces | cur_msgs_s | P1a | violation | trace states=6 |
| traces | cur_bg_s | P1b | violation | trace states=4 |
| traces | cur_bgend_s | P1a | violation | trace states=4 |
| traces | cur_end_s | P8_noLostInput | violation | trace states=5 |
| traces | cur_dead_s | P5_state | violation | trace states=4 |
| traces | cur_reab_s | P3 | violation | trace states=5 |
| traces | cur_plaus_s | P1a | violation | trace states=5 |
| traces | cur_bg_s | D_runningImpliesTurn | violation | trace states=4 |
| traces | m1_min_s | P2 | violation | trace states=6 |
| traces | m2_min_s | P4_userDecision | violation | trace states=6 |
| traces | m2_min_s | P4_aux_registered | violation | trace states=5 |
| traces | m2_min_s | P4_resolved | violation | trace states=6 |
| traces | m3_min_s | P6 | violation | trace states=6 |
| itf | cur_min | P1b | violation | steps<=5; out/itf/cur_min.P1b.interrupt.itf.json |
| itf | cur_abort | P4_app | violation | steps<=5; out/itf/cur_abort.P4_app.abort.itf.json |
| itf | cur_msgs | P1a | violation | steps<=5; out/itf/cur_msgs.P1a.system-status.itf.json |
| itf | cur_end | P8_noLostInput | violation | steps<=6; out/itf/cur_end.P8_noLostInput.restart-after-end.itf.json |
| itf | cur_dead | P5_state | violation | steps<=4; out/itf/cur_dead.P5_state.input-after-error.itf.json |
| itf | cur_bgend | P1a | violation | steps<=3; out/itf/cur_bgend.P1a.stream-end-with-pending.itf.json |
| itf | cur_reab | P3 | violation | steps<=4; out/itf/cur_reab.P3.double-resolve.itf.json |
| itf | cur_bg | P1b | violation | steps<=4; out/itf/cur_bg.P1b.itf.json |
| itf | cur_bg | D_runningImpliesTurn | violation | steps<=5; out/itf/cur_bg.D_runningImpliesTurn.approve-outside-turn.itf.json |
| itf | m1_min | P2 | violation | steps<=5; out/itf/m1_min.P2.itf.json |
| itf | m2_min | P4_userDecision | violation | steps<=6; out/itf/m2_min.P4_userDecision.itf.json |
| itf | m3_min | P6 | violation | steps<=7; out/itf/m3_min.P6.itf.json |
| deep | cur_U_3 | P2 P4_userDecision P4_aux_registered P5_noEffect P6 | ok | exhaustive; 2462496 distinct states; depth 20 |
| replay | random.cur_U | - | 500 passed (500) | 500 traces x 30 steps, seed 11 |
| replay | random.m1_U | - | 9 failed | 91 passed (100) | 100 traces x 30 steps, seed 11 |
| replay | random.m2_U | - | 24 failed | 76 passed (100) | 100 traces x 30 steps, seed 11 |
| replay | random.m3_U | - | 3 failed | 97 passed (100) | 100 traces x 30 steps, seed 11 |
| replay | counterexamples.current | - | 9 passed (9) | out/itf/cur_*: 通れば実装でも再現 |
| replay | counterexamples.mutants | - | 2 failed | 1 passed (3) | out/itf/m*: 食い違えば実装は退行していない |
| apalache | cur_min | P1b | timeout | steps<=4; 902s; stopped after APA_TIMEOUT=900s |
| apalache | m1_min | P2 | timeout | steps<=4; 902s; stopped after APA_TIMEOUT=900s |
