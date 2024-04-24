using Microsoft.Maui.Platform;

#if __APPLE__
using AppKit;
using UIKit;
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
    public static void SetCustomCursor(this VisualElement visualElement, CursorIcon cursor, IMauiContext? mauiContext)
    {
        ArgumentNullException.ThrowIfNull(mauiContext);

        #if __APPLE__
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
                case UIGestureRecognizerState.Began:
                    GetNSCursor(cursor).Set();
                    break;
                case UIGestureRecognizerState.Ended:
                    NSCursor.ArrowCursor.Set();
                    break;
            }
        }));
        #endif
    }

    #if __APPLE__
    static NSCursor GetNSCursor(CursorIcon cursor)
    {
        return cursor switch
        {
            CursorIcon.Hand => NSCursor.OpenHandCursor,
            CursorIcon.Pointer => NSCursor.PointingHandCursor,
            CursorIcon.IBeam => NSCursor.IBeamCursor,
            CursorIcon.Cross => NSCursor.CrosshairCursor,
            CursorIcon.Arrow => NSCursor.ArrowCursor,
            CursorIcon.SizeAll => NSCursor.ResizeUpCursor,
            CursorIcon.Wait => NSCursor.OperationNotAllowedCursor,
            _ => NSCursor.ArrowCursor,
        };
    }
   
    class PointerUIHoverGestureRecognizer : UIHoverGestureRecognizer
    {
        public PointerUIHoverGestureRecognizer(Action<UIHoverGestureRecognizer> action) : base(action)
        {
        }
    }
     #endif

}