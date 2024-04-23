using System.Collections.Concurrent;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Windows.Input;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System;
using System.Windows.Input;

using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Diagnostics;
using System;
using System.Windows.Input;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Diagnostics;

public partial class MainPageViewModel : INotifyPropertyChanged
{

  
    public ICommand TapCommand => new Command<string>(async (url) => await Launcher.OpenAsync(url));

    #region INotifyPropertyChanged 
		public event PropertyChangedEventHandler PropertyChanged;

		protected virtual void OnPropertyChanged ([CallerMemberName] string propertyName = null)
		{
			PropertyChangedEventHandler handler = PropertyChanged;
			if (handler != null)
				handler (this, new PropertyChangedEventArgs (propertyName));
		}
		#endregion
}
