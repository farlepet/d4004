/* Intel 4004 emulator
 *
 * NOTE: THIS IS NOT A FAITHFUL EMULATOR, IT DOES NOT SEPREATELY EMULATE
 *   THE CPU, MEMORY ACCESS DEVICES, MEMORY, AND IO DEVICES!
 * 
 * Important notes:
 *   * Speed: 740 KHz
 */

import core.thread;
import std.stdio;
import std.file;

import video;
import cpu;


char[] infile;

int main(char[][] argv)
{
	writefln("d4004 -- An Intel 4004 emulator written in D");

	check_cmds(argv);

	if(!exists(infile))
	{
		writefln("::\x1B[31mROM %s does not exist!\x1B[0m", infile);
		return 1;
	}

	cpu_4004 cpu4004 = new cpu_4004();

	writefln("::Loading file %s into the ROM", infile);

	auto insize = getSize(infile);

	cpu4004.rom[0..insize] = cast(ubyte[])read(infile, 4096);
	cpu4004.rom[insize] = 0xFF; // Opcode telling the CPU to stop (Well, for this `emulator` at least........)

	video.init_video();

	long delay = TickDuration.ticksPerSec / 740000; // Get ticks to delay to accurately simulate the CPU speed

	TickDuration end;

	for(;;)
	{
		video.update_video();
		int v = cpu4004.next_instr();
		if(v < 0) return 0;
		end = TickDuration.currSystemTick() + TickDuration(delay * v);
		while(TickDuration.currSystemTick() < end) { }
	}

	return 0;
}

void check_cmds(char[][] args)
{
	for(int i = 0; i < args.length; i++)
	{
		if(args[i] == "-i")
		{
			infile = args[++i].dup;
		}
	}
}