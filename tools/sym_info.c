#include <stdio.h>
#include <string.h>
#include <stdlib.h>

typedef struct {
  size_t size;
  char *data;
} LineBuffer;

void init_line_buffer(LineBuffer*);
void grow_line_buffer(LineBuffer*);
void get_line(FILE*, LineBuffer*);

typedef struct {
  unsigned int rom_offset;
  unsigned int bank;
  unsigned int offset;
  unsigned int address;
  unsigned int size;
} SectionInfo;

void parse_section(char*, SectionInfo*);
void parse_ramsection(char*, SectionInfo*);

int main(int argc, char **argv) {
  char *in_fname = 0;
  int hex_output = 0;
  int count_zp = 0;
  size_t ram_size = 0;
  size_t zp_size = 0;
  size_t rom_size[256];
  memset(rom_size, 0, sizeof(rom_size));

  for (int i=1; i<argc; i++) {
    if (!in_fname && argv[i][0] != '-') in_fname = argv[i];
    else {
      if (strcmp(argv[i], "-x") == 0) hex_output = 1;
      else if (strcmp(argv[i], "-z") == 0) count_zp = 1;
    }
  }

  if (!in_fname) {
    printf("Usage: %s [options] <SYM FILE>\n", argv[0]);
    return -1;
  }

  FILE *in_file = fopen(in_fname, "r");
  if (!in_file) {
    fprintf(stderr, "Failed to open symbol file %s.\n", in_fname);
    return -1;
  }

  LineBuffer line;
  init_line_buffer(&line);

  while(!feof(in_file)) {
    get_line(in_file, &line);
    if (strcmp(line.data, "[sections]") == 0) break;
  }

  SectionInfo info;
  while(!feof(in_file)) {
    get_line(in_file, &line);
    if (!line.data[0]) continue;
    else if (strcmp(line.data, "[ramsections]") == 0) break;
    else {
      parse_section(line.data, &info);
      rom_size[info.bank] += info.size;
    }
  }

  printf("ROM Usage\n");
  for (int i=0; i<256; i++) {
    if (rom_size[i]) {
      if (hex_output) printf("ROM BANK %02x: %x bytes used\n", i, rom_size[i]);
      else printf("ROM BANK %3d: %d bytes used\n", i, rom_size[i]);
    }
  }

  while(!feof(in_file)) {
    get_line(in_file, &line);
    if (!line.data[0]) continue;
    else if (line.data[0] == '[') break;
    else {
      parse_ramsection(line.data, &info);
      if (count_zp && info.address < 0x100) zp_size += info.size;
      else ram_size += info.size;
    }
  }

  printf("\nRAM Usage\n");
  if (count_zp) {
    if (hex_output) printf("Zero Page: %x bytes used\n", zp_size);
    else printf("Zero Page: %d bytes used\n", zp_size);
  }
  if (hex_output) printf("RAM: %x bytes used\n", ram_size);
  else printf("RAM: %d bytes used\n", ram_size);

  return 0;
}

void init_line_buffer(LineBuffer *line) {
  line->size = 256;
  line->data = malloc(line->size);
}

void grow_line_buffer(LineBuffer *line) {
  line->size *= 2;
  line->data = realloc(line->data, line->size);
}

void get_line(FILE *input, LineBuffer *line) {
  int i=0;
  while (!feof(input)) {
    if (i >= line->size) grow_line_buffer(line);
    line->data[i] = fgetc(input);
    if (line->data[i] == 0 || line->data[i] == '\n') {
      line->data[i] = 0;
      return;
    }
    i++;
  }
  if (i) line->data[i-1] = 0;
}

void parse_section(char *line, SectionInfo *info) {
  sscanf(line, "%x %x:%x %x %x", &info->rom_offset, &info->bank, &info->offset, &info->address, &info->size);
}

void parse_ramsection(char *line, SectionInfo *info) {
  sscanf(line, "%x:%x %x %x", &info->bank, &info->offset, &info->address, &info->size);
}
