#include <stdio.h>

int main(int argc, char **argv)
{
	char *pfname = argv[1];
	char *pnewname = pfname;

	while (*(pfname++))
		if (*pfname == ':' )
			*pfname = '-';

	printf("%s", pnewname);
	return 0;
}
