using System.Collections.ObjectModel;
using System.Windows.Input;
using Drill.Core;


namespace Drill;
public partial class MainPage : ContentPage
{



    /// <summary>
    /// Collection that is read by the UI showing the results
    /// </summary>

    public ObservableCollection<DrillResult> Results { get; set; } = [];

    private Search currentSearch;


    public MainPage()
    {
        InitializeComponent();

        BindingContext = this;

        currentSearch = new Search("");

    }



    protected override void OnAppearing()
    {
        base.OnAppearing();

        Dispatcher.StartTimer(TimeSpan.FromMilliseconds(100), () =>
        {
            var results = currentSearch.PopResults(Results.Count < 30 ? 30 : 5);
            foreach (var item in results)
            {
                // FIXME: this may crash stuff
                // stop this timer when [X] is pressed or application closing in general
                Results.Add(item);
            }

            return true;
        });
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


    public ICommand OpenFile => new Command<string>(
        execute: FullPath =>
        {
            try
            {
                Drill.IO.OpenFile(FullPath);
            }
            catch (Exception e)
            {
                DisplayAlert("Error opening file", "FullPath: " + FullPath + "\n" + e.ToString(), "OK");
            }
        }
    );
    
    public ICommand OpenPath => new Command<string>(
        execute: fullPath =>
        {
            try
            {
                Drill.IO.OpenPath(fullPath);
            }
            catch (Exception e)
            {
                DisplayAlert("Error opening file", "FullPath: " + fullPath + "\n" + e.ToString(), "OK");
            }
        }
    );

 

    private List<string> blacklist = [
        "Photos Library.photoslibrary",
        ".Trash",
    ];

    DateTime lastTimeTextChanged = DateTime.UtcNow;


    double Progress = 0.4;



    private  void OnTextChanged(object sender, TextChangedEventArgs e)
    {
        // Stop current search
        currentSearch.Stop();

        // Clear UI list
        Results.Clear();

        // Create new search
        currentSearch = new Search(e.NewTextValue);
        currentSearch.StartAsync(ErrorCallback);
    }


    private void ErrorCallback(Exception e)
    {
        Dispatcher.DispatchAsync(() =>
        {
            DisplayAlert("Fatal Error", e.ToString().Replace("\n", ";"), "Quit");
            Environment.Exit(1);
            return false;
        });
    }

}

