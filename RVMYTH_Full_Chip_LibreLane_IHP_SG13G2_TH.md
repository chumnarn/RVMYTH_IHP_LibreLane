# คู่มือ Full-chip implementation ของ RVMYTH ด้วย LibreLane และ IHP SG13G2

ฉบับปฏิบัติการ: RTL จาก `kunalg123/rvmyth` ห่อด้วย padframe ของ `chumnarn/ihp-sg13g2-librelane-template`

## 1. เป้าหมายและขอบเขต

คู่มือนี้พาผู้เรียนจากการตรวจ source และจำลอง RTL ไปจนถึงการสร้าง layout ของ full chip สำหรับ RVMYTH บน IHP SG13G2 ด้วย LibreLane 3.x ครอบคลุมการเชื่อม core เข้ากับ I/O pads, การกำหนด clock และ I/O timing, floorplan, PDN, placement, CTS, routing, extraction และ physical verification ที่ flow มีให้

ตัวอย่างอ้างอิง upstream repository snapshot ที่บรรจุในแพ็กเกจนี้:

- RVMyth: commit `2037d3403dc6156ea1d1cc70af34886a3889ff36`
- IHP SG13G2 LibreLane template: commit `0418301723d86133de686ef743cfd668bb3d11d4`
- PDK revision ที่ Makefile ใช้กับ Ciel: `3b5a704ba6738aa686b08706187830e6284d2a10`

การ freeze revision ทำให้ทำซ้ำได้ แต่ผู้สอนควรตรวจ compatibility เมื่อเปลี่ยน LibreLane, PDK, Ciel หรือ template รุ่นใหม่

### ขอบเขตที่ต้องเข้าใจ

1. `mythcore_test.v` เป็น RTL/generated Verilog ของ core สำหรับการเรียนรู้ RV32I ไม่ใช่ RISC-V production SoC ที่มี bus, boot ROM, interrupt controller, debug, clock/reset conditioning หรือ firmware interface ครบ
2. โปรแกรมตัวอย่างและ instruction/data memories อยู่ภายใน RTL; พอร์ต `out[9:0]` เป็นค่าที่ core แสดงจากรีจิสเตอร์ภายใน ไม่ใช่ memory-mapped peripheral interface
3. `chip_top.sv` เป็น padframe สำหรับการศึกษา มี clock pad, active-low reset pad, output pads 10 บิต และ power pads สำหรับ core/I/O domain ตามโครง template ไม่มี analog signal pad, ESD sign-off, package model หรือ board model
4. SDC ในแพ็กเกจเป็น timing budget ตัวอย่าง 20 ns พร้อม input/output delay ที่ตั้งให้ตรวจ coverage ได้ ต้องแทนที่ด้วยข้อกำหนดบอร์ด/ระบบจริงก่อนใช้ผลเป็นข้อสรุป
5. ผล DRC/LVS/STA เป็นผลตามเวอร์ชัน PDK, rule decks, extraction และเงื่อนไขที่ติดตั้งจริงเท่านั้น ห้ามเรียกผลนี้ว่า foundry sign-off หากไม่ได้ใช้ flow และ checklist ที่ foundry/โครงการกำหนด
6. upstream RVMyth snapshot ไม่มีไฟล์ LICENSE ใน repo ณ revision ที่ตรวจพบ ควรยืนยันสิทธิ์ก่อนแจกจ่ายต่อ นอกเหนือจากการใช้งานเพื่อการเรียนการสอนภายใน

## 2. สถาปัตยกรรมของแพ็กเกจ

| ไฟล์ | หน้าที่ |
|---|---|
| `src/mythcore_test.v` | core RTL ต้นฉบับ สร้างโมดูล `core(clk, reset, out[9:0])` |
| `src/mythcore_test_gen.v`, `src/clk_gate.v`, `src/*.vh` | generated RTL และ include files ที่ core ต้องใช้ |
| `src/chip_core.sv` | integration wrapper; แปลง reset pad active-low เป็น reset core active-high |
| `src/chip_top.sv` | full-chip top; IHP SG13G2 pads, power pads, core instance |
| `librelane/config.yaml` | RTL/file list, pad placement, PDK, floorplan, PDN และ implementation options |
| `librelane/chip_top.sdc` | clock, I/O delays, output load, uncertainty/slew |
| `librelane/pdn_cfg.tcl` | PDN grid/core-ring จาก template โดยไม่มี SRAM macro grids |
| `ip/bondpad_70x70_novias/` | LEF/GDS/Verilog abstract ของ bondpad ที่ template ใช้ |
| `src/tb_rvmyth_core.sv` | RTL smoke testbench สำหรับ core โดยตรง |
| `Makefile`, `flake.nix`, `flake.lock` | คำสั่งช่วย, tool shell และ PDK bootstrap |

ข้อมูลทางเดินสัญญาณหลัก:

- `clk_PAD` → `sg13g2_IOPadIn` → `chip_core.clk` → `core.clk`
- `rst_n_PAD` → `sg13g2_IOPadIn` → `chip_core.rst_n` → invert → `core.reset`
- `core.out[9:0]` → `result_core[9:0]` → `sg13g2_IOPadOut30mA` → `result_PAD[9:0]`
- `IOVDD/IOVSS` จ่าย I/O pad domain; `VDD/VSS` จ่าย core domain และ pad supply pins

## 3. เตรียมเครื่องมือและ workspace

### 3.1 Host ที่แนะนำ

ใช้ Linux x86-64 หรือ WSL2 Ubuntu ที่ติดตั้ง Nix flakes, Git และ make แล้ว มีพื้นที่ว่างหลายสิบ GB สำหรับ PDK, Nix store และ run artifacts แนะนำ RAM 16 GB ขึ้นไปสำหรับ flow เต็ม แม้ design นี้จะเล็กกว่า SoC ที่มี SRAM macro

LibreLane shell ใน flake ติดตั้ง LibreLane/OpenROAD/KLayout/Magic/Netgen ตาม dependency ของ flake พร้อม Icarus Verilog และ GTKWave สำหรับจำลอง/ดู waveform

### 3.2 แตกแพ็กเกจและเข้า environment

```bash
unzip RVMYTH_IHP_LibreLane.zip
cd RVMYTH_IHP_LibreLane
nix develop
```

ตรวจเวอร์ชันและคำสั่ง:

```bash
librelane --version
iverilog -V | head -n 2
openroad -version
klayout -v
make help
```

หาก `nix develop` ถามเรื่อง experimental features ให้เปิด flakes ตามแนวทางติดตั้ง Nix ของเครื่องนั้น หาก environment ใช้ `nix-shell` ได้ ให้เรียก `nix-shell` จาก project root เช่นกัน แต่ควรยึด `nix develop` เมื่อใช้ flake

### 3.3 ดาวน์โหลด/activate PDK

```bash
make clone-pdk
ls IHP-Open-PDK/ihp-sg13g2
```

สคริปต์เรียก Ciel ด้วย PDK commit ที่ pin ไว้ ไม่ได้รวม PDK/GDS rule decks ไว้ใน ZIP หากเครื่องมี PDK ที่ผ่านการตรวจแล้ว สามารถกำหนด root เอง:

```bash
make librelane PDK_ROOT=/path/to/pdk-root
```

root ที่กำหนดต้องมี directory `ihp-sg13g2` ภายใน และต้องสอดคล้องกับ configuration ของ Ciel/LibreLane ที่ใช้อยู่

## 4. Lab 0 — ตรวจ source และ configuration ก่อนรัน

### 4.1 ตรวจ Git/source provenance

ถ้าต้องการเทียบกับ upstream:

```bash
git clone https://github.com/kunalg123/rvmyth.git /tmp/rvmyth-upstream
git -C /tmp/rvmyth-upstream rev-parse HEAD
```

ตรวจในแพ็กเกจว่าโมดูลและ include dependency ครบ:

```bash
grep -nE 'module core|include' src/mythcore_test.v src/mythcore_test_gen.v src/clk_gate.v
grep -n 'module chip_core\|module chip_top' src/chip_core.sv src/chip_top.sv
```

ห้ามแก้ generated file เพื่อแก้ synthesis warning โดยไม่เข้าใจต้นทาง หากต้องแก้ core ให้เก็บ diff แยกและรัน simulation regression ใหม่

### 4.2 ตรวจ configuration ที่สัมพันธ์กัน

- `DESIGN_NAME` ต้องเป็น `chip_top`
- รายการ `VERILOG_FILES` ต้องรวม pad wrapper, core wrapper และ upstream core
- include directory ต้องชี้ไป `src/` เพื่อค้น `sp_verilog.vh`, `clk_gate.v`, generated declarations
- `CLOCK_PORT`/`CLOCK_NET` ต้องชี้ที่ clock pad และ pin ผ่าน buffer เข้า core
- instance paths ใน `PAD_SOUTH/EAST/NORTH/WEST` ต้องตรงกับ generate block และ instance name ใน `chip_top.sv`
- `DIE_AREA` ต้องครอบ pad ring; `CORE_AREA` ต้องอยู่ใน die และเหลือพื้นที่ IO/pad ring
- `PNR_SDC_FILE`, `SIGNOFF_SDC_FILE`, `FALLBACK_SDC` ใช้ SDC เดียวกันใน baseline
- `PDN_CFG` นี้ไม่มีชื่อ instance ของ SRAM; ถ้าเพิ่ม SRAM ต้องเพิ่ม macro views, placement, power connections และ macro grid ให้ตรงชื่อ instance จริง

## 5. Lab 1 — RTL simulation ก่อน PnR

รันจาก project root ภายใน Nix shell:

```bash
make sim-rtl
```

คำสั่งเทียบเท่า:

```bash
iverilog -g2012 -I src -s tb_rvmyth_core \
  -o build_rvmyth_sim src/mythcore_test.v src/tb_rvmyth_core.sv
vvp build_rvmyth_sim
```

ผลที่คาดหวังคือ simulation จบโดยไม่เกิด elaboration/runtime error และพิมพ์ `result bus` ออกมา เก็บ waveform `rvmyth_core.vcd` เพื่อดู reset, clock และ output ถ้าต้องการ:

```bash
gtkwave rvmyth_core.vcd
```

Testbench smoke นี้ไม่ได้แทน architectural self-checking test และไม่ได้ตรวจ ISA coverage ทุก instruction ก่อนส่งมอบ ให้ทำ reference-model/scoreboard เพิ่มหากเปลี่ยน core หรือโปรแกรม หาก simulator แจ้ง syntax error ให้ตรวจว่าใช้ Icarus รุ่นที่มากับ flake, include path `-I src`, และ source files ทุกไฟล์อยู่ครบ อย่าแก้ RTL ด้วยการตัด include ออกแบบสุ่ม

## 6. Lab 2 — ตรวจ padframe และ reset polarity

ก่อน synthesis ให้อ่าน `chip_core.sv` และ `chip_top.sv` แล้ววาดสัญญาณ reset ด้วยตนเอง:

- ภายนอกชิป: `rst_n_PAD=0` หมายถึง reset asserted
- หลัง input pad: `rst_n_core=0`
- wrapper ต่อ `~rst_n` เข้า `core.reset`; core จึงเห็น `1` ขณะ reset asserted

ใน full-chip RTL, `clk_PAD`, `rst_n_PAD`, และ `result_PAD` เป็น `inout` เพราะ pad cell มีขา `pad` bidirectional ในโมเดล physical แต่การใช้งานจริงกำหนดทิศโดยเลือก I/O cell ที่เหมาะสม

ตรวจจำนวน instance ที่ต้องตรงกับ config: 1 clock input, 1 reset input, 10 output cells, 1 IOVDD, 1 IOVSS, 1 VDD, 1 VSS และ bondpad macro placements ตาม platform rules

**ข้อควรระวัง:** ชื่อ pad master, electrical pin และ power pin ของ IHP PDK เป็นข้อมูลเฉพาะเวอร์ชัน ให้ตรวจ Verilog/LEF ของ SG13G2 จาก PDK ที่ติดตั้งหาก elaboration รายงาน missing module/terminal

## 7. Lab 3 — เริ่ม full-chip implementation

รัน baseline เต็ม:

```bash
make librelane
```

หรือสั่งตรง:

```bash
librelane librelane/config.yaml \
  --pdk ihp-sg13g2 \
  --pdk-root "$PWD/IHP-Open-PDK" \
  --manual-pdk \
  --save-views-to final/
```

LibreLane จะสร้าง run directory ภายใต้ `librelane/runs/` ให้เก็บ log และ reports เป็นหลักฐาน ห้ามลบ run ที่ล้มเหลวก่อนเก็บ stage ที่ error และ resolved configuration

### ลำดับ stage และสิ่งที่ต้องตรวจ

1. **Load config / source / lint** — ตรวจ top, defines, include paths, ไม่มี unresolved modules และไม่เกิด accidental black box
2. **Synthesis** — ตรวจ cell area, sequential/combinational cell count, latch, undriven/multiple-driver warnings และ mapping ไป SG13G2 cells
3. **Floorplan / IO placement** — ตรวจ die/core boundary, rows, pin-side placement, pad overlap และระยะระหว่าง core กับ pad ring
4. **PDN** — ตรวจ core ring/straps/rails, via insertion, PG terminals ที่ต่อถึง pad และไม่มี supply net ลอย
5. **Global placement / optimization** — ดู utilization, overflow/congestion, max slew/cap/fanout และ setup timing
6. **CTS** — ตรวจ clock tree ถูกสร้างจาก clock pad path, insertion delay/skew และจำนวน clock buffers; เปรียบ pre-CTS กับ post-CTS
7. **Global/detailed routing** — ตรวจ route completion, DRC/antenna markers, shorts/opens และ congestion
8. **Parasitic extraction / STA** — อ่าน SPEF/SDF ที่ flow สร้าง, worst setup/hold paths, clock propagation, unconstrained endpoints และ coverage
9. **DRC/LVS/antenna/final checks** — เก็บรายงานทุก checker พร้อม rule deck/PDK revision ที่ใช้
10. **Final views** — ตรวจ GDS/OASIS, LEF, netlist, SDC/SPEF และรายงานใน `final/` ว่าเป็นของ run ล่าสุดที่จบจริง

ชื่อ stage ที่แน่นอนขึ้นกับ LibreLane release และ flow graph ที่ resolved; ใช้ run summary/manifest ของ run นั้นเป็นแหล่งอ้างอิง ห้ามอาศัยเลข stage จากคู่มือคนละเวอร์ชัน

## 8. Lab 4 — อ่านผล synthesis และ floorplan

### Synthesis audit

ใน run directory ล่าสุด ค้นหา reports/netlists และอ่าน:

```bash
find librelane/runs -type f \( -iname '*stat*' -o -iname '*synth*' -o -iname '*netlist*.v' \) | sort
```

บันทึกอย่างน้อย top module, mapped cell area, จำนวน DFF, combinational area, warnings, inferred latches (ต้องไม่มีโดยไม่ตั้งใจ), black boxes และ tool/Liberty corner ที่ใช้ อย่าเทียบ area หาก library, synthesis constraints, defines หรือ flow revision ต่างกัน

### Floorplan audit

เปิด layout ที่ run สร้างด้วย KLayout หรือดู `make klayout` หลัง run สำเร็จ ตรวจ:

- rows ไม่ทับ macro/pad geometry และ core อยู่ใน die boundary
- pin/pad placement ตรงด้านที่ระบุใน config และไม่มีชื่อ instance ที่หาย
- core utilization ไม่สูงจน routing congested; density 25% เป็นจุดเริ่มต้น ไม่ใช่ค่าที่รับรอง optimal
- bondpads/IO pads อยู่ในตำแหน่งและ orientation ตาม platform
- core ring ไม่ชน pad cells หรือพ้น boundary โดยไม่ตั้งใจ

ถ้าปรับ `DIE_AREA` หรือ `CORE_AREA` ให้บันทึก dimensions ใหม่ พร้อม reason และ rerun ตั้งแต่ floorplan ไม่เปรียบเทียบผลกับ baseline โดยละเลยว่าระยะ routing เปลี่ยนไป

## 9. Lab 5 — PDN และ power connectivity

ตรวจ PG nets จาก reports/checkers และ layout:

1. ยืนยัน logical nets `VDD`, `VSS` อยู่ใน core domain
2. ยืนยัน `IOVDD`, `IOVSS` ต่อถึง I/O pads ตาม power convention ของ PDK/platform
3. ตรวจ power/ground terminals ของ signal pads และ supply pads ว่าต่อถึง nets จริง ไม่ใช่แค่มี wire ชื่อเดียวกัน
4. ตรวจ core ring, vertical/horizontal straps, standard-cell rails และ via stacks
5. ตรวจ PDN connectivity, opens, shorts, disconnected terminals และ PDN geometry DRC
6. หาก checker แจ้ง supply terminal ไม่มีหรือ net ไม่ใช่ supply ให้ตรวจ IHP platform global-connect rules, top-level port visibility และ power pin names ก่อนแก้ Tcl

`PDN_CORE_RING_CONNECT_TO_PADS: true` บอกให้ PDN flow พยายามเชื่อม ring เข้ากับ supply pads ตาม platform conventions; ไม่ใช่หลักฐานว่าทุก IO supply/ground path สมบูรณ์ ต้องใช้ผล connectivity จริงยืนยัน

## 10. Lab 6 — Clock, CTS และ timing

ตัวอย่าง SDC ใช้ period 20 ns (50 MHz), uncertainty 0.25 ns, transition 0.15 ns, reset input delay 0–2 ns, output delay 0–4 ns และ output load 0.033442 ในหน่วยที่ SDC/STA ใช้ตาม library convention โจทย์นี้ให้ฝึก flow เท่านั้น ควรตรวจหน่วย capacitance ของ tool และ Liberty ให้ตรงกัน

ก่อน/หลัง CTS ให้บันทึก:

- clock source object ที่ผูกกับ `clk_pad/p2c`
- clock period, uncertainty, transition และ clock propagation mode
- insertion delay และ skew ที่ CTS รายงาน
- worst setup slack และ worst hold slack พร้อม startpoint/endpoint/corner
- จำนวน unconstrained endpoints และ I/O ports ที่ไม่มี delay
- max transition/capacitance/fanout violations

อ่าน clock report และ timing report โดยแยก launch clock path, data path, capture clock path, setup/hold requirement และ uncertainty อย่าสร้าง clock ซ้ำด้วย SDC เพิ่มอีกชุดโดยไม่ตรวจ SDC ที่ flow อ่านแล้ว และอย่าใส่ false path กว้างเพื่อซ่อน violation

ข้อจำกัดที่ควรรู้: SDC นี้นิยาม clock ที่ output pin ของ input pad cell จาก `CLOCK_NET`; ต้องยืนยันว่าชื่อ pin ถูกต้องจาก netlist/ODB ของ run และ STA propagate clock ผ่าน pad cell อย่างที่ตั้งใจ ถ้า LibreLane version/platform ตีความ clock object ต่างกัน ให้แก้ SDC ตาม timing model ของ I/O cell แล้ว rerun/ตรวจ coverage

## 11. Lab 7 — Routing, extraction และ physical verification

หลัง detailed route:

- ยืนยัน routed signal nets, DRC count, antenna violations, opens/shorts
- ตรวจ connectivity ของ output pins และ clock/reset pads
- ตรวจ extraction corner และ SPEF annotation coverage; อย่าใช้ pre-route wireload แทน post-route RC
- รัน STA ด้วย propagated clocks และ parasitics ที่ flow ใช้จริง; ตรวจ setup และ hold ทุก scenario/corner ที่ platform รองรับ
- รัน KLayout DRC, Magic DRC, LVS, antenna และ density checks ตาม flow ที่เปิดใช้
- ตรวจ LVS source/layout correspondence และ supply net mapping รวม pad/bondpad abstractions
- หาก checker ถูก skip หรือไม่รองรับ ให้บันทึกชื่อ step, เหตุผล และผลที่ยังขาด ห้ามรายงาน skipped checker ว่าผ่าน

หากต้องแยก debug โดยปิด DRC ชั่วคราว ให้ใช้:

```bash
make librelane-nodrc
```

นี่เป็น debug run เท่านั้น ไม่ใช่ final acceptance เพราะมีการข้าม KLayout/Magic DRC, antenna และ density checks

## 12. Lab 8 — เปิดดู layout และรวบรวม outputs

หลัง flow สำเร็จ:

```bash
make klayout
make openroad
make copy-final
find final -maxdepth 2 -type f | sort
```

ส่งมอบ GDS/OASIS พร้อม cell/netlist views, SDC, SPEF หากมี, timing reports, DRC/LVS/antenna reports, resolved config, source revision, PDK revision และ tool versions ควรเก็บ run directory ต้นฉบับไว้พร้อม final views เพื่อสอบย้อนกลับได้

หาก GUI เปิดไม่ได้ ให้เปิด GDS/OASIS โดยตรงใน KLayout หรือ database/ODB/SAVE checkpoint ใน OpenROAD; GUI failure ไม่ได้พิสูจน์ว่า implementation run ล้มเหลว แต่ต้องแยกบันทึกปัญหา GUI ออกจาก physical checks

## 13. เกณฑ์ตรวจรับสำหรับ mini-project

| หัวข้อ | เงื่อนไขผ่านระดับการเรียนรู้ |
|---|---|
| RTL | RTL smoke sim รันจบ; reset polarity และ output ถูกอธิบายได้ |
| Synthesis | ไม่มี unresolved design modules; latch/undriven/multiple-driver ถูกแก้หรือให้เหตุผล |
| Padframe | จำนวน/ชื่อ pad instances ตรง config; pins และ power pins มี connectivity |
| Floorplan | rows/core/die/pads ไม่ทับกันและ placement มีพื้นที่ route |
| PDN | PG checks ที่ flow รองรับผ่าน; skipped/unsupported checks ถูกเปิดเผย |
| Timing | มี SDC coverage audit; setup/hold path และ clock propagation ถูกบันทึก |
| Route | route завершен, opens/shorts/antenna/DRC รายงานครบและผลผ่านตามเกณฑ์ที่ตั้ง |
| LVS | ผ่าน checker ที่รันจริงและใช้ netlist/layout/PDK ที่ตรงกัน |
| Reproducibility | tool versions, config, RTL hash, PDK revision, run tag และคำสั่งถูกรวบรวม |

ผล “จบ flow” ไม่เท่ากับผ่านทุก physical verification และผล passing จาก open PDK flow ไม่เท่ากับ silicon sign-off อัตโนมัติ

## 14. Troubleshooting

### `Module not found` เช่น I/O pad cell หรือ `core`

- ตรวจ PDK_ROOT/PDK และ `make clone-pdk`
- ตรวจ source list/includes และ `VERILOG_INCLUDE_DIRS`
- ตรวจว่า tool อ่าน functional Verilog model ของ SG13G2 pads จาก platform
- อย่าแก้ด้วยการสร้าง empty black box สำหรับ pad ที่ต้องถูกวางจริง

### PAD instance ไม่พบหรือ pad side assignment ล้มเหลว

- เช็ค path ใน config ให้ตรง generate labels เช่น `result_pads[0].result_pad`
- เช็คการ escape วงเล็บเหลี่ยม YAML และรูปแบบที่ LibreLane version ต้องการ
- ตรวจว่าชื่อ cell instance คงอยู่หลัง elaboration; ถ้าเปลี่ยน generate block ให้เปลี่ยน PAD lists ด้วย

### SDC clock ไม่เจอหรือไม่มี clock propagation

- ตรวจ synthesized netlist/ODB ว่า clock pad pin ชื่อ `clk_pad/p2c` จริง
- ตรวจ SDC ที่ resolved ว่าถูกโหลดใน PNR และ signoff steps
- ตรวจ `report_clocks`, `report_clock_tree` และ timing path clocks
- อย่าเพิ่ม `create_clock` ตัวที่สองจนกว่าจะยืนยันว่า clock เดิมไม่ถูกสร้าง

### PDN บอก supply terminal หาย, unconnected หรือ net type ผิด

- ตรวจ `VDD/VSS` top ports, `IOVDD/IOVSS`, pad cell PG pins และ platform global-connect Tcl
- ตรวจ PAD power macro instance และ pad net names ใน netlist
- ตรวจ pin geometry/PDN layer/via rules ใน PDK revision
- หลีกเลี่ยงการ force net type/connection ด้วย Tcl โดยไม่ตรวจ physical connectivity ภายหลัง

### Pad ring / die fit failure

- จำนวน pad ต่อด้านต้องไม่เกินพื้นที่ด้าน die หลังคำนึงถึง corners/sealring/platform spacing
- เพิ่ม DIE_AREA ถ้าจำเป็น และคำนวณ core boundary ใหม่
- บันทึกขนาด die/core ใหม่ เพราะเปลี่ยน wirelength, congestion และ timing

### DRC/LVS failure

- อ่าน first failing rule และ geometry location ก่อน
- แยก PDK rule violation จาก abstract/macro mapping mismatch
- ตรวจ bondpad files/versions และ `IGNORE_DISCONNECTED_MODULES` ให้ตรงกับ macro ที่ intentional
- ไม่ suppress checker/violation เพื่อให้ dashboard ขึ้น pass โดยไม่บันทึก waiver ที่ผ่าน review

## 15. Release record (กรอกเมื่อจบ run)

```text
Design/top: chip_top
RVMyth source commit/hash:
Template base commit:
LibreLane version:
IHP SG13G2 PDK revision:
Nix flake.lock hash/revision:
Run tag:
RTL simulation command/result:
Synthesis cell area / sequential count:
Die/core dimensions / target density:
Clock period / SDC coverage:
Pre-CTS setup/hold WNS:
Post-CTS setup/hold WNS:
Post-route setup/hold WNS and corner(s):
DRC / LVS / antenna / density results:
PG connectivity result:
Skipped steps and reason:
GDS/OASIS path and checksum:
Known limitations / reviewer:
```

ห้ามกรอกตัวเลข PPA หรือสถานะ physical verification ล่วงหน้า ตัวเลขต้องคัดจากรายงาน run จริง พร้อมหน่วย, corner, stage, tool/PDK version และเงื่อนไขการวัด
