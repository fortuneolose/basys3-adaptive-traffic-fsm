# Verification Plan

## Strategy

Verification combines deterministic self-checking simulation, continuously
evaluated safety invariants, independent lint, and implemented-design reports.
The controller is tested directly so a simulated second is one explicit
`tick_i` pulse. Test parameters are 2/3/5/2/1/2/2/1 ticks for startup,
minimum/maximum green, amber, all-red, walk, flash, and clear.

The testbench reports each failed expectation and ends with `$fatal`; success
requires `TESTBENCH PASS`. It also writes `build/traffic_controller.vcd`.

## Coverage matrix

| Requirement | Stimulus/check |
|---|---|
| Reset/startup | Synchronous reset; safe output decode; exact startup duration |
| Complete normal cycle | Startup through both road phases and back to NS |
| Exact fixed durations | Check every pre-boundary tick, transition tick, and counter reset |
| All-red clearance | Check both reds in both clearance states before next green |
| NS extension | Active NS, no conflict; verify survival past minimum |
| EW extension | Active EW, no conflict; verify survival past minimum |
| Maximum enforcement | Hold active demand with no conflict; transition exactly at maximum |
| Conflicting demand | Assert opposing sensor after minimum; transition on next tick |
| Pedestrian request by phase | Inject in each state code 0–6 and require eventual walk |
| Brief request | One system-clock request pulse; pending bit remains until service |
| Multiple requests | Repeated pulses collapse into one pending bit and valid service |
| Pedestrian outputs | Both roads red; walk/flash/clear behavior and exact durations |
| Emergency by state | Inject without tick in every state code 0–9; require next-edge entry |
| Emergency release | Deassert and apply ticks; require emergency remains latched |
| Recovery | Clear emergency then reset; require full startup path |
| Reset during emergency | Hold emergency while resetting; require emergency wins |
| Stuck sensors | Hold both high; both roads still advance at minimum due conflict |
| Held button | Debouncer produces one pulse and stable level until release |
| Invalid state | Force encoding 15 and require fail-safe all-red output decode |
| Off-by-one boundaries | Elapsed values checked on every fixed-state boundary |

## Continuous invariants

At every falling clock edge after reset, procedural assertion-equivalents check:

1. NS and EW greens are never simultaneously high.
2. Pedestrian walk never overlaps either vehicle green.
3. Each road has exactly one active red/amber/green indication.
4. Both roads are red throughout pedestrian and emergency states.

The procedural form is accepted by Icarus. A production environment could add
the equivalent SVA and prove it formally.

## Executed results

| Tool / step | Version | Result |
|---|---|---|
| Icarus compile | 12.0 stable | Pass |
| Self-checking simulation | Icarus/vvp 12.0 | Pass, 3,461 checks |
| Top-level lint | Verilator 5.020 | Pass, no diagnostics |
| Vivado synthesis | 2025.1 | Pass, 0 errors / 0 critical warnings |
| Opt/place/phys-opt/route | Vivado 2025.1 | Pass, 0 failed or unrouted nets |
| Timing summary | Vivado 2025.1 | Pass, WNS +1.089 ns, WHS +0.122 ns |
| DRC | Vivado 2025.1 | 0 checks found |
| Methodology | Vivado 2025.1 | 0 checks found |

The only synthesis warning is informational: the small design does not meet
Vivado's criteria for parallel synthesis. Icarus emits its known conservative
`always_comb` constant-select sensitivity message.

## Report review checklist

- `reports/simulation.log`: contains `TESTBENCH PASS: 3461 checks completed`.
- `reports/verilator_lint.log`: empty because strict lint found no diagnostics.
- `reports/utilization_post_route.rpt`: 188 LUTs, 139 flip-flops, 34 IOBs,
  one BUFG.
- `reports/clock_utilization.rpt`: only `sys_clk_pin`, 10.000 ns.
- `reports/timing_summary.rpt`: setup/hold/pulse-width pass and empty
  unconstrained-path table.
- `reports/drc.rpt`: checks found 0.
- `reports/methodology_post_route.rpt`: checks found 0.

## Residual verification gaps

- No formal exhaustive proof or mutation testing.
- Board programming and physical LED/button behavior were not exercised here.
- No gate-level simulation with routed delays; post-route STA is used instead.
- No analog testing of switch bounce, metastability MTBF, or external drivers.
- Emergency behavior has no independent hardware interlock in this educational
  design.
