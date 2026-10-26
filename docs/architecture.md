# 8-Channel DMA Controller Architecture Specification

## 1. System Overview
The Programmable 8-Channel DMA Controller provides concurrent, high-throughput autonomous data transfers between up to 8 independent peripheral streams and a shared memory subsystem. 

Each channel maintains its own independent context (source address, destination address, transfer length down-counter, data width, and control/status). Access to the shared memory master bus is arbitrated using a fair **Round-Robin Token-Passing Arbiter** (`dma_arbiter.v`).

```
                                CPU Register Bus (reg_write, reg_read, reg_addr[7:0], reg_wdata, reg_rdata)
                                                      │
                    ┌─────────────────────────────────┴─────────────────────────────────┐
                    ▼                                                                   ▼
     ┌───────────────────────────────┐                                   ┌───────────────────────────────┐
     │         dma_channel 0         │  ...                             │         dma_channel 7         │
     │  (Base: 0x00, Length, Width)  │                                   │  (Base: 0xE0, Length, Width)  │
     └──────────────┬────────────────┘                                   └──────────────┬────────────────┘
                    │ ch0_req                                                           │ ch7_req
                    │                                                                   │
                    ▼                                                                   ▼
     ┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
     │                                     dma_arbiter.v                                                 │
     │                           (Round-Robin Token Pointer Arbiter)                                     │
     │                                  grant[7:0], grant_idx[2:0]                                       │
     └───────────────────────────────────────────────────┬───────────────────────────────────────────────┘
                                                         │
                                                         ▼
     ┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
     │                                Memory Bus Multiplexer & Gating                                    │
     │                    Routes granted channel's mem_addr, mem_wdata, mem_we, mem_be                   │
     │                    Gates external mem_ready strictly to the requesting channel                    │
     └───────────────────────────────────────────────────┬───────────────────────────────────────────────┘
                                                         │
                                                         ▼
                                             Shared Memory Master Bus
                                (mem_req, mem_we, mem_addr, mem_wdata, mem_be, mem_rdata, mem_ready)
```

---

## 2. Core Functional Blocks

### 2.1 8 Independent DMA Channels (`dma_channel.v`)
- Each channel contains its own:
  - Register File (`dma_registers.v`): stores channel-specific parameters.
  - Control FSM (`dma_fsm.v`): manages handshake states and transitions independently.
  - Datapath (`dma_datapath.v`): generates active addresses, decrements countdown counter, steers byte enables, and buffers data.

### 2.2 Address Decoding & Gating
- 8-bit CPU register address (`reg_addr[7:0]`):
  - Top 3 bits `reg_addr[7:5]` select Channel $0 \dots 7$.
  - Bottom 5 bits `reg_addr[4:0]` address the specific register within that channel.
- Read data bus is sliced based on `reg_addr[7:5]`.

### 2.3 Round-Robin Token-Passing Arbiter (`dma_arbiter.v`)
- Beat-level arbitration ensures no channel hogs the memory bus.
- Circular priority search starting from `token`: $\text{token} \dots \text{token}+7 \pmod 8$.
- **Beat-Lock Mechanism**: Locks active channel during memory latency until `ack_step` occurs (`mem_req && mem_ready`).
- Advanced `token <= grant_idx + 1` upon beat completion.

### 2.4 Response Gating Pipeline
- The controller pipelines the channel index that issued `mem_req` in cycle $T$.
- When memory returns `mem_ready` in cycle $T+1$, `ch_mem_ready` is gated exclusively to that channel, preventing cross-channel handshake race conditions.

---

## 3. Interrupt Architecture
- `irq_channels[7:0]`: Dedicated completion interrupt pin for each channel.
- `irq`: Global consolidated interrupt (`|irq_channels`), signaling the CPU whenever any enabled channel completes its transfer block.
