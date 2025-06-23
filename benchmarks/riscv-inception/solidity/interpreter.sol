// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Interpreter {
    uint32 constant SP = 2;
    uint32 constant A0 = 10;
    uint32 constant A1 = 11;
    uint32 constant A2 = 12;

    struct State {
        uint32 pc;
        uint32[32] regs;
        bytes mem;
    }

    enum Status {
        Continue,
        Error,
        Finished
    }

    function reg_decode(uint32 reg) internal pure returns (uint32) {
        return reg & 31;
    }

    function sign_ext(uint32 value, uint32 bit_count) internal pure returns (int32) {
        unchecked {
            uint32 mask = uint32(1 << (bit_count - 1));
            return int32(value ^ mask) - int32(mask);
        }
    }

    function bits(uint32 start, uint32 end, uint32 value, uint32 position) internal pure returns (uint32) {
        unchecked {
            uint32 mask = uint32((1 << (end - start + 1)) - 1);
            return ((value >> position) & mask) << start;
        }
    }

    function set_reg(State memory self, uint32 reg, uint32 value) internal pure {
        if (reg != 0) {
            self.regs[reg] = value;
        }
    }

    function u32_from_le_bytes(bytes memory data, uint32 position) internal pure returns (uint32) {
        unchecked {
            return uint32(uint8(data[position])) |
                (uint32(uint8(data[position + 1])) << 8) |
                (uint32(uint8(data[position + 2])) << 16) |
                (uint32(uint8(data[position + 3])) << 24);
        }
    }

    function u16_from_le_bytes(bytes memory data, uint32 position) internal pure returns (uint16) {
        unchecked {
            return uint16(uint8(data[position])) |
                (uint16(uint8(data[position + 1])) << 8);
        }
    }

    function step(State memory self) internal pure returns (Status) {
        unchecked {
            uint32 op = u32_from_le_bytes(self.mem, self.pc);
            self.pc += 4;

            uint32 dst = reg_decode(op >> 7);
            uint32 src1 = reg_decode(op >> 15);
            uint32 src2 = reg_decode(op >> 20);
            uint32 funct3 = (op >> 12) & 7;

            if (op == 0x00000073) {
                if (self.regs[A0] == 0x45584954) {
                    return Status.Finished;
                } else if (self.regs[A0] == 1) {
                    // Print request; ignore it.
                    return Status.Continue;
                } else {
                    return Status.Error;
                }
            }

            uint32 opcode = op & 0x7f;

            if (opcode == 0x37) {
                // LUI
                set_reg(self, dst, op & 0xfffff000);
                return Status.Continue;
            } else if (opcode == 0x17) {
                // AUIPC
                set_reg(self, dst, uint32(int32(self.pc - 4) + int32(op & 0xfffff000)));
                return Status.Continue;
            } else if (opcode == 0x6f) {
                // JAL
                set_reg(self, dst, self.pc);
                int32 offset = sign_ext(
                    bits(1, 10, op, 21) |
                    bits(11, 11, op, 20) |
                    bits(12, 19, op, 12) |
                    bits(20, 20, op, 31),
                    21
                );
                self.pc = uint32(int32(self.pc - 4) + offset);
                return Status.Continue;
            } else if (opcode == 0x67 && funct3 == 0) {
                // JALR
                uint32 target = uint32(int32(self.regs[src1]) + int32(sign_ext(op >> 20, 12))) & (0xffffffff ^ 1);
                set_reg(self, dst, self.pc);
                self.pc = target;
                return Status.Continue;
            } else if (opcode == 0x63) {
                // BRANCH
                int32 offset = sign_ext(
                    bits(1, 4, op, 8) |
                    bits(5, 10, op, 25) |
                    bits(11, 11, op, 7) |
                    bits(12, 12, op, 31),
                    13
                );
                uint32 target = uint32(int32(self.pc - 4) + offset);
                uint32 src1_value = self.regs[src1];
                uint32 src2_value = self.regs[src2];
                bool branch = false;

                if (funct3 == 0) branch = src1_value == src2_value; // BEQ
                else if (funct3 == 1) branch = src1_value != src2_value; // BNE
                else if (funct3 == 4) branch = int32(src1_value) < int32(src2_value); // BLT
                else if (funct3 == 5) branch = int32(src1_value) >= int32(src2_value); // BGE
                else if (funct3 == 6) branch = src1_value < src2_value; // BLTU
                else if (funct3 == 7) branch = src1_value >= src2_value; // BGEU
                else return Status.Error;

                if (branch) self.pc = target;
                return Status.Continue;
            } else if (opcode == 0x3) {
                // LOAD
                int32 offset = sign_ext((op >> 20) & 0xfff, 12);
                uint32 addr = uint32(int32(self.regs[src1]) + offset);
                uint32 value;

                if (funct3 == 0) {
                    // LB
                    value = uint32(int32(int8(uint8(self.mem[addr]))));
                } else if (funct3 == 1) {
                    // LH
                    value = uint32(int32(int16(u16_from_le_bytes(self.mem, addr))));
                } else if (funct3 == 2) {
                    // LW
                    value = u32_from_le_bytes(self.mem, addr);
                } else if (funct3 == 4) {
                    // LBU
                    value = uint32(uint8(self.mem[addr]));
                } else if (funct3 == 5) {
                    // LHU
                    value = uint32(u16_from_le_bytes(self.mem, addr));
                } else {
                    return Status.Error;
                }

                set_reg(self, dst, value);
                return Status.Continue;
            } else if (opcode == 0x23) {
                // STORE
                int32 offset = sign_ext(
                    ((op >> (25 - 5)) & 0xfe0) | ((op >> 7) & 31),
                    12
                );
                uint32 addr = uint32(int32(self.regs[src1]) + offset);
                uint32 src2_value = self.regs[src2];

                if (funct3 == 0) {
                    // SB
                    self.mem[addr] = bytes1(uint8(src2_value));
                } else if (funct3 == 1) {
                    // SH
                    self.mem[addr] = bytes1(uint8(src2_value & 0xff));
                    self.mem[addr + 1] = bytes1(uint8((src2_value >> 8) & 0xff));
                } else if (funct3 == 2) {
                    // SW
                    self.mem[addr] = bytes1(uint8(src2_value & 0xff));
                    self.mem[addr + 1] = bytes1(uint8((src2_value >> 8) & 0xff));
                    self.mem[addr + 2] = bytes1(uint8((src2_value >> 16) & 0xff));
                    self.mem[addr + 3] = bytes1(uint8((src2_value >> 24) & 0xff));
                } else {
                    return Status.Error;
                }

                return Status.Continue;
            } else if (opcode == 0x13) {
                // I-type
                uint32 src1_value = self.regs[src1];
                uint32 value;

                if (funct3 == 0x1) {
                    // SLLI
                    uint8 amount = uint8(bits(0, 4, op, 20));
                    value = src1_value << amount;
                } else if (funct3 == 0x5) {
                    uint8 amount = uint8(bits(0, 4, op, 20));
                    if ((op & 0xfe000000) >> 24 == 0x00) {
                        value = src1_value >> amount; // SRLI
                    } else if ((op & 0xfe000000) >> 24 == 0x40) {
                        value = uint32(int32(src1_value) >> amount); // SRAI
                    } else {
                        return Status.Error;
                    }
                } else if (funct3 == 0x0) {
                    // ADDI
                    int32 imm = sign_ext((op >> 20) & 0xfff, 12);
                    value = src1_value + uint32(imm);
                } else if (funct3 == 0x2) {
                    // SLTI
                    int32 imm = sign_ext((op >> 20) & 0xfff, 12);
                    value = int32(src1_value) < imm ? 1 : 0;
                } else if (funct3 == 0x3) {
                    // SLTIU
                    int32 imm = sign_ext((op >> 20) & 0xfff, 12);
                    value = src1_value < uint32(imm) ? 1 : 0;
                } else if (funct3 == 0x4) {
                    // XORI
                    int32 imm = sign_ext((op >> 20) & 0xfff, 12);
                    value = src1_value ^ uint32(imm);
                } else if (funct3 == 0x6) {
                    // ORI
                    int32 imm = sign_ext((op >> 20) & 0xfff, 12);
                    value = src1_value | uint32(imm);
                } else if (funct3 == 0x7) {
                    // ANDI
                    int32 imm = sign_ext((op >> 20) & 0xfff, 12);
                    value = src1_value & uint32(imm);
                } else {
                    return Status.Error;
                }

                set_reg(self, dst, value);
                return Status.Continue;
            } else if (opcode == 0x33) {
                // R-type
                uint32 src1_value = self.regs[src1];
                uint32 src2_value = self.regs[src2];
                uint32 value;

                uint32 opc_ext = op & 0xfe007000;
                if (opc_ext == 0) {
                    // ADD
                    value = src1_value + src2_value;
                } else if (opc_ext == 0x40000000) {
                    // SUB
                    value = src1_value - src2_value;
                } else if (opc_ext == 0x00001000) {
                    // SLL
                    value = src1_value << (src2_value & 31);
                } else if (opc_ext == 0x00002000) {
                    // SLT
                    value = int32(src1_value) < int32(src2_value) ? 1 : 0;
                } else if (opc_ext == 0x00003000) {
                    // SLTU
                    value = src1_value < src2_value ? 1 : 0;
                } else if (opc_ext == 0x00004000) {
                    // XOR
                    value = src1_value ^ src2_value;
                } else if (opc_ext == 0x00005000) {
                    // SRL
                    value = src1_value >> src2_value;
                } else if (opc_ext == 0x40005000) {
                    // SRA
                    value = uint32(int32(src1_value) >> (src2_value & 31));
                } else if (opc_ext == 0x00006000) {
                    // OR
                    value = src1_value | src2_value;
                } else if (opc_ext == 0x00007000) {
                    // AND
                    value = src1_value & src2_value;
                } else {
                    return Status.Error;
                }

                set_reg(self, dst, value);
                return Status.Continue;
            } else {
                return Status.Error;
            }
        }
    }

    function run(bytes calldata data) public pure returns (uint) {
        uint32 value = u32_from_le_bytes(data, uint32(data.length - 4));
        uint32 maxSize = 16 * 1024 * 1024;
        uint32 bssSize = value < maxSize ? value : maxSize;
        uint32 length = uint32(data.length) - 4 + bssSize;

        State memory state = State({
            pc: 8,
            regs: [uint32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            mem: new bytes(length)
        });

        for (uint i = 0; i < data.length - 4; i++) {
            state.mem[i] = data[i];
        }

        state.regs[SP] = uint32(state.mem.length);

        uint32 count = 0;
        while (true) {
            count += 1;
            Status status = step(state);
            if (status == Status.Finished) {
                break;
            } else if (status == Status.Error) {
                revert("Execution error");
            }
        }

        return count;
    }
}
