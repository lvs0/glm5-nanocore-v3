# GLM-5.2 NanoCore V3-FINAL

**Synchronous Neuromorphic MAC Tile — TinyTapeout Submission**

> 8-bit input → registered → 4×4 MAC matrix → ReLU → single 8-bit output neuron
> Zero external memory · Hardwired weights · SkyWater 130nm · OpenLane flow

## Architecture

```
in[7:0] → [Input Register] → [4×4 MAC Hidden Layer] → [ReLU] → [Output Neuron] → out[7:0]
                ↑                        ↑                    ↑
           clk / rst_n              4-bit weights          5-bit weights
                               15-bit accumulator      21-bit accumulator
                               overflow-free (V3)       overflow-free (V3)
```

### Datapath Widths (V3-FINAL — overflow-free)

| Stage | Width | Notes |
|-------|-------|-------|
| Input | 8-bit | Registered on clk |
| Products | 13-bit | 9-bit × 4-bit |
| MAC sum (hidden) | 15-bit | Progressive 13→14→15 |
| Hidden ReLU | 15-bit | Sign-bit clamp |
| Output products | 20-bit | 15-bit × 5-bit |
| Output accumulation | 21-bit | 20→20→21 |
| Final output | 8-bit | Saturation logic |

### Non-Linearity
- **Hidden layer**: ReLU (zero-fill negative values)
- **Output**: Saturation clamp — outputs 0 on negative overflow, 255 on positive overflow

### Timing
- Synchronous with global clock
- Registered inputs + registered output
- Target: **100 MHz**

## Pinout (TinyTapeout Standard)

| Pin | Direction | Description |
|-----|-----------|-------------|
| `clk` | Input | Global clock |
| `rst_n` | Input | Active-low reset |
| `in[7:0]` | Input | 8-bit activation vector |
| `out[7:0]` | Output | 8-bit result, registered |

## Project Structure

```
glm5-nanocore-v3/
├── src/
│   ├── glm5_nanocore.v      # Main Verilog RTL (tt_um_glm5_nanocore)
│   ├── config.json          # TinyTapeout config
│   └── Submit Project...html # Submission page (Efabless)
├── OpenLane/                # OpenLane ASIC flow (submodule)
│   └── designs/             # Design configs
├── info.yaml                # Project metadata
└── README.md                # This file
```

## Building the ASIC

Requires [OpenLane](https://github.com/The-OpenROAD-Project/OpenLane) or [LibreLane](https://github.com/librelane/librelane) + Docker.

```bash
# Inside OpenLane container
cd OpenLane
make mount
./flow.tcl -design /path/to/glm5-nanocore-v3 -openlane_version 2024.12.22_01.51
```

Or use the TinyTapeout workflow at [tinytapeout.com](https://tinytapeout.com).

## Hardwired Weights

All weights are compiled into the fabric — no external memory access:

- **Input → Hidden (W_ij)**: 4-bit signed, values ∈ [-3, +3]
- **Hidden → Output (V_j)**: 5-bit signed, values ∈ [-8, +8]
- **Biases (B_i, C_OUT)**: 15-bit / 21-bit signed

Weights are stored as `localparam` in the Verilog source.

## Why "Neuromorphic"?

Classic digital ANN, but with two properties that qualify:
1. **Hardwired computation** — no fetch-decode-execute; the operation is the circuit
2. **Overflow-free datapath** — progressive width expansion prevents saturation artifacts that plague fixed-point neural networks in hardware

## Status

- [x] RTL complete (V3-FINAL, 258 lines)
- [x] Widths verified (overflow-free through full pipeline)
- [x] OpenLane config present
- [ ] Timing closure (100 MHz target)
- [ ] Silicon validated

## Author

Principal ASIC Design Engineer — [lvs0](https://github.com/lvs0)

## License

Apache 2.0