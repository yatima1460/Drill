using System.Collections.Concurrent;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Windows.Input;

using Drill.Backend;


namespace Drill;
public partial class MainPage : ContentPage
{

    /// <summary>
    /// Collection that is read by the UI showing the results
    /// </summary>
    private readonly ObservableCollection<DrillResult> Results = [];


    Task? currentSearchTask;


    private static void ErrorCallbackBlackhole(Exception e)
    {

    }

    private void OnPointerEntered(object? sender, PointerEventArgs e)
    {
        ((Label)sender!)!.TextDecorations = TextDecorations.Underline;
        if (sender is VisualElement visualElement)
        {
            visualElement.SetCustomCursor(CursorIcon.Pointer, Application.Current?.MainPage?.Handler?.MauiContext);
        }
    }

    private void OnPointerExited(object? sender, PointerEventArgs e)
    {
        ((Label)sender!)!.TextDecorations = TextDecorations.None;

        if (sender is VisualElement visualElement)
        {
            visualElement.SetCustomCursor(CursorIcon.Arrow, Application.Current?.MainPage?.Handler?.MauiContext);
        }

    }
    private async void OnBackButtonPressed(object sender, EventArgs e)
    {
        // Close the application when the escape key is pressed
        if (e is BackButtonPressedEventArgs args && args.Handled == false)
        {
            args.Handled = true; // Mark the event as handled to prevent further processing

            // Close the application
            // You can use different methods to close the application based on your platform and requirements
            // For example, you can use App.Current.Exit() in a .NET MAUI app
            
            Search.Stop();
            Application.Current.Quit();
        }
    }


    void OnNameTapped(object sender, EventArgs args)
    {
        var spanSender = (Span)sender;
        var fullPath = spanSender.BindingContext as string; // Assuming FullPath is of type string

        OpenFilePath(fullPath);
    }
    public MainPage()
    {
        InitializeComponent();

        BindingContext = this;

        UI_Results.ItemsSource = Results;
        


        timer = new(TimerCallback, null, Timeout.Infinite, Timeout.Infinite);
    }

    private static void OpenFilePath(string FullPath)
    {
        // Open the directory
        if (DeviceInfo.Current.Platform == DevicePlatform.MacCatalyst)
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = FullPath,
                UseShellExecute = true,
                Verb = "open"
            });
        }
        else if (DeviceInfo.Current.Platform == DevicePlatform.WinUI)
        {

        }

    }

    private void PathTapped(object sender, System.EventArgs e)
    {
        if (sender is Label label)
        {
            string directoryPath = label.Text;


            // Check if the directory path is valid
            if (Directory.Exists(directoryPath))
            {
                // Open the directory
                Process.Start(new ProcessStartInfo
                {
                    FileName = directoryPath,
                    UseShellExecute = true,
                    Verb = "open"
                });
            }
            else
            {
                // Handle invalid directory path
                // You can show an error message or take appropriate action
            }
        }
    }

    protected override void OnAppearing()
    {
        base.OnAppearing();

        timer = new Timer(TimerCallback, null, Timeout.Infinite, Timeout.Infinite);

        Dispatcher.StartTimer(TimeSpan.FromMilliseconds(100), () =>
        {
            var results = Search.PopResults(100);
            foreach (var item in results)
            {
                // FIXME: this may crash stuff
                // stop this timer when [X] is pressed or application closing in general
                Results.Add(item);
            }


            return true;
        });
    }


    // Launcher.OpenAsync is provided by Essentials.
    // public ICommand TapCommand => new Command<string>(async (url) => await Launcher.OpenAsync(url));
    // public ICommand TapCommand => new Command<string>(async (url) => OpenFilePath(url));
    public ICommand OpenFile => new Command<string>(async (url) => OpenFile_Internal(url));

    public ICommand OpenPath => new Command<string>(async (url) => OpenPath_Internal(url));


    /// <summary>
    /// Opens the file provided
    /// </summary>
    /// <param name="FullPath"></param>
    private void OpenFile_Internal(string FullPath)
    {
        try
        {
            if (DeviceInfo.Current.Platform == DevicePlatform.MacCatalyst)
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = "open",
                    Arguments = "\"" + FullPath + "\""
                });
            }
            if (DeviceInfo.Current.Platform == DevicePlatform.WinUI)
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = "explorer.exe",
                    Arguments = "\"" + FullPath + "\""
                });
            }
        }
        catch (Exception e)
        {
            DisplayAlert("Error opening file", "FullPath: " + FullPath + "\n" + e.ToString(), "OK");
        }
    }

    /// <summary>
    /// Opens the local system file explorer to the folder containing the file provided and if supported selects it
    /// </summary>
    /// <param name="FullPath"></param>
    private void OpenPath_Internal(string FullPath)
    {
        try
        {
            if (DeviceInfo.Current.Platform == DevicePlatform.MacCatalyst)
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = "open",
                    Arguments = "-R \"" + FullPath + "\""
                });
            }
            if (DeviceInfo.Current.Platform == DevicePlatform.WinUI)
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = "explorer.exe",
                    Arguments = string.Format("/select,\"{0}\"", FullPath)
                });
            }
        }
        catch (Exception e)
        {
            DisplayAlert("Error opening path", "FullPath: " + FullPath + "\n" + e.ToString(), "OK");
        }

    }




    private List<string> blacklist = [
        "Photos Library.photoslibrary",
        ".Trash",
    ];

    DateTime lastTimeTextChanged = DateTime.UtcNow;


    double Progress = 0.4;

    private Timer timer;

    private  void OnTextChanged(object sender, TextChangedEventArgs e)
    {
        // Stop current search
        Search.Stop();

        // Clear UI list
        Results.Clear();

        // Create new search
        Search.StartAsync(e.NewTextValue, ErrorCallback);
    }


    internal void ErrorCallback(Exception e)
    {
        Dispatcher.DispatchAsync(() =>
        {
            DisplayAlert("Fatal Error", e.ToString().Replace("\n", ";"), "Quit");
            Environment.Exit(1);
            return false;
        });
    }

    private void TimerCallback(object state)
    {
        string newText = (string)state;

        
    }
}

