# DMA Controller Register Map Specification

## Channel 0 Register Map

Base Address: `0x00` (Channels 1, 2, 3 will replicate at offsets `0x20`, `0x40`, `0x60` in Stage 2).

| Offset | Name | Type | Reset | Description |
| :--- | :--- | :--- | :--- | :--- |
| `0x00` | `CONTROL` | R/W | `0x00000000` | Channel control register |
| `0x04` | `STATUS` | R/W1C | `0x00000000` | Channel status register |
| `0x08` | `SRC_ADDR` | R/W | `0x00000000` | Source starting base address |
| `0x0C` | `DST_ADDR` | R/W | `0x00000000` | Destination starting base address |
| `0x10` | `TRANSFER_LEN` | R/W | `0x00000000` | Total number of elements to transfer |
| `0x14` | `DATA_WIDTH` | R/W | `0x00000020` | Data width in bits (1 to 32, default 32) |

---

## Field Descriptions

### 1. `CONTROL` (`0x00`)

| Bits | Name | Type | Reset | Description |
| :--- | :--- | :--- | :--- | :--- |
| `[0]` | `START` | WO (Pulse) | `0` | Write `1` to trigger DMA transfer. Automatically clears. Also clears `STATUS.DONE`. |
| `[1]` | `ENABLE` | R/W | `0` | Channel master enable. Must be `1` for `START` to execute. |
| `[2]` | `DIRECTION`| R/W | `0` | Transfer direction:<br>`0`: Peripheral-to-Memory (P2M)<br>`1`: Memory-to-Peripheral (M2P) |
| `[3]` | `SRC_INC` | R/W | `0` | Source address post-increment:<br>`0`: Constant/fixed address (e.g. peripheral FIFO)<br>`1`: Increment address per beat by stride |
| `[4]` | `DST_INC` | R/W | `1` | Destination address post-increment:<br>`0`: Constant/fixed address<br>`1`: Increment address per beat by stride |
| `[5]` | `IRQ_EN` | R/W | `0` | Interrupt enable on transfer completion (`1` = assert IRQ) |
| `[6]` | `ABORT` | WO (Pulse) | `0` | Write `1` to cancel active transfer and return to IDLE |
| `[31:7]`| RESERVED | RO | `0` | Reserved |

---

### 2. `STATUS` (`0x04`)

| Bits | Name | Type | Reset | Description |
| :--- | :--- | :--- | :--- | :--- |
| `[0]` | `BUSY` | RO | `0` | `1` while DMA transfer is in progress, `0` when idle |
| `[1]` | `DONE` | R/W1C | `0` | Set to `1` when transfer count reaches 0. Cleared by writing `1` or starting a new transfer. |
| `[2]` | `ERROR` | R/W1C | `0` | Set to `1` if transfer was aborted. Cleared by writing `1`. |
| `[31:3]`| RESERVED | RO | `0` | Reserved |

---

### 3. `DATA_WIDTH` (`0x14`)

| Bits | Name | Type | Reset | Description |
| :--- | :--- | :--- | :--- | :--- |
| `[5:0]` | `WIDTH` | R/W | `32` | Width of each transferred item in bits (range 1–32).<br>Determines address stepping stride and memory byte enables:<ul><li>`1..8`: Stride = 1 byte, single-byte enables</li><li>`9..16`: Stride = 2 bytes, 16-bit halfword enables</li><li>`17..32`: Stride = 4 bytes, 32-bit word enables</li></ul> |
| `[31:6]`| RESERVED | RO | `0` | Reserved |

---

## Programming Sequence Example (Peripheral to Memory, 32-bit Words)

```c
// 1. Configure Source Address (Peripheral FIFO register)
DMA_SRC_ADDR = 0x40000000;

// 2. Configure Destination Address (Buffer in SRAM)
DMA_DST_ADDR = 0x20001000;

// 3. Set Transfer Length (e.g., 64 words)
DMA_TRANSFER_LEN = 64;

// 4. Set Data Width (32 bits)
DMA_DATA_WIDTH = 32;

// 5. Start Transfer (Enable=1, Dir=P2M(0), SrcInc=0, DstInc=1, IrqEn=1, Start=1)
// Hex: 0x00000033
DMA_CONTROL = (1 << 0) | (1 << 1) | (0 << 2) | (0 << 3) | (1 << 4) | (1 << 5);

// 6. Wait for completion (or wait for IRQ)
while (!(DMA_STATUS & 0x02));

// 7. Clear DONE flag
DMA_STATUS = 0x02;
```
