module WinAPI.WinAPI;

import core.runtime;
import std.string;
import std.utf;

import core.sys.windows.windows;



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


    hwnd = CreateWindowW(wc.lpszClassName, "Drill", WS_OVERLAPPEDWINDOW | WS_VISIBLE,
            0, 0, 1920/2, 1080/2, NULL, NULL, hInstance, NULL);

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
         case WM_CREATE: 
      
            CenterWindow(hwnd);
            break;      
    case WM_DESTROY:

        PostQuitMessage(0);
        break;
    default:
        break;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}


nothrow extern (Windows) void CenterWindow(HWND hwnd) {

    RECT rc = {0};
    
    GetWindowRect(hwnd, &rc);
    int win_w = rc.right - rc.left;
    int win_h = rc.bottom - rc.top;

    int screen_w = GetSystemMetrics(SM_CXSCREEN);
    int screen_h = GetSystemMetrics(SM_CYSCREEN);
    
    SetWindowPos(hwnd, HWND_TOP, (screen_w - win_w)/2, 
        (screen_h - win_h)/2, 0, 0, SWP_NOSIZE);
}