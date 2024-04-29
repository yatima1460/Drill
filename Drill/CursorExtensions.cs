
#if __APPLE__
using AppKit;
using UIKit;
#endif

using Microsoft.Maui.Platform;

#if __WINDOWS__
//using Microsoft.UI.Input;
//using Microsoft.UI.Xaml.Input;
//using Microsoft.UI.Xaml;
//using System.Reflection;
//using Windows.UI.Core;
#endif


public enum CursorIcon
{
    Wait,
    Pointer,
    Hand,
    Arrow,
    IBeam,
    Cross,
    SizeAll
}


public static class CursorExtensions
{


#if __OSX__
    public static void SetCustomCursor(this VisualElement visualElement, CursorIcon cursor, IMauiContext? mauiContext)
    {
        ArgumentNullException.ThrowIfNull(mauiContext);


        var view = visualElement.ToPlatform(mauiContext);
        if (view.GestureRecognizers is not null)
        {
            foreach (var recognizer in view.GestureRecognizers.OfType<PointerUIHoverGestureRecognizer>())
            {
                view.RemoveGestureRecognizer(recognizer);
            }
        }

        view.AddGestureRecognizer(new PointerUIHoverGestureRecognizer(r =>
        {
            switch (r.State)
            {
                case UIKit.UIGestureRecognizerState.Began:
                    GetNSCursor(cursor).Set();
                    break;
                case UIKit.UIGestureRecognizerState.Ended:
                    AppKit.NSCursor.ArrowCursor.Set();
                    break;
            }
        }));
    }

    static AppKit.NSCursor GetNSCursor(CursorIcon cursor)
    {
        return cursor switch
        {
            CursorIcon.Hand => AppKit.NSCursor.PointingHandCursor,
            CursorIcon.IBeam => AppKit.NSCursor.IBeamCursor,
            CursorIcon.Cross => AppKit.NSCursor.CrosshairCursor,
            CursorIcon.Arrow => AppKit.NSCursor.ArrowCursor,
            CursorIcon.SizeAll => AppKit.NSCursor.ResizeUpCursor,
            CursorIcon.Wait => AppKit.NSCursor.OperationNotAllowedCursor,
            _ => AppKit.NSCursor.ArrowCursor,
        };
    }
   
    class PointerUIHoverGestureRecognizer : UIKit.UIHoverGestureRecognizer
    {
        public PointerUIHoverGestureRecognizer(Action<UIKit.UIHoverGestureRecognizer> action) : base(action)
        {
        }
    }
#elif __WINDOWS__
    //public static void SetCustomCursor(this VisualElement visualElement, CursorIcon cursor, IMauiContext? mauiContext)
    //{
    //    ArgumentNullException.ThrowIfNull(mauiContext);
    //    UIElement view = visualElement.ToPlatform(mauiContext);
    //    view.PointerEntered += ViewOnPointerEntered;
    //    view.PointerExited += ViewOnPointerExited;
    //    void ViewOnPointerExited(object sender, PointerRoutedEventArgs e)
    //    {
    //        view.ChangeCursor(InputCursor.CreateFromCoreCursor(new CoreCursor(GetCursor(CursorIcon.Arrow), 1)));
    //    }

    //    void ViewOnPointerEntered(object sender, PointerRoutedEventArgs e)
    //    {
    //        view.ChangeCursor(InputCursor.CreateFromCoreCursor(new CoreCursor(GetCursor(cursor), 1)));
    //    }
    //}

    //static void ChangeCursor(this UIElement uiElement, InputCursor cursor)
    //{
    //    Type type = typeof(UIElement);
    //    type.InvokeMember("ProtectedCursor", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.SetProperty | BindingFlags.Instance, null, uiElement, new object[] { cursor });
    //}

    //static CoreCursorType GetCursor(CursorIcon cursor)
    //{
    //    return cursor switch
    //    {
    //        CursorIcon.Hand => CoreCursorType.Hand,
    //        CursorIcon.IBeam => CoreCursorType.IBeam,
    //        CursorIcon.Cross => CoreCursorType.Cross,
    //        CursorIcon.Arrow => CoreCursorType.Arrow,
    //        CursorIcon.SizeAll => CoreCursorType.SizeAll,
    //        CursorIcon.Wait => CoreCursorType.Wait,
    //        _ => CoreCursorType.Arrow,
    //    };
    //}
    public static void SetCustomCursor(this VisualElement visualElement, CursorIcon cursor, IMauiContext? mauiContext)
    {
        ArgumentNullException.ThrowIfNull(mauiContext);
    }
#else
#warning Platform not supported to set custom cursor
    public static void SetCustomCursor(this VisualElement visualElement, CursorIcon cursor, IMauiContext? mauiContext)
    {
        ArgumentNullException.ThrowIfNull(mauiContext);
    }
#endif

}
