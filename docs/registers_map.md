# 8-Channel DMA Controller Register Map Specification

## Channel Base Address Mapping

Each channel occupies 32 bytes (`0x20` stride):

| Channel | Address Range | Base Offset | Description |
| :---: | :---: | :---: | :--- |
| **CH 0** | `0x00` – `0x1F` | `8'h00` | Channel 0 Configuration & Status Registers |
| **CH 1** | `0x20` – `0x3F` | `8'h20` | Channel 1 Configuration & Status Registers |
| **CH 2** | `0x40` – `0x5F` | `8'h40` | Channel 2 Configuration & Status Registers |
| **CH 3** | `0x60` – `0x7F` | `8'h60` | Channel 3 Configuration & Status Registers |
| **CH 4** | `0x80` – `0x9F` | `8'h80` | Channel 4 Configuration & Status Registers |
| **CH 5** | `0xA0` – `0xBF` | `8'hA0` | Channel 5 Configuration & Status Registers |
| **CH 6** | `0xC0` – `0xDF` | `8'hC0` | Channel 6 Configuration & Status Registers |
| **CH 7** | `0xE0` – `0xFF` | `8'hE0` | Channel 7 Configuration & Status Registers |

---

## Channel Internal Register Offsets (Within Base Offset)

| Offset | Name | Type | Reset | Description |
| :---: | :--- | :--- | :--- | :--- |
| `+ 0x00` | `CONTROL` | R/W | `0x00000000` | Channel control register |
| `+ 0x04` | `STATUS` | R/W1C | `0x00000000` | Channel status register (W1C) |
| `+ 0x08` | `SRC_ADDR` | R/W | `0x00000000` | Source starting base address |
| `+ 0x0C` | `DST_ADDR` | R/W | `0x00000000` | Destination starting base address |
| `+ 0x10` | `TRANSFER_LEN` | R/W | `0x00000000` | Total number of elements to transfer |
| `+ 0x14` | `DATA_WIDTH` | R/W | `0x00000020` | Bit-width per element (1 to 32 bits, default 32) |

---

## Field Bit Definitions

### 1. `CONTROL` (`+ 0x00`)

| Bits | Name | Type | Reset | Description |
| :--- | :--- | :--- | :--- | :--- |
| `[0]` | `START` | WO (Pulse) | `0` | Write `1` to trigger DMA transfer. Clears `STATUS.DONE`. |
| `[1]` | `ENABLE` | R/W | `0` | Channel master enable. Must be `1` for transfer to proceed. |
| `[2]` | `DIRECTION`| R/W | `0` | Transfer direction:<br>`0`: Peripheral-to-Memory (P2M)<br>`1`: Memory-to-Peripheral (M2P) |
| `[3]` | `SRC_INC` | R/W | `0` | Source address post-increment:<br>`0`: Fixed address<br>`1`: Increments per beat by stride |
| `[4]` | `DST_INC` | R/W | `1` | Destination address post-increment:<br>`0`: Fixed address<br>`1`: Increments per beat by stride |
| `[5]` | `IRQ_EN` | R/W | `0` | Interrupt enable on transfer completion (`1` = assert IRQ) |
| `[6]` | `ABORT` | WO (Pulse) | `0` | Write `1` to cancel active transfer and return to IDLE |
| `[31:7]`| RESERVED | RO | `0` | Reserved |

---

### 2. `STATUS` (`+ 0x04`)

| Bits | Name | Type | Reset | Description |
| :--- | :--- | :--- | :--- | :--- |
| `[0]` | `BUSY` | RO | `0` | `1` while DMA operation is active |
| `[1]` | `DONE` | R/W1C | `0` | Set when countdown reaches 0. Cleared by writing `1` or new `START`. |
| `[2]` | `ERROR` | R/W1C | `0` | Set if transfer was aborted. Cleared by writing `1`. |
| `[31:3]`| RESERVED | RO | `0` | Reserved |

---

### 3. `DATA_WIDTH` (`+ 0x14`)

| Bits | Name | Type | Reset | Description |
| :--- | :--- | :--- | :--- | :--- |
| `[5:0]` | `WIDTH` | R/W | `32` | Data bit-width per element ($1 \dots 32$).<br>Stride: `1..8` $\implies +1$; `9..16` $\implies +2$; `17..32` $\implies +4$. |
| `[31:6]`| RESERVED | RO | `0` | Reserved |

---

## Multi-Channel C-Driver Programming Example

```c
#define DMA_CH_BASE(ch) ((volatile uint32_t*)(0x80000000 + ((ch) * 0x20)))

void start_dma_channel(int ch, uint32_t src, uint32_t dst, uint32_t len, int is_p2m) {
    volatile uint32_t *dma = DMA_CH_BASE(ch);

    dma[2] = src;  // + 0x08: SRC_ADDR
    dma[3] = dst;  // + 0x0C: DST_ADDR
    dma[4] = len;  // + 0x10: TRANSFER_LEN
    dma[5] = 32;   // + 0x14: DATA_WIDTH = 32 bits

    if (is_p2m) {
        // Start=1, En=1, P2M=0, SrcInc=0, DstInc=1, IrqEn=1 -> 0x33
        dma[0] = 0x33;
    } else {
        // Start=1, En=1, M2P=1, SrcInc=1, DstInc=0, IrqEn=1 -> 0x2F
        dma[0] = 0x2F;
    }
}
```
