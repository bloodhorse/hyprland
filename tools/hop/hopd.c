#include <arpa/inet.h>
#include <fcntl.h>
#include <linux/uinput.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

enum { KBD = 0, MOUSE = 1, PING = 2, DROP = 3 };

struct rec { uint8_t dev, type; uint16_t code; int32_t value; };

static int kfd, mfd;
static unsigned char held[KEY_CNT];
static volatile sig_atomic_t back;
static void home(int sig) { (void)sig; back = 1; }
static const int buttons[] = {BTN_LEFT, BTN_RIGHT, BTN_MIDDLE, BTN_SIDE, BTN_EXTRA};
static const int rels[] = {REL_X, REL_Y, REL_WHEEL, REL_HWHEEL};

static void emit(int fd, int type, int code, int val) {
    struct input_event e = {0};
    e.type = type; e.code = code; e.value = val;
    if (write(fd, &e, sizeof e) < 0) perror("write");
}

static int device(const char *name, int vendor, int product) {
    int fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) { perror("uinput"); exit(1); }
    ioctl(fd, UI_SET_EVBIT, EV_KEY);
    if (vendor == 0x1d50) {
        for (int i = 1; i < 249; i++) ioctl(fd, UI_SET_KEYBIT, i);
    } else {
        for (unsigned i = 0; i < sizeof buttons / sizeof *buttons; i++) ioctl(fd, UI_SET_KEYBIT, buttons[i]);
        ioctl(fd, UI_SET_EVBIT, EV_REL);
        for (unsigned i = 0; i < sizeof rels / sizeof *rels; i++) ioctl(fd, UI_SET_RELBIT, rels[i]);
    }
    struct uinput_setup s = {0};
    s.id.bustype = BUS_USB; s.id.vendor = vendor; s.id.product = product;
    strcpy(s.name, name);
    ioctl(fd, UI_DEV_SETUP, &s);
    ioctl(fd, UI_DEV_CREATE);
    return fd;
}

static void drop(void) {
    for (int c = 0; c < KEY_CNT; c++) {
        if (!held[c]) continue;
        emit(c >= BTN_MISC && c < KEY_OK ? mfd : kfd, EV_KEY, c, 0);
        held[c] = 0;
    }
    emit(kfd, EV_SYN, SYN_REPORT, 0);
    emit(mfd, EV_SYN, SYN_REPORT, 0);
}

static void play(const struct rec *r, int c) {
    if (r->dev == PING) { if (write(c, r, sizeof *r) < 0) perror("pong"); return; }
    if (r->dev == DROP) { drop(); return; }
    if (r->dev == KBD) {
        if (r->type != EV_KEY || r->code < 1 || r->code > 248 || (r->value != 0 && r->value != 1)) return;
        held[r->code] = r->value;
        emit(kfd, EV_KEY, r->code, r->value);
        emit(kfd, EV_SYN, SYN_REPORT, 0);
        return;
    }
    if (r->dev != MOUSE) return;
    if (r->type == EV_SYN) { emit(mfd, EV_SYN, SYN_REPORT, 0); return; }
    if (r->type == EV_REL) {
        for (unsigned i = 0; i < sizeof rels / sizeof *rels; i++)
            if (rels[i] == r->code) emit(mfd, EV_REL, r->code, r->value);
        return;
    }
    if (r->type != EV_KEY || (r->value != 0 && r->value != 1)) return;
    for (unsigned i = 0; i < sizeof buttons / sizeof *buttons; i++)
        if (buttons[i] == r->code) { held[r->code] = r->value; emit(mfd, EV_KEY, r->code, r->value); }
}

static void serve(int c) {
    unsigned char buf[4096];
    size_t have = 0;
    for (;;) {
        struct pollfd p = {c, POLLIN, 0};
        int ready = poll(&p, 1, 2000);
        if (back) {
            struct rec r = {DROP, 0, 0, 0};
            back = 0;
            if (write(c, &r, sizeof r) < 0) return;
            continue;
        }
        if (ready <= 0) return;
        ssize_t n = read(c, buf + have, sizeof buf - have);
        if (n <= 0) return;
        have += n;
        size_t at = 0;
        for (; have - at >= sizeof(struct rec); at += sizeof(struct rec)) {
            struct rec r;
            memcpy(&r, buf + at, sizeof r);
            play(&r, c);
        }
        memmove(buf, buf + at, have - at);
        have -= at;
    }
}

int main(int argc, char **argv) {
    if (argc != 4) { fprintf(stderr, "hopd <listen address> <port> <allowed address>\n"); return 2; }
    signal(SIGPIPE, SIG_IGN);
    struct sigaction sa = {0};
    sa.sa_handler = home;
    sigaction(SIGUSR1, &sa, 0);
    kfd = device("Lily58 hop", 0x1d50, 0x615e);
    mfd = device("hop mouse", 0x25a7, 0xfa61);
    int one = 1;
    int s = socket(AF_INET, SOCK_STREAM, 0);
    setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
    setsockopt(s, IPPROTO_IP, IP_FREEBIND, &one, sizeof one);
    struct sockaddr_in a = {0};
    a.sin_family = AF_INET; a.sin_port = htons(atoi(argv[2]));
    inet_pton(AF_INET, argv[1], &a.sin_addr);
    if (bind(s, (struct sockaddr *)&a, sizeof a) < 0 || listen(s, 1) < 0) { perror("listen"); return 1; }
    struct in_addr allow;
    inet_pton(AF_INET, argv[3], &allow);
    for (;;) {
        struct sockaddr_in peer;
        socklen_t len = sizeof peer;
        int c = accept(s, (struct sockaddr *)&peer, &len);
        if (c < 0) continue;
        if (peer.sin_addr.s_addr != allow.s_addr) { close(c); continue; }
        setsockopt(c, IPPROTO_TCP, TCP_NODELAY, &one, sizeof one);
        fprintf(stderr, "hop on\n");
        back = 0;
        serve(c);
        drop();
        close(c);
        fprintf(stderr, "hop off\n");
    }
}
