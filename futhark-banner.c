#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <time.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <termios.h>
#include "text.h"

struct termios orig_termios;

void cooked_mode() {
  tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);
  printf("\033[?25h");
}

void raw_mode() {
  printf("\033[?25l");

  tcgetattr(STDIN_FILENO, &orig_termios);
  atexit(cooked_mode);

  struct termios raw = orig_termios;
  raw.c_iflag &= ~(IXON);
  raw.c_lflag &= ~(ECHO | ICANON | ISIG);
  raw.c_cc[VMIN] = 0;
  raw.c_cc[VTIME] = 0;
  tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
}

void clear_screen() {
  printf("\033[2");
}

void clear_line() {
  printf("\033[2K");
}

void def() {
  printf("\033[0m");
}

void fg_rgb(uint8_t r, uint8_t g, uint8_t b) {
  printf("\033[38;2;%d;%d;%dm", r, g, b);
}

void bg_rgb(uint8_t r, uint8_t g, uint8_t b) {
  printf("\033[48;2;%d;%d;%dm", r, g, b);
}

int s_bg_rgb(char *s, uint8_t r, uint8_t g, uint8_t b) {
  return sprintf(s, "\033[48;2;%03d;%03d;%03dm", r, g, b);
}

void render(int nrows, int ncols, uint32_t *rgbs) {
  for (int i = 0; i < nrows; i++) {
    for (int j = 0; j < ncols; j++) {
      double r0 = 0, g0 = 0, b0 = 0;
      double r1 = 0, g1 = 0, b1 = 0;
      uint32_t w0 = rgbs[(i*2)*ncols+j];
      uint32_t w1 = rgbs[(i*2+1)*ncols+j];
      r0 = (w0>>16)&0xFF;
      g0 = (w0>>8)&0xFF;
      b0 = (w0>>0)&0xFF;
      r1 = (w1>>16)&0xFF;
      g1 = (w1>>8)&0xFF;
      b1 = (w1>>0)&0xFF;
      fg_rgb(r0, g0, b0);
      bg_rgb(r1, g1, b1);
      fputs("▀", stdout);
    }
  }
}

void add_text(struct futhark_context *ctx,
              struct futhark_opaque_state **state,
              const char *s, int x, int y, int scale) {
  int error;
  struct futhark_u8_1d *s_fut = futhark_new_u8_1d(ctx, (const unsigned char*)s, strlen(s));
  assert(s_fut != NULL);
  struct futhark_opaque_state *old_state = *state;
  error = futhark_entry_add_text(ctx, state, old_state, s_fut, x, y, scale);
  assert(!error);
  futhark_free_u8_1d(ctx, s_fut);
}

int main(int argc, char** argv) {
  struct futhark_context_config *cfg = futhark_context_config_new();
  assert(cfg != NULL);
  struct futhark_context *ctx = futhark_context_new(cfg);
  assert(ctx != NULL);
  assert(futhark_context_sync(ctx) == 0);

  struct winsize w;
  ioctl(STDOUT_FILENO, TIOCGWINSZ, &w);

  int error = 0;
  int nrows = w.ws_row-1;
  int ncols = w.ws_col;

  assert(nrows >= 0 && ncols >= 0);

  raw_mode();

  struct futhark_u32_2d *arr;

  uint32_t *rgbs = calloc((nrows*2)*ncols, sizeof(uint32_t));

  struct futhark_opaque_state* state;
  error = futhark_entry_init(ctx, &state, nrows*2, ncols);
  assert(!error);

  for (int i = 1; i < argc-3; i += 4) {
    int x = atoi(argv[i]);
    int y = atoi(argv[i+1]);
    int scale = atoi(argv[i+2]);
    if (scale < 1) {
      fprintf(stderr, "Scale must be positive number, not %s\n", argv[i+2]);
      exit(1);
    }
    add_text(ctx, &state, argv[i+3], x, y, scale);
  }

  while (1) {
    struct futhark_u32_2d *arr;
    error = futhark_entry_render(ctx, &arr, state);
    assert(!error);
    error = futhark_values_u32_2d(ctx, arr, rgbs);
    assert(!error);
    error = futhark_context_sync(ctx);
    assert(!error);
    render(nrows,ncols,rgbs);

    char c;
    if (read(STDIN_FILENO, &c, 1) != 0) {
      if (c == 'q') {
        break;
      }
    }

    printf("\r\033[%dA", nrows); // Move up.
  }

  def();
  fflush(stdout);

  futhark_context_free(ctx);
  futhark_context_config_free(cfg);
}
