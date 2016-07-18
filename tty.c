#include <stdlib.h>
#include <termios.h>
#include <unistd.h>

/****************************************************
 * To make effective use of this library function:  *
 * add prototypes for the bellow functions that you *
 * wish to use. Please note that they contain bugs  *
 ****************************************************/


/* In order to restore at exit.*/
static struct termios orig_termios;

/* Raw mode: 1960 magic shit. */
void enableRawMode()
{
	struct termios raw;

	if(!isatty(STDIN_FILENO))
	{
		exit(EXIT_FAILURE);
	}

	if(tcgetattr(STDIN_FILENO, &orig_termios) == -1)
	{
		exit(EXIT_FAILURE);
	}

	raw = orig_termios;	 /* modify the original mode */
	/* input modes: no break, no CR to NL, no parity check, no strip char,
	 * no start/stop output control. */
	raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
	/* output modes - disable post processing */
	raw.c_oflag &= ~(OPOST);
	/* control modes - set 8 bit chars */
	raw.c_cflag |= (CS8);
	/* local modes - choing off, canonical off, no extended functions,
	 * no signal chars (^Z,^C) */
	raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
	/* control chars - set return condition: min number of bytes and timer. */
	raw.c_cc[VMIN] = 0; /* Return each byte, or zero for timeout. */
	raw.c_cc[VTIME] = 1; /* 100 ms timeout (unit is tens of second). */

	/* put terminal in raw mode after flushing */
	if(tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) < 0)
	{
		exit(EXIT_FAILURE);
	}

	return;
}

void disableRawMode()
{
	tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);
}

char tty_getchar()
{
	int nread;
	char c;

	enableRawMode();
	do
	{
		nread = read(STDIN_FILENO, &c, 1);
	} while(nread  == 0);
	disableRawMode();

	return c;
}
