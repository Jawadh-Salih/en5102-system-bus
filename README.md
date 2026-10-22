# 8-bit parallel system bus (Verilog)

A system bus with 2 masters and 3 slaves (4 KB, 4 KB and 2 KB), written in Verilog and verified by simulation. Written for EN5102 Digital Systems Design, Assignment 2.

- 8-bit data, 14-bit address
- Priority arbitration (M0 over M1) with a hold rule, so a master is never cut off mid-transfer
- Asynchronous active-low reset, rising-edge clock

## Files

| File | What it is |
|---|---|
| `arbiter.v` | Priority arbiter with a registered one-hot grant |
| `address_decoder.v` | 14-bit address to one-hot slave select |
| `bus.v` | Top level: arbiter, decoder, forward multiplexer (masters to slaves), return multiplexer (slaves to masters) |
| `tb_arbiter.v` | Self-checking testbench for the arbiter (10 checks) |
| `tb_address_decoder.v` | Self-checking testbench for the decoder (8 edge addresses and a sweep of all 16384 addresses) |
| `tb_bus.v` | Self-checking testbench for the whole bus (16 checks) |

## Memory map

| Slave | Size | Address range (hex) |
|---|---|---|
| S0 | 4 KB | `0000`-`0FFF` |
| S1 | 4 KB | `1000`-`1FFF` |
| S2 | 2 KB | `2000`-`27FF` |
| unmapped | | `2800`-`3FFF` (no slave selected) |

## Run the simulations

Needs [Icarus Verilog](https://steveicarus.github.io/iverilog/) (tested with version 13).

```bash
# arbiter
iverilog -g2012 -o sim_arb tb_arbiter.v arbiter.v && vvp sim_arb

# address decoder
iverilog -g2012 -o sim_dec tb_address_decoder.v address_decoder.v && vvp sim_dec

# whole bus
iverilog -g2012 -o sim_bus tb_bus.v bus.v arbiter.v address_decoder.v && vvp sim_bus
```

Each testbench prints PASS or FAIL for every check and writes a `.vcd` waveform that can be opened in a viewer such as GTKWave.
