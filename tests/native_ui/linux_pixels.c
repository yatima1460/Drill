/* Read a rectangle from the private Xvfb root window as packed RGB. */
#include <gdk/gdk.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    if (argc != 5 || !gdk_init_check(NULL, NULL))
        return 1;
    int width = atoi(argv[3]), height = atoi(argv[4]);
    if (width <= 0 || height <= 0 || width > 256 || height > 256)
        return 1;
    g_autoptr(GdkPixbuf) image = gdk_pixbuf_get_from_window(
        gdk_get_default_root_window(), atoi(argv[1]), atoi(argv[2]), width, height);
    if (!image || gdk_pixbuf_get_width(image) != width || gdk_pixbuf_get_height(image) != height)
        return 1;
    const guchar *pixels = gdk_pixbuf_read_pixels(image);
    int stride = gdk_pixbuf_get_rowstride(image), channels = gdk_pixbuf_get_n_channels(image);
    for (int y = 0; y < height; y++) {
        const guchar *row = pixels + y * stride;
        for (int x = 0; x < width; x++)
            if (fwrite(row + x * channels, 3, 1, stdout) != 1)
                return 1;
    }
    return 0;
}
