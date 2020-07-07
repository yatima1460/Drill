#ifndef UNICODE
#define UNICODE
#endif

#include <windows.h>

// these are used to ID the controls/windows, and are used to execute an event (e.g. click)
#define ID_EDITCHILD 110 // The edit control (need one of these for each edit control)
#define IDM_EDUNDO 111
#define IDM_EDCUT 112
#define IDM_EDCOPY 113
#define IDM_EDPASTE 114
#define IDM_EDDEL 115
#define GWL_HINSTANCE 6 // required in the definition of the edit control

#define ID_DRILL_ICON 999

// global variables
HWND Mainhwnd; // handle for the main window
HWND hEdit; // handle for the Edit control

// Colour definitions (used to set/change the main window's colour)
// for RGB values: https://www.rapidtables.com/web/color/RGB_Color.html
HBRUSH hBrushBlack = CreateSolidBrush(RGB(0, 0, 0));
HBRUSH hBrushWhite = CreateSolidBrush(RGB(255, 255, 255));
HBRUSH hBrushLightGrey = CreateSolidBrush(RGB(200, 200, 200));


const int ID_EDIT = 1;
const int IDC_LIST = 2;

const TCHAR lpszLatin[] = L"Text edit box test";



void CenterWindow(const HWND hwnd)
{

	RECT rc = { 0 };

	GetWindowRect(hwnd, &rc);
	int win_w = rc.right - rc.left;
	int win_h = rc.bottom - rc.top;

	int screen_w = GetSystemMetrics(SM_CXSCREEN);
	int screen_h = GetSystemMetrics(SM_CYSCREEN);

	SetWindowPos(hwnd, HWND_TOP, (screen_w - win_w) / 2, (screen_h - win_h) / 2, 0, 0, SWP_NOSIZE);
}


LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	HWND hwndEdit;
	HWND hwndList;

	switch (uMsg)
	{
	case WM_CREATE:
	{
		int edit_box_height = 20;
		int screen_w = GetSystemMetrics(SM_CXSCREEN);
		int screen_h = GetSystemMetrics(SM_CYSCREEN);
		hwndEdit = CreateWindowW(L"Edit", NULL,
			WS_CHILD | WS_VISIBLE | WS_BORDER,
			0, 0, screen_w / 2, edit_box_height,
			hwnd, (HMENU)ID_EDIT, NULL, NULL);


		SendMessage(hwndEdit, WM_SETTEXT, 0, (LPARAM)lpszLatin);
		SetFocus(hwndEdit);
		// HWND hWndEdit = CreateWindowEx(WS_EX_CLIENTEDGE, TEXT("Edit"), TEXT("test"),
		//                             WS_CHILD | WS_VISIBLE, 0, 0, 140,
		//                             40, hwnd, NULL, NULL, NULL);
		hwndList = CreateWindowW(L"ListBox", NULL, WS_CHILD | WS_VISIBLE | LBS_NOTIFY,
			0, edit_box_height, screen_w, screen_h - edit_box_height, hwnd,
			(HMENU)IDC_LIST, NULL, NULL);

		CenterWindow(hwnd);
		break;
	}

	case WM_COMMAND:
	{

		switch (wParam)
		{
		case IDM_EDUNDO: // Edit control (to be used by menu options)
						 // Send WM_UNDO only if there is something to be undone. 
			if (SendMessage(hEdit, EM_CANUNDO, 0, 0))
				SendMessage(hEdit, WM_UNDO, 0, 0);
			else
			{
				MessageBox(hEdit,
					L"Nothing to undo.",
					L"Undo notification",
					MB_OK);
			}
			break;
		case IDM_EDCUT: // Edit control (to be used by menu options)
			SendMessage(hEdit, WM_CUT, 0, 0);
			break;

		case IDM_EDCOPY: // Edit control (to be used by menu options)
			SendMessage(hEdit, WM_COPY, 0, 0);
			break;

		case IDM_EDPASTE: // Edit control (to be used by menu options)
			SendMessage(hEdit, WM_PASTE, 0, 0);
			break;

		case IDM_EDDEL: // Edit control (to be used by menu options)
			SendMessage(hEdit, WM_CLEAR, 0, 0);
			break;
		case WM_DESTROY: // REQUIRED in order to close the program completely
			PostQuitMessage(0);
			break;
		default:
			return DefWindowProc(hwnd, uMsg, wParam, lParam);
		}
		abort();
	}
    case WM_SETFOCUS:
	{

		return 0;
	}


	case WM_DESTROY:
	{
		PostQuitMessage(0);
		break;
	}

	default:
	{
		break;
	}
}

return DefWindowProcW(hwnd, uMsg, wParam, lParam);
}



int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE, PWSTR pCmdLine, int nCmdShow)
{
	MSG msg;
	HWND hwnd;
	WNDCLASSW wc;

	wc.style = CS_VREDRAW | CS_HREDRAW;
	wc.cbClsExtra = 0;
	wc.cbWndExtra = 0;
	wc.lpszClassName = L"Window";
	wc.hInstance = hInstance;
	wc.hbrBackground = GetSysColorBrush(COLOR_3DFACE);
	wc.lpszMenuName = NULL;
	wc.lpfnWndProc = &WindowProc;
	wc.hCursor = LoadCursor(NULL, IDC_ARROW);
	wc.hIcon = static_cast<HICON>(LoadImage(hInstance, MAKEINTRESOURCEW(ID_DRILL_ICON), IMAGE_ICON, 32, 32, LR_DEFAULTCOLOR));
	//wc.hIcon = LoadIcon(hInstance, IDI_APPLICATION);

	RegisterClassW(&wc);

	hwnd = CreateWindowW(wc.lpszClassName, L"Drill", WS_OVERLAPPEDWINDOW | WS_VISIBLE, 0, 0,
		GetSystemMetrics(SM_CXSCREEN) / 2,
		GetSystemMetrics(SM_CYSCREEN) / 2, NULL, NULL, hInstance, NULL);

	ShowWindow(hwnd, nCmdShow);
	UpdateWindow(hwnd);

	// The Message Loop
		// this processes all messages (mouse, keyboard) going to the window
	while (GetMessage(&msg, NULL, 0, 0) > 0)
	{
		// process certain keyboard events (e.g. WM_CHAR, WM_KEYDOWN)
		TranslateMessage(&msg);
		// send the processed message out to the window
		DispatchMessage(&msg);
	}

	return (int)msg.wParam;
}



