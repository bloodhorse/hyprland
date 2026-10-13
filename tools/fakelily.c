#include <fcntl.h>
#include <linux/uinput.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static struct { const char *n; int c; } T[] = {
    {"esc",KEY_ESC},{"1",KEY_1},{"2",KEY_2},{"3",KEY_3},{"4",KEY_4},{"5",KEY_5},{"6",KEY_6},{"7",KEY_7},{"8",KEY_8},{"9",KEY_9},{"0",KEY_0},
    {"q",KEY_Q},{"w",KEY_W},{"e",KEY_E},{"r",KEY_R},{"t",KEY_T},{"y",KEY_Y},{"u",KEY_U},{"i",KEY_I},{"o",KEY_O},{"p",KEY_P},
    {"a",KEY_A},{"s",KEY_S},{"d",KEY_D},{"f",KEY_F},{"g",KEY_G},{"h",KEY_H},{"j",KEY_J},{"k",KEY_K},{"l",KEY_L},{"semicolon",KEY_SEMICOLON},
    {"z",KEY_Z},{"x",KEY_X},{"c",KEY_C},{"v",KEY_V},{"b",KEY_B},{"n",KEY_N},{"m",KEY_M},{"comma",KEY_COMMA},{"dot",KEY_DOT},{"slash",KEY_SLASH},
    {"tab",KEY_TAB},{"space",KEY_SPACE},{"enter",KEY_ENTER},{"backspace",KEY_BACKSPACE},{"delete",KEY_DELETE},
    {"left",KEY_LEFT},{"right",KEY_RIGHT},{"up",KEY_UP},{"down",KEY_DOWN},
    {"alt",KEY_LEFTALT},{"ralt",KEY_RIGHTALT},{"cmd",KEY_LEFTMETA},{"rcmd",KEY_RIGHTMETA},{"ctrl",KEY_LEFTCTRL},{"lshift",KEY_LEFTSHIFT},{"rshift",KEY_RIGHTSHIFT},
    {"f1",KEY_F1},{"f2",KEY_F2},{"f7",KEY_F7},{"f8",KEY_F8},{"f9",KEY_F9},{"f10",KEY_F10},{"f11",KEY_F11},{"f12",KEY_F12},
    {0,0}};

static int fd, mfd;
static void mev(int type, int code, int val) {
    struct input_event e = {0};
    e.type = type; e.code = code; e.value = val;
    if (write(mfd, &e, sizeof e) < 0) perror("write");
}
static void click(void) { mev(EV_KEY, BTN_LEFT, 1); mev(EV_SYN, SYN_REPORT, 0); usleep(30000); mev(EV_KEY, BTN_LEFT, 0); mev(EV_SYN, SYN_REPORT, 0); usleep(60000); }
static void ev(int type, int code, int val) {
    struct input_event e = {0};
    e.type = type; e.code = code; e.value = val;
    if (write(fd, &e, sizeof e) < 0) perror("write");
}
static void key(int c, int v) { ev(EV_KEY, c, v); ev(EV_SYN, SYN_REPORT, 0); usleep(40000); }
static int code(const char *n) {
    for (int i = 0; T[i].n; i++) if (!strcmp(T[i].n, n)) return T[i].c;
    fprintf(stderr, "unknown key %s\n", n); exit(2);
}

int main(int argc, char **argv) {
    fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) { perror("uinput"); return 1; }
    ioctl(fd, UI_SET_EVBIT, EV_KEY);
    for (int i = 1; i < 249; i++) ioctl(fd, UI_SET_KEYBIT, i);
    struct uinput_setup s = {0};
    s.id.bustype = BUS_USB; s.id.vendor = 0x1d50; s.id.product = 0x615e;
    strcpy(s.name, "Lily58 stand-in");
    ioctl(fd, UI_DEV_SETUP, &s);
    ioctl(fd, UI_DEV_CREATE);
    mfd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    ioctl(mfd, UI_SET_EVBIT, EV_KEY); ioctl(mfd, UI_SET_KEYBIT, BTN_LEFT); ioctl(mfd, UI_SET_KEYBIT, BTN_RIGHT);
    ioctl(mfd, UI_SET_EVBIT, EV_REL); ioctl(mfd, UI_SET_RELBIT, REL_X); ioctl(mfd, UI_SET_RELBIT, REL_Y);
    struct uinput_setup ms = {0};
    ms.id.bustype = BUS_USB; ms.id.vendor = 0x1234; ms.id.product = 0x5678;
    strcpy(ms.name, "stand-in mouse");
    ioctl(mfd, UI_DEV_SETUP, &ms);
    ioctl(mfd, UI_DEV_CREATE);
    sleep(2);
    for (int a = 1; a < argc; a++) {
        if (!strcmp(argv[a], "click")) { click(); continue; }
        if (!strcmp(argv[a], "click2")) { click(); click(); usleep(150000); continue; }
        if (!strncmp(argv[a], "wait:", 5)) { usleep(atoi(argv[a] + 5) * 1000); continue; }
        int ks[8], n = 0;
        char *dup = strdup(argv[a]);
        for (char *p = strtok(dup, "+"); p && n < 8; p = strtok(0, "+")) ks[n++] = code(p);
        for (int i = 0; i < n; i++) key(ks[i], 1);
        for (int i = n - 1; i >= 0; i--) key(ks[i], 0);
        usleep(150000);
    }
    usleep(300000);
    ioctl(fd, UI_DEV_DESTROY);
    ioctl(mfd, UI_DEV_DESTROY);
    close(fd);
    return 0;
}
