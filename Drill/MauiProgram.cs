using Microsoft.Extensions.Logging;
using Microsoft.Maui.LifecycleEvents;
using Microsoft.Maui.Platform;

namespace Drill;

public static class MauiProgram
{
	public static MauiApp CreateMauiApp()
	{
		var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .ConfigureFonts(fonts =>
            {
                fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
                fonts.AddFont("OpenSans-Semibold.ttf", "OpenSansSemibold");
            })
            .ConfigureLifecycleEvents(events =>
            {
#if WINDOWS
                events.AddWindows(windowsLifecycleBuilder =>
                {
                    windowsLifecycleBuilder.OnWindowCreated(window =>
                    {
                        var handle = WinRT.Interop.WindowNative.GetWindowHandle(window);
                        var id = Microsoft.UI.Win32Interop.GetWindowIdFromWindow(handle);
                        var appWindow = Microsoft.UI.Windowing.AppWindow.GetFromWindowId(id);
                        var titleBar = appWindow.TitleBar;                  
                        //titleBar.BackgroundColor = Colors.Black.ToWindowsColor();
                        //titleBar.ButtonBackgroundColor = Colors.Black.ToWindowsColor();
                        //titleBar.InactiveBackgroundColor = Colors.Black.ToWindowsColor();
                        //titleBar.ButtonInactiveBackgroundColor = Colors.Black.ToWindowsColor();
                        titleBar.IconShowOptions = Microsoft.UI.Windowing.IconShowOptions.ShowIconAndSystemMenu;
                    });
                });
#endif
            });




#if DEBUG
		builder.Logging.AddDebug();
#endif

		return builder.Build();
	}
}
