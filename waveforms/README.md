# Showcase waveforms

Run:

```bash
./scripts/generate_waveforms.sh
gtkwave waveforms/traffic_showcase.fst waveforms/traffic_showcase.gtkw
```

`traffic_showcase.vcd` is the portable trace. `traffic_showcase.fst` is the
smaller, faster GTKWave version. The save file preloads the useful signals.

## Scenario IDs

| ID | Demonstration |
|---:|---|
| 1 | Startup and one complete normal NS/EW traffic cycle |
| 2 | NS active-demand extension and hard maximum-green cutoff |
| 3 | Brief pedestrian request, pending latch, walk/flash/clear service |
| 4 | Tick-independent emergency entry, sticky release, reset recovery |

## Event markers

| Marker | Meaning |
|---:|---|
| 10–12 | Normal scenario start, startup timing, road sequence |
| 20–22 | Adaptive scenario start, extension, maximum cutoff tick |
| 30–33 | Pedestrian start, request pulse, pending wait, pedestrian phases |
| 40–43 | Emergency start, assertion, sticky release, reset/restart |
| 99 | End of showcase |

Timing parameters are deliberately accelerated: startup 2 ticks, minimum green
3, maximum green 6, amber 2, all-red 1, walk 3, flash 4, and clear 1. Each high
`tick` pulse advances the registered elapsed counter once. Emergency changes
state on a normal `clk` edge while `tick` remains low, making the fast override
easy to see.
