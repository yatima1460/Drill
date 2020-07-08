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
//#define GWL_HINSTANCE 6 // required in the definition of the edit control

#define ID_DRILL_ICON 999

// global variables
HWND Mainhwnd; // handle for the main window
HWND hEdit;	   // handle for the Edit control

// Colour definitions (used to set/change the main window's colour)
// for RGB values: https://www.rapidtables.com/web/color/RGB_Color.html
HBRUSH hBrushBlack = CreateSolidBrush(RGB(0, 0, 0));
HBRUSH hBrushWhite = CreateSolidBrush(RGB(255, 255, 255));
HBRUSH hBrushLightGrey = CreateSolidBrush(RGB(200, 200, 200));

const int ID_EDIT = 1;
const int IDC_LIST = 2;

void AutoResizeControls(const HWND hwnd, const HWND hwndEdit, const HWND hwndList, const int edit_box_height)
{
	RECT r = {0};
	GetClientRect(hwnd, &r);
	SetWindowPos(hwndEdit, NULL, 0, 0, r.right, edit_box_height, NULL);
	SetWindowPos(hwndList, NULL, 0, edit_box_height, r.right, r.bottom - edit_box_height, NULL);
}

// const TCHAR lpszLatin[] = L"Text edit box test";
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

HWND hwndEdit;
HWND hwndList;
bool invalidUI;

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{

	//HWND hwndStatusBar;
	int edit_box_height = 40;

	if (invalidUI)
	{
		AutoResizeControls(hwnd, hwndEdit, hwndList, edit_box_height);
		invalidUI = false;
	}

	switch (uMsg)
	{
	case WM_CREATE:
	{
		//enableVisualStyles();

		int screen_w = GetSystemMetrics(SM_CXSCREEN);
		int screen_h = GetSystemMetrics(SM_CYSCREEN);
		// hwndEdit = CreateWindowW(L"Edit", NULL,
		// 	WS_CHILD | WS_VISIBLE | WS_BORDER,
		// 	0, 0, screen_w / 2, edit_box_height,
		// 	hwnd, (HMENU)ID_EDIT, NULL, NULL);





		hwndEdit = CreateWindowEx(0, MSFTEDIT_CLASS, TEXT(""),
								  /* ES_MULTILINE |*/ WS_VISIBLE | WS_CHILD | WS_BORDER | WS_TABSTOP,
								  0, 0, screen_w / 2, edit_box_height,
								  hwnd, NULL, (HINSTANCE)GetWindowLong(hwnd, GWL_HINSTANCE), NULL);

		LONG lExStyle = GetWindowLong(hwndEdit, GWL_EXSTYLE);
lExStyle &= ~WS_EX_CLIENTEDGE;
SetWindowLong(hwndEdit, GWL_EXSTYLE, lExStyle);
		//    HWND hwndStatus;
		//     RECT rcClient;
		//     HLOCAL hloc;
		//     PINT paParts;
		//     int i, nWidth;

		// Ensure that the common control DLL is loaded.
		//  InitCommonControls();
		// Create the status bar.
		//     hwndStatusBar = CreateWindowEx(
		//         0,                       // no extended styles
		//         STATUSCLASSNAME,         // name of status bar class
		//         (PCTSTR) NULL,           // no text when first created
		//         SBARS_SIZEGRIP |         // includes a sizing grip
		//         WS_CHILD | WS_VISIBLE,   // creates a visible child window
		//         0, 0, 0, 0,              // ignores size and position
		//         hwnd,              // handle to parent window
		//         (HMENU) NULL,       // child window identifier
		//         (HINSTANCE)GetWindowLong(hwnd, GWL_HINSTANCE),                   // handle to application instance
		//         NULL);                   // no window creation data

		// // Get the coordinates of the parent window's client area.
		//     GetClientRect(hwnd, &rcClient);

		// 	const int cParts = 1;

		//     // Allocate an array for holding the right edge coordinates.
		//     hloc = LocalAlloc(LHND, sizeof(int) * cParts);
		//     paParts = (PINT) LocalLock(hloc);

		//     // Calculate the right edge coordinate for each part, and
		//     // copy the coordinates to the array.
		//     nWidth = rcClient.right / cParts;
		//     int rightEdge = nWidth;
		//     for (i = 0; i < cParts; i++) {
		//        paParts[i] = rightEdge;
		//        rightEdge += nWidth;
		//     }

		//     // Tell the status bar to create the window parts.
		//     SendMessage(hwndStatus, SB_SETPARTS, (WPARAM) cParts, (LPARAM) paParts);

		//     // Free the array, and return.
		//     LocalUnlock(hloc);
		//     LocalFree(hloc);

		CHARFORMAT boldfont;

		boldfont.cbSize = sizeof(CHARFORMAT);
		boldfont.crTextColor = RGB(0, 0, 0);
		boldfont.dwMask = CFM_COLOR | CFM_SIZE | CFM_BOLD | CFM_CHARSET;
		boldfont.yHeight = 350;
		//boldfont.dwEffects = CFE_BOLD;			/* Text will be BOLD*/
		boldfont.bCharSet = DEFAULT_CHARSET;
		SendMessage(hwndEdit, EM_SETCHARFORMAT, SCF_ALL, (LPARAM)&boldfont);

		// SendMessage(hwndEdit, WM_SETTEXT, 0, (LPARAM)lpszLatin);
		SetFocus(hwndEdit);
		//SendMessage(hwndEdit, EM_SETFONTSIZE , 36, 0);
		// HWND hWndEdit = CreateWindowEx(WS_EX_CLIENTEDGE, TEXT("Edit"), TEXT("test"),
		//                             WS_CHILD | WS_VISIBLE, 0, 0, 140,
		//                             40, hwnd, NULL, NULL, NULL);
		hwndList = CreateWindowW(L"ListBox", NULL, WS_BORDER | WS_CHILD | WS_VISIBLE | LBS_NOTIFY,
								 0, edit_box_height, screen_w, screen_h - edit_box_height, hwnd,
								 (HMENU)IDC_LIST, NULL, NULL);



		LONG lExStyleList = GetWindowLong(hwndList, GWL_EXSTYLE);
lExStyleList &= ~WS_EX_CLIENTEDGE;
SetWindowLong(hwndList, GWL_EXSTYLE, lExStyleList);
		AutoResizeControls(hwnd, hwndEdit, hwndList, edit_box_height);

		//auto theme = "WINDOW";
		SetWindowTheme(hwnd, L"WINDOW", nullptr);



		CenterWindow(hwnd);
		break;
	}

	case WM_CONTEXTMENU:
	{
#define IDC_PASTE 102

		if ((HWND)wParam == hwndEdit)
		{
			auto m_hMenu = CreatePopupMenu();
			InsertMenu(m_hMenu, 0, MF_BYCOMMAND | MF_STRING | MF_ENABLED, IDC_PASTE, L"Paste");
			TrackPopupMenu(m_hMenu, TPM_TOPALIGN | TPM_LEFTALIGN, GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam), 0, hwnd, NULL);
		}
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
	case WM_SYSCOMMAND:
	{

		if (wParam == SC_MAXIMIZE || wParam == SC_RESTORE)
		{
			invalidUI = true;
		}
		break;
	}
	case WM_SIZING:
	{

		invalidUI = true;
		// SendMessage(hwndEdit, EM_WIDTH, SCF_ALL, (LPARAM)&boldfont);
		break;
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
	LoadLibrary(TEXT("Msftedit.dll"));
	

	MSG msg;
	HWND hwnd;
	WNDCLASSW wc;

	wc.style = CS_VREDRAW | CS_HREDRAW;

	wc.cbClsExtra = 0;
	wc.cbWndExtra = 0;
	wc.lpszClassName = L"Drill Window";
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

	auto dwStyle = GetWindowLong(hwnd, GWL_STYLE);
	dwStyle ^= WS_MAXIMIZEBOX;
	dwStyle ^= WS_SIZEBOX;
	SetWindowLong(hwnd, GWL_STYLE, dwStyle);

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
