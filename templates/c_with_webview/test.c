
#define WEBVIEW_IMPLEMENTATION
#include "webview.h"

char HTML_CODE[] = "data:text/html,%s"; // [M[ FILE_STRING | ./test.html ]M]

static void invoke_cb(struct webview *w, const char *arg) {
  printf("Callback called with '%s'\n", arg);
}

int main(int argc, char *argv[])
{
    struct webview webview;
    memset(&webview, 0, sizeof(webview));
    webview.title = "title";
    webview.url = HTML_CODE;
    webview.width = 500;
    webview.height = 500;
    webview.resizable = FALSE;
    webview.debug = TRUE;
    webview.external_invoke_cb = &invoke_cb;
    int r = webview_init(&webview);
    do {
        r = webview_loop(&webview, 1);
    } while (r == 0);
    webview_exit(&webview);
    return 0;
}
