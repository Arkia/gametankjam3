#include <stdio.h>
#include <string.h>
#include <stdint.h>

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

#define MAX_PATH 256
#define PALETTE_IMAGE "palette.png"

int main(int argc, char **argv) {
  char *input_file_name;
  char *output_file_name;
  
  printf("Converting Image...\n");
  
  if (argc < 2) {
    printf("Usage: %s <INPUT FILE>\n", argv[0]);
    return -1;
  }
  
  input_file_name = argv[1];
  if (argc > 2) output_file_name = argv[2];
  else {
    output_file_name = malloc(MAX_PATH);
    strncpy(output_file_name, input_file_name, MAX_PATH);
    char *extension_ptr = strrchr(output_file_name, '.');
    if (!extension_ptr) extension_ptr = output_file_name + strlen(output_file_name);
    size_t space_left = MAX_PATH - (extension_ptr - output_file_name);
    strncpy(extension_ptr, ".bin", space_left);
  }
  
  int w,h,n;
  uint8_t *palette = stbi_load(PALETTE_IMAGE, &w, &h, &n, 4);
  if (!palette) {
    printf("Failed to load palette file!\n");
    return -1;
  }
  palette[3] = 0;
  
  uint8_t *input_image = stbi_load(input_file_name, &w, &h, &n, 4);
  if (!input_image) {
    printf("Failed to load input image!\n");
    return -1;
  }
  
  printf("Loaded image %s\nW = %d\nH = %d\n", input_file_name, w, h);
  
  uint8_t page_buffer[128*128];
  memset(page_buffer, 0, 128*128);
  uint8_t *buffer_pixel = page_buffer;
  uint8_t *input_pixel = input_image;
  
  if (w > 128) w = 128;
  if (h > 128) h = 128;
  int pitch = 128 - w;
  
  printf("Converting to 128x128\n");
  
  for (int y=0; y<h; y++) {
    for (int x=0; x<w; x++) {
      uint8_t r = *input_pixel++;
      uint8_t g = *input_pixel++;
      uint8_t b = *input_pixel++;
      uint8_t a = *input_pixel++;
      
      if (!a) {
        *buffer_pixel++ = 0;
      } else {
        int distance = 0x7FFFFFF;
        uint8_t pixel_byte;
        
        for (int i=1; i<256; i++) {
          int palette_index = i*4;
          int d_r = r - palette[palette_index];
          int d_g = g - palette[palette_index+1];
          int d_b = b - palette[palette_index+2];
          
          int new_distance = d_r*d_r + d_g*d_g + d_b*d_b;
          if (new_distance < distance) {
            distance = new_distance;
            pixel_byte = i;
          }
        }
        
        *buffer_pixel++ = pixel_byte;
      }
    }
    
    buffer_pixel += pitch*4;
  }
  
  printf("Finding output height\n");
  
  uint8_t output_buffer[128*128];
  int line_count = 128;
  int line_empty = 1;
  
  while (line_empty && line_count > 0) {
    uint8_t *line_ptr = page_buffer + (line_count-1)*128;
    
    for (int i=0; i<128; i++) {
      if (*line_ptr++) {
        line_empty = 0;
        break;
      }
    }
    
    if (line_empty) line_count--;
  }
  
  printf("Output height = %d\n", line_count);
  
  int input_size = line_count*128;
  int output_index = 0;
  int input_index = 0;
  int sequence_byte = -1;
  int sequence_length = 0;
  
  printf("Compressing...\n");
  
  while (input_index < input_size) {
    int search_start = input_index - 128;
    int run_offset = 0;
    int run_length = 0;
    
    if (search_start < 0) search_start = 0;
    while (search_start < input_index) {
      int search_back = search_start;
      int search_front = input_index;
      int new_length = 0;
      
      for (int i=0; i<255; i++) {
        if (search_front == input_size) break;
        if (page_buffer[search_back++] != page_buffer[search_front++]) break;
        new_length++;
      }
      
      if (new_length > run_length) {
        run_offset = search_start - input_index;
        run_length = new_length;
      }
      
      search_start++;
    }
    
    if (run_length) {
      if (sequence_length) {
        output_buffer[sequence_byte] = sequence_length-1;
        sequence_length = 0;
        sequence_byte = -1;
      }
      
      output_buffer[output_index++] = run_offset;
      output_buffer[output_index++] = run_length;
      input_index += run_length;
    } else {
      if (sequence_length) {
        sequence_length++;
        if (sequence_length == 128) {
          output_buffer[sequence_byte] = sequence_length-1;
          sequence_length = 0;
          sequence_byte = -1;
        } else {
          output_buffer[output_index++] = page_buffer[input_index++];
        }
      } else {
        sequence_byte = output_index++;
        sequence_length = 1;
        output_buffer[output_index++] = page_buffer[input_index++];
      }
    }
  }
  
  printf("Compression Done. Final size = %d\n", output_index+2);
  printf("Compression Ratio: %d%%\n", 100*(output_index+2)/input_size);
  printf("Writing output to %s\n", output_file_name);
  
  FILE *output_file = fopen(output_file_name, "wb");
  if (!output_file) {
    printf("Failed to open output file %s\n", output_file_name);
    return -1;
  }
  fwrite(&input_size, 2, 1, output_file);
  fwrite(output_buffer, 1, output_index, output_file);
  fclose(output_file);
  
  printf("Done!\n");
  return 0;
}