using System.Collections.Concurrent;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Windows.Input;

using Drill.Core;


namespace Drill;
public partial class MainPage : ContentPage
{

	private ConcurrentQueue<FileSystemInfo> ParallelResults = [];
	private ObservableCollection<DrillResult> Results { get; set; } = [];
	private string? ExceptionHappened;
	Task? currentSearchTask;
	bool stop;
	string currentSearchText = string.Empty;

	

	


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
				stop = true;
				if (currentSearchTask != null)
				{
					await currentSearchTask;
				}
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
		ResetContext();


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

	private void CollectionView_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            // Get the selected item
            FileSystemInfo selectedItem = e.CurrentSelection[0] as FileSystemInfo;

            // Display an alert with the selected item
            DisplayAlert("Item Selected", $"You selected: {selectedItem}", "OK");
        }

	protected override void OnAppearing()
	{
		base.OnAppearing();

		// Start the timer when the page appears
		Dispatcher.StartTimer(TimeSpan.FromMilliseconds(20), () =>
		{
			// Code to execute on each tick (every second in this case)
			// This code will execute on the UI thread
			// You can update UI elements or perform any other UI-related tasks here
			UpdateUI();

			// Return true to continue the timer, or false to stop it
			return ExceptionHappened == null;
		});


	}

	private async void UpdateUI()
	{
		// Check if any fatal exception happened
		if (ExceptionHappened != null)
		{
			await DisplayAlert("Fatal Error", ExceptionHappened.ToString(), "Quit");
			ExceptionHappened = null;
			
			Environment.Exit(1);
		}

		if (Results.Count > 100)
		{
			stop = true;
		}
		else
		{
			for (int i = 0; i < 10; i++)
			{
				if (ParallelResults.TryDequeue(out FileSystemInfo dequeued))
				{
					Results.Add(new DrillResult(dequeued));
					
				}
			}
		}
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
					Arguments = "\""+FullPath+"\""
				});
			}
			if (DeviceInfo.Current.Platform == DevicePlatform.WinUI)
			{
				Process.Start(new ProcessStartInfo
				{
					FileName = "explorer.exe",
					Arguments = "\""+FullPath+"\""
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
	private  void OpenPath_Internal(string FullPath)
	{
		try 
		{
			if (DeviceInfo.Current.Platform == DevicePlatform.MacCatalyst)
			{
				Process.Start(new ProcessStartInfo
				{
					FileName = "open",
					Arguments = "-R \""+FullPath+"\""
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

    private static bool TokenMatching(string searchString, string fileName)
	{
        string[] tokenizedSearchString = searchString.ToLower().Split(" ");
		foreach (string token in tokenizedSearchString)
		{
			if (!fileName.Contains(token, StringComparison.CurrentCultureIgnoreCase))
			{
				return false;
			}
		}
		return true;
	}

	private void ResetContext()
	{
		// Clear the results
		Results.Clear();
		ParallelResults.Clear();
		currentSearchTask = null;
		stop = false;

	}

	private List<string> blacklist = [
		"Photos Library.photoslibrary",
		".Trash",
	];

	DateTime lastTimeTextChanged = DateTime.UtcNow;


	

	private Timer? timer;

    private async void OnTextChanged(object sender, TextChangedEventArgs e)
	{
		/* This system is in place so the search starts only after a while the user stops writing
		 * It starts a timer, and if after X milliseconds there is no more OnTextChanged Drill will start searching
		 */
        if (timer != null)
		{
            timer.Change(Timeout.Infinite, Timeout.Infinite);
			timer.Dispose();
			timer = null;
        }
		timer = new Timer(TimerCallback, e.NewTextValue, 300, Timeout.Infinite);

		stop = false;
    }

 
	private void TimerCallback(object state)
	{
        string newText = (string)state;

        if (currentSearchText == newText)
        {
            return;
        }

        // Stop if there is a current search
        if (currentSearchTask != null)
        {
            stop = true;
			currentSearchTask.Wait();
        }

        ResetContext();
        currentSearchText = newText;
        if (currentSearchText == "")
        {
            return;
        }
        currentSearchTask = Task.Run(() =>
        {
            // string userFolderPath = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

            try
            {
                HashSet<string> visited = [];
                Queue<DirectoryInfo> directoriesToExplore = [];

                // DriveInfo[] drives = DriveInfo.GetDrives();
                // foreach (DriveInfo drive in drives)
                // {
                // 	string label = drive.IsReady ?
                // 	directoriesToExplore.Enqueue(drive.RootDirectory);
                // }


                directoriesToExplore.Enqueue(new DirectoryInfo(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile)));

                DriveInfo[] allDrives = DriveInfo.GetDrives();
                foreach (DriveInfo d in allDrives)
                {
                    if (d.IsReady == true && (d.DriveType == DriveType.Removable || d.DriveType == DriveType.Fixed || d.DriveType == DriveType.Network))
                    {
                        directoriesToExplore.Enqueue(d.RootDirectory);
                    }
                }

                while (stop == false && directoriesToExplore.Count != 0)
                {
                    DirectoryInfo rootFolderInfo = directoriesToExplore.Dequeue();

                    // To prevent loops
                    if (visited.Contains(rootFolderInfo.FullName))
                    {
                        continue;
                    }
                    visited.Add(rootFolderInfo.FullName);


                    try
                    {
                        FileSystemInfo[] subs = rootFolderInfo.GetFileSystemInfos("*", SearchOption.TopDirectoryOnly);
                        foreach (FileSystemInfo sub in subs)
                        {
                            if (TokenMatching(currentSearchText, sub.Name))
                            {
                                ParallelResults.Enqueue(sub);
                            }
                            if ((sub.Attributes & FileAttributes.Directory) == FileAttributes.Directory)
                            {
                                //if (!blacklist.Contains(sub.Name))
                                directoriesToExplore.Enqueue((DirectoryInfo)sub);
                            }
                        }
                    }
                    // We can't go deeper unless we are admins, skip it
                    catch (UnauthorizedAccessException uae)
                    {
                        continue;
                    }
                }

                currentSearchTask = null;
                stop = true;
            }
            catch (Exception e)
            {
                stop = true;
                ExceptionHappened = e.ToString().Replace("\n", " ");
            }
        });
    }



    // private void OnCounterClicked(object sender, EventArgs e)
    // {
    // 	count++;

    // 	if (count == 1)
    // 		CounterBtn.Text = $"Clicked {count} time";
    // 	else
    // 		CounterBtn.Text = $"Clicked {count} times";

    // 	SemanticScreenReader.Announce(CounterBtn.Text);
    // }
}

