# Interview Guide

## 60–90 second explanation

“I designed a synthesizable adaptive traffic-junction controller for a Basys 3
FPGA. The policy is an eleven-state synchronous Moore FSM with explicit amber
and all-red safety intervals, a latched pedestrian request, adaptive green times,
and a sticky emergency all-red state. Everything runs from the board's 100 MHz
clock; a one-cycle enable provides one-second timing, so there are no generated
or gated clocks. All physical inputs use two-flop synchronizers, and the push
buttons are debounced. The green policy guarantees a minimum, extends only for
active traffic with no conflict, and enforces a maximum to prevent starvation.
I separated the portable controller from the board wrapper and built a
self-checking accelerated testbench with continuous safety invariants. It passed
3,461 checks, strict Verilator lint, and Vivado synthesis through routing. The
routed design used 188 LUTs and 139 flip-flops and met the 100 MHz constraint
with +1.089 ns worst setup slack. It is an educational demo, not a certified
road controller; a real system needs independent hardwired safety.”

## Why a Moore FSM?

A Moore machine makes signal lamps a decode of registered state rather than a
direct function of noisy/asynchronous demand inputs. Outputs therefore change
only after clocked state updates. That is easier to review, verify, and reason
about for mutually exclusive safety outputs. `PED_FLASH` also uses a registered
elapsed-time bit, so its blink remains based only on registered state.

## State register, next-state logic, and output logic

- **State register:** an `always_ff` block captures `state_d` on a timing enable.
  Emergency and reset are higher-priority system-clock events.
- **Next-state logic:** an `always_comb` block starts with `state_d = state_q`
  and applies duration/demand policy for every enumerated state. Its default
  recovers toward startup.
- **Output logic:** another `always_comb` block starts with fail-safe all-red
  values and overrides only the lamps appropriate to the current state.

This partition avoids inferred latches and makes safety review local: transition
policy cannot accidentally create a combinational lamp glitch.

## Why clock enables beat generated clocks

A counter pulse used inside `if (tick_i)` is data/control on the existing clock
tree. A fabric-divided “slow clock” would create another clock domain, add clock
tree and crossing problems, and complicate constraints. Clock enables preserve
one global clock, straightforward static timing, and predictable reset behavior.

## Metastability and two-flop synchronization

Switches and buttons can change near a 100 MHz edge. The first synchronizer flop
may become metastable; the second provides settling time before the value reaches
functional logic. This does not make risk zero, but improves mean time between
failures dramatically. Vivado attributes retain the two registers and encourage
appropriate placement. A synchronizer does not debounce—it only addresses clock
domain crossing.

## Button debouncing

A mechanical button may alternate between 0 and 1 for milliseconds. The
debouncer accepts a new level only after it remains different from the current
level for 2,000,000 cycles, or 20 ms at 100 MHz. It emits exactly one
`pressed_o` pulse on a stable rising transition, so holding BTNU cannot create a
new request every second.

## Request latching

The debounced pedestrian pulse may be much shorter than a traffic phase. A
pending flip-flop sets on that pulse and stays set across every intervening
state. It clears only as pedestrian clearance finishes. If set and clear happen
together, the new set wins, preventing a boundary request from disappearing.

## Adaptive timing and starvation prevention

No green can leave before eight seconds. From eight seconds onward, conflict or
loss of active demand ends the phase; continuing active demand with no conflict
extends it. Fifteen seconds always ends it. The FSM still alternates NS then EW,
so the maximum creates a finite service bound even when one sensor stays high.
Pedestrians are served at the all-red decision after EW and have a bounded wait.

## Emergency-state behavior

After two-flop synchronization, emergency bypasses the one-second enable and is
checked on every 100 MHz edge. It forces both roads red, walk off, stop on, and
the emergency LED on. A sticky latch prevents automatic restart when the switch
is lowered. Only reset sampled with emergency low clears it, and recovery starts
through the two-second startup all-red state. If reset and emergency are both
high, emergency wins.

This is still not a real emergency-stop architecture. A certified implementation
would need an independent de-energizing path, feedback, diagnostics, redundancy,
and a safety lifecycle.

## Safety invariants

- NS green and EW green are mutually exclusive.
- Walk never overlaps any vehicle green.
- Exactly one red/amber/green lamp is active per road.
- Both roads are red in pedestrian and emergency phases.
- Every direction change contains amber and all-red states.
- Unknown state decode is all-red.

The RTL makes these true by default decode and state topology; the testbench also
checks them continuously.

## How the testbench verifies the controller

The testbench instantiates the controller directly with shortened tick counts.
Tasks apply reset, generate a single tick, inject a one-clock request, reach a
target state, and verify exact fixed-state durations. Directed tests cover both
green extensions, maximum limits, every request phase, emergency from every
non-emergency state, release/reset semantics, stuck inputs, invalid state, and
off-by-one boundaries. Any mismatch increments a failure count; final success is
reported only when every check passes.

## Reading an example waveform

For a normal cycle, place `clk`, `tick`, `state_code`, `state_elapsed`, all six
vehicle outputs, `ped_pending`, `ped_walk`, and `emergency` in the viewer.

1. `state_code=0`: both reds; elapsed goes 0, 1, then transition on tick 2.
2. `state_code=1`: NS green; with no NS demand it leaves on minimum tick 3.
3. Codes 2 and 3: NS amber then both red; EW green cannot rise before code 4.
4. A request pulse makes `ped_pending` high immediately and it stays high.
5. After codes 4, 5, and 6, code 7 asserts walk with both reds.
6. Codes 8 and 9 flash stop then clear; pending drops only leaving code 9.
7. An emergency edge changes state to 10 without waiting for `tick`.

At each transition, confirm elapsed resets to zero. That is the most useful place
to catch duration off-by-one mistakes.

## Ten likely FPGA interview questions

1. **Why use `always_ff` and nonblocking assignments?** They express edge-
   triggered storage and model simultaneous register updates without ordering
   races.
2. **How did you avoid inferred latches?** Every combinational block assigns
   defaults before its complete case/condition logic.
3. **What does a two-flop synchronizer guarantee?** It reduces metastability
   propagation probability; it cannot guarantee zero risk or debounce a signal.
4. **Why is emergency not debounced?** Conservative assertion is safer; any
   synchronized high latches all-red. Reset/recovery is debounced.
5. **What prevents starvation?** Each green has an unconditional maximum and the
   topology alternates directions.
6. **Why is this still a Moore FSM if stop flashes?** Flash depends on a
   registered elapsed counter, not directly on input; outputs use registered
   state only.
7. **How did you prove no conflicting greens?** Safe output decode, no topology
   path that activates both, continuous simulation checks, and directed state
   coverage. Formal proof is a logical next step.
8. **Why parameterize durations?** Hardware gets readable second values while
   simulation runs thousands of checks quickly without duplicate RTL.
9. **How did timing close?** One BUFG-backed clock, no derived clocks, clock
   enables, explicit XDC, and post-route STA at 10 ns; WNS was +1.089 ns.
10. **What would you change for a real product?** Independent safety shutdown,
    redundancy, feedback, sensor diagnostics, certified requirements/process,
    formal verification, fault injection, and environmental testing.

## Five-minute live demonstration

**0:00–0:40 — Orient the audience.** Point out SW0/SW1 sensors, BTNU request,
BTNC reset, SW15 emergency, signal LEDs, pending LED, and `SSrr` display.

**0:40–1:20 — Safe startup and normal sequence.** Press BTNC. Narrate the two-
second all-red, NS green, amber, all-red, EW green, amber, all-red sequence.

**1:20–2:10 — Adaptive green.** Raise SW0 during NS green and keep SW1 low.
Show that NS extends beyond eight seconds but changes at fifteen. On another
cycle, raise SW1 after minimum green to show a conflict ends NS promptly.

**2:10–3:10 — Pedestrian request.** Tap BTNU briefly and point to LED8 remaining
on. Follow the request through EW, walk, flashing stop, clear, then NS. Explain
why it is served only at a safe all-red decision.

**3:10–4:10 — Emergency.** Raise SW15 during green. Show immediate all-red and
LED15. Lower SW15 and show it remains locked. Press BTNC and show startup rather
than direct green.

**4:10–5:00 — Evidence and limitations.** Show the passing simulation line,
Vivado timing/utilization reports, and explain the key disclaimer: this is an
educational FPGA demonstration without an independent hardware safety path.

## Honest limitations and improvements

The demand model is binary and does not estimate queues. No output feedback can
detect a failed lamp/LED. There is one FPGA, one clock, and no redundant voter or
watchdog. Timing is one-second granularity. Verification is strong directed
simulation plus implementation reports, but not a formal proof or certified
process. Improvements include formal invariant/liveness proofs, constrained
random tests, sensor plausibility checks, dual-controller comparison, hardware
lamp-current monitoring, safe power stages, accessible pedestrian indications,
and runtime-configurable policy with protected bounds.
