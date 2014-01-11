module cpu;

import std.stdio;

/* Register information:
 *
 * A         - 4-bit Accumulator
 * R0 - R15  - 4-bit General-purpose registers
 * PC        - 12-bit Program Counter
 * PC1 - PC3 - 12-bit Call stack registers
 * status    - 4-bit flags register
 *   - CPZS
 *      - S - Sign
 *      - Z - Zero
 *      - P - Parity
 *      - C - Carry
 */

class cpu_4004
{
	ubyte[16] r; // General-Purpose registers, all 4 bits

	ushort pc; // 12 bits

	// Call stack, all 12 bits
	ushort pc1;
	ushort pc2;
	ushort pc3;

	ubyte status; // 4 bits

	ubyte[4096] rom; // 4K of 8-bit words

	ubyte[640] ram; // 5120 bits of ram

	this()
	{
		for(int i = 0; i < 16; i++) r[i] = 0;
		pc     = 0;
		pc1    = 0;
		pc2    = 0;
		pc3    = 0;
		status = 0;
	}
}