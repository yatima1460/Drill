module WinAPI.WinAPI;

import core.runtime;
import std.string;
import std.utf;

import core.sys.windows.windows;

RECT rect;
int width = 1920 / 2;
int height = 1080 / 2;

int center_window(HWND parent_window, int width, int height)
{
    GetClientRect(parent_window, &rect);
    rect.left = (rect.right / 2) - (width / 2);
    rect.top = (rect.bottom / 2) - (height / 2);
    return 0;
}

extern (Windows) int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance,
        PWSTR pCmdLine, int nCmdShow)
{
    MSG msg;
    HWND hwnd;
    WNDCLASSW wc;

    wc.style = CS_HREDRAW | CS_VREDRAW;
    wc.cbClsExtra = 0;
    wc.cbWndExtra = 0;
    wc.lpszClassName = "Window";
    wc.hInstance = hInstance;
    wc.hbrBackground = GetSysColorBrush(COLOR_3DFACE);
    wc.lpszMenuName = NULL;
    wc.lpfnWndProc = &WndProc;
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    wc.hIcon = LoadIcon(NULL, IDI_APPLICATION);

    RegisterClassW(&wc);

    center_window(GetDesktopWindow(), width, height);
    hwnd = CreateWindowW(wc.lpszClassName, "Drill", WS_OVERLAPPEDWINDOW | WS_VISIBLE,
            rect.left, rect.top, width, height, NULL, NULL, hInstance, NULL);

    ShowWindow(hwnd, nCmdShow);
    UpdateWindow(hwnd);

    while (GetMessage(&msg, NULL, 0, 0))
    {
        DispatchMessage(&msg);
    }

    return cast(int) msg.wParam;
}

extern (Windows) LRESULT WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) nothrow
{

    switch (msg)
    {
    case WM_DESTROY:

        PostQuitMessage(0);
        break;
    default:
        break;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}
