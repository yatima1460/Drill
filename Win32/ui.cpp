#ifndef UNICODE
#define UNICODE
#endif

#include <windows.h>
#include <Richedit.h>
#include <CommCtrl.h>
#include <windowsx.h>
#include <uxtheme.h>

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
HWND hEdit;	   // handle for the Edit control

// Colour definitions (used to set/change the main window's colour)
// for RGB values: https://www.rapidtables.com/web/color/RGB_Color.html
// HBRUSH hBrushBlack = CreateSolidBrush(RGB(0, 0, 0));
// HBRUSH hBrushWhite = CreateSolidBrush(RGB(255, 255, 255));
// HBRUSH hBrushLightGrey = CreateSolidBrush(RGB(200, 200, 200));

const int ID_EDIT = 1;
const int IDC_LIST = 2;

// void AutoResizeControls(const HWND hwnd, const HWND hwndEdit, const HWND hwndList, const int edit_box_height)
// {
// 	RECT r = {0};
// 	GetClientRect(hwnd, &r);
// 	SetWindowPos(hwndEdit, NULL, 0, 0, r.right, edit_box_height, NULL);
// 	SetWindowPos(hwndList, NULL, 0, edit_box_height, r.right, r.bottom - edit_box_height, NULL);
// }


int enableVisualStyles(void)
{
	wchar_t dir[MAX_PATH];
	ULONG_PTR ulpActivationCookie = 0;
	ACTCTXW actCtx =
		{
			sizeof(actCtx),
			ACTCTX_FLAG_RESOURCE_NAME_VALID | ACTCTX_FLAG_SET_PROCESS_DEFAULT | ACTCTX_FLAG_ASSEMBLY_DIRECTORY_VALID,
			L"shell32.dll", 0, 0, dir, (LPWSTR)124,
			0, 0};
	UINT cch = GetSystemDirectoryW(dir, sizeof(dir) / sizeof(*dir));
	if (cch >= sizeof(dir) / sizeof(*dir))
	{
		return 0;
	}
	dir[cch] = L'\0';
	ActivateActCtx(CreateActCtxW(&actCtx), &ulpActivationCookie);
	return (int)ulpActivationCookie;
}

/**
 *	Centers a window given a handle
 */
void CenterWindow(const HWND hwnd)
{
	RECT rc = {0};

	GetWindowRect(hwnd, &rc);
	int win_w = rc.right - rc.left;
	int win_h = rc.bottom - rc.top;

	int screen_w = GetSystemMetrics(SM_CXSCREEN);
	int screen_h = GetSystemMetrics(SM_CYSCREEN);

	SetWindowPos(hwnd, HWND_TOP, (screen_w - win_w) / 2, (screen_h - win_h) / 2, 0, 0, SWP_NOSIZE);
}

// The event callback is being called continuously, saving those as global variables..
HWND hwndEdit;
HWND hwndList;

HWND CreateListControl(const HWND mainWindow, const int edit_box_height)
{
	int screen_h = GetSystemMetrics(SM_CYSCREEN);
	int screen_w = GetSystemMetrics(SM_CXSCREEN);
	const auto hwndList = CreateWindowW(L"ListBox", NULL, WS_BORDER | WS_CHILD | WS_VISIBLE | LBS_NOTIFY,
								 0, edit_box_height, screen_w, screen_h - edit_box_height, mainWindow,
								 (HMENU)IDC_LIST, NULL, NULL);

		LONG lExStyleList = GetWindowLong(hwndList, GWL_EXSTYLE);
		lExStyleList &= ~WS_EX_CLIENTEDGE;
		SetWindowLong(hwndList, GWL_EXSTYLE, lExStyleList);
		RECT r = {0};
		GetClientRect(mainWindow, &r);
		SetWindowPos(hwndList, nullptr, 0, edit_box_height, r.right, r.bottom - edit_box_height, 0);

	return hwndList;

}

HWND CreateEditControl(const HWND mainWindow, const int height)
{
	// Load dynamic library for modern text input
	LoadLibrary(TEXT("Msftedit.dll"));

	int screen_w = GetSystemMetrics(SM_CXSCREEN);
	int screen_h = GetSystemMetrics(SM_CYSCREEN);
	const auto hwndEdit = CreateWindowEx(0, MSFTEDIT_CLASS, TEXT(""), WS_VISIBLE | WS_CHILD | WS_BORDER | WS_TABSTOP,
										 0, 0, screen_w / 2, height,
										 mainWindow, nullptr, (HINSTANCE)GetWindowLong(mainWindow, GWL_HINSTANCE), nullptr);

	LONG lExStyle = GetWindowLong(hwndEdit, GWL_EXSTYLE);
	lExStyle &= ~WS_EX_CLIENTEDGE;
	SetWindowLong(hwndEdit, GWL_EXSTYLE, lExStyle);

	CHARFORMAT boldfont;

	boldfont.cbSize = sizeof(CHARFORMAT);
	boldfont.crTextColor = RGB(0, 0, 0);
	boldfont.dwMask = CFM_COLOR | CFM_SIZE | CFM_BOLD | CFM_CHARSET;
	boldfont.yHeight = 350;
	boldfont.dwEffects = CFE_DISABLED; /* Text will be BOLD*/
	boldfont.bCharSet = DEFAULT_CHARSET;
	SendMessage(hwndEdit, EM_SETCHARFORMAT, SCF_ALL, (LPARAM)&boldfont);

	RECT r = {0};
	GetClientRect(mainWindow, &r);
	SetWindowPos(hwndEdit, nullptr, 0, 0, r.right, height, 0);

	return hwndEdit;
}

/**
 * 	Callback receiving the window events
 */
LRESULT CALLBACK WindowProc(HWND handleWindow, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	const int EDIT_BOX_HEIGHT = 40;

	switch (uMsg)
	{

	// Event when the window is created the first time
	case WM_CREATE:
	{
		// Create the search bar
		hwndEdit = CreateEditControl(handleWindow, EDIT_BOX_HEIGHT);
		SetFocus(hwndEdit);
		
		// Create the list with results
		hwndList = CreateListControl(handleWindow, EDIT_BOX_HEIGHT);
	
		// Center the window
		CenterWindow(handleWindow);

		break;
	}

	// Event when right clicking and wanting to spawn a context menu
	case WM_CONTEXTMENU:
	{
#define IDC_PASTE 102

		if ((HWND)wParam == hwndEdit)
		{
			auto m_hMenu = CreatePopupMenu();
			InsertMenu(m_hMenu, 0, MF_BYCOMMAND | MF_STRING | MF_ENABLED, IDC_PASTE, L"Paste");
			TrackPopupMenu(m_hMenu, TPM_TOPALIGN | TPM_LEFTALIGN, GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam), 0, handleWindow, NULL);
		}
		break;
	}

	// Event when some virtual input commands are spawned (closing with the [X] or like Ctrl-V)
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
			return DefWindowProc(handleWindow, uMsg, wParam, lParam);
		}
		abort();
	}
	case WM_SYSCOMMAND:
	{

		if (wParam == SC_MAXIMIZE || wParam == SC_RESTORE)
		{
			
		}
		break;
	}
	case WM_SIZING:
	{

		
		// SendMessage(hwndEdit, EM_WIDTH, SCF_ALL, (LPARAM)&boldfont);
		break;
	}
	case WM_SETFOCUS:
	{

		return 0;
	}

	// Event when the window is being destroyed
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

	return DefWindowProcW(handleWindow, uMsg, wParam, lParam);
}


int CALLBACK WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
	// Set window meta-data
	WNDCLASSW wc;
	wc.style = CS_VREDRAW | CS_HREDRAW;
	wc.cbClsExtra = 0;
	wc.cbWndExtra = 0;
	wc.lpszClassName = L"Drill Window";
	wc.hInstance = hInstance;
	wc.hbrBackground = GetSysColorBrush(COLOR_3DFACE);
	wc.lpszMenuName = NULL;
	// Set window callback receiving events
	wc.lpfnWndProc = &WindowProc;
	// Load default arrow cursor
	wc.hCursor = LoadCursor(hInstance, IDC_ARROW);
	// Load icon as embedded resource (.ico baked inside .exe)
	wc.hIcon = static_cast<HICON>(LoadImage(hInstance, MAKEINTRESOURCEW(ID_DRILL_ICON), IMAGE_ICON, 32, 32, LR_DEFAULTCOLOR));
	// Save the meta-data
	RegisterClassW(&wc);

	// Create the actual window
	HWND hwnd = CreateWindowW(wc.lpszClassName, L"Drill", WS_OVERLAPPEDWINDOW | WS_VISIBLE, 0, 0,
						 GetSystemMetrics(SM_CXSCREEN) / 2,
						 GetSystemMetrics(SM_CYSCREEN) / 2, NULL, NULL, hInstance, NULL);

	// Disable resizing
	auto dwStyle = GetWindowLong(hwnd, GWL_STYLE);
	dwStyle ^= WS_MAXIMIZEBOX;
	dwStyle ^= WS_SIZEBOX;
	SetWindowLong(hwnd, GWL_STYLE, dwStyle);

	// Show the window
	ShowWindow(hwnd, nCmdShow);
	UpdateWindow(hwnd);

	MSG msg;
	// Events loop
	while (GetMessage(&msg, NULL, 0, 0) > 0)
	{

		// Process certain keyboard events (like WM_CHAR, WM_KEYDOWN)
		TranslateMessage(&msg);

		// Send the processed message out to the window
		DispatchMessage(&msg);
	}

	return (int)msg.wParam;
}
