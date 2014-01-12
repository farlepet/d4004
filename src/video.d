module video;

import core.sys.posix.termios;
import std.stdio;
import cpu;

void init_video()
{
	//writef("\033[2J");
	//writef("\x1B[1;1H");
	//writef("-\n-\n-\n-\n");

	termios ttystate, ttysave;

	tcgetattr(0, &ttystate);
	ttystate.c_lflag &= ~(ICANON | ECHO);
	ttystate.c_cc[VMIN] = 1;
	tcsetattr(0, TCSANOW, &ttystate);

}

void update_video()
{
	int x, y;
	writef("\x1B[s");    // Save cursor position
	//writef("\x1B[1;1H"); // Go home
	//writef("-\n-\n-\n-\n");
	writef("\x1B[u");
}