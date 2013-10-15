//////////////////////////////////////////////////////////////////////////
//
// extract-html-pre.c
//
// Extract the text between the <pre> and </pre> tags of an html file,
// which constitutes the "preformatted" text. This text my still have
// some html embedded, however, such as "&lt;" for "<", "&#45;" for "-",
// "&amp;" for "&", and "&quot;" for ".
//
// Rather than convert those here, it is better to use something that
// is already written, like sed, to do it. For example:
//
//	sed -i 's/&gt;/>/g;s/&lt;/</g;s/&amp;/\&/g;s/&quot;/"/g' file
//
// Tony Camuso 20131016
//

#include <stdio.h>
#include <string.h>

#define INBUFSIZE 256

int find_tag (char *tag, FILE *file, long* pos);
int copy_file (long begpos, long endpos, FILE *infile, FILE* outfile);
char *fgetstr (FILE *file);

const char* usage_str = "\n"
"usage: extract-html-pre infile outfile\n"
"\n"
"\tinfile:  name of html file to read from\n"
"\toutfile: name of file to write extracted text to\n"
"\n";

int main (int argc, char *argv[])
{

	FILE *infile;
	FILE *outfile;
	char *infilename;
	char *outfilename;
	long pre_tag_pos;
	long end_pre_tag_pos;
	int status = 0;

	if (argc != 3) {
		int i;
		printf("%s", usage_str);
		printf("args: %d\n", argc);
		for(i = 0; i < argc; i++)
			printf("arg[%d]: %s\n", i, argv[i]);
		status = -1;
		goto main_out_1;
	}

	infilename = argv[1];
	outfilename = argv[2];

	if ((infile = fopen(infilename, "r")) == NULL) {
		printf("\nCannot open %s for reading.\n", infilename);
		status = -2;
		goto main_out_1;
	}

	if ((outfile = fopen(outfilename, "w+")) == NULL) {
		printf("\nCannot open %s for writing.\n", outfilename);
		status = -3;
		goto main_out_2;
	}

	if (!(find_tag("<pre>", infile, &pre_tag_pos))) {
		printf("\nCould not find \"<pre>\" tag in %s.\n", infile);
		status = -4;
		goto main_out_3;
	}

	if(!(find_tag("</pre>", infile, &end_pre_tag_pos))) {
		printf("\nCould not find \"</pre>\" tag in %s.\n", infile);
		status = -5;
		goto main_out_3;
	}

	// printf("end_pre_tag_pos: %d\n", end_pre_tag_pos); // debug

	end_pre_tag_pos -= (strlen("</pre>") + 1);

	// printf("end_pre_tag_pos: %d\n", end_pre_tag_pos); // debug

	copy_file(pre_tag_pos, end_pre_tag_pos, infile, outfile);

main_out_3:
	fclose(outfile);

main_out_2:
	fclose(infile);

main_out_1:
	return status;
}

int find_tag (char* tag, FILE *file, long *pos)
{
	static char buff[INBUFSIZE];
	char *pbuf = &buff[0];
	int  found = 0;
	int  status;

	rewind(file);

	while ((fgets(pbuf, INBUFSIZE, file)) != NULL) {
		if (strcasestr(pbuf, tag)) {
			found = 1;
			break;
		}
	}

	*pos = ftell(file);

	// Returns 1 if found, 0 if not found.
	//
	return found;
}


int copy_file (long begpos, long endpos, FILE *infile, FILE* outfile)
{
	long curpos;

	rewind(infile);

	fseek(infile, begpos, SEEK_SET);

	while((ftell(infile) < endpos) && (ftell(infile) != EOF)) {
		// printf("curpos: %d\n", ftell(infile)); // debug
		fputs(fgetstr(infile), outfile);
	}
	return 0;
}

char *fgetstr (FILE *file)
{
	static char buff[INBUFSIZE];
	char *pbuf = &buff[0];

	return (fgets(pbuf, INBUFSIZE, file));
}

