use std::{
    ffi::{c_void, CStr},
    ptr::NonNull,
    rc::Rc,
};

unsafe extern "C" {
    fn drill_gl_context(
        depth: u8,
        stencil: u8,
        samples: u8,
        accelerated: bool,
        transparent: bool,
    ) -> *mut c_void;
    fn drill_gl_free_context(context: *mut c_void);
    fn drill_gl_surface(view: *mut c_void) -> *mut c_void;
    fn drill_gl_free_surface(context: *mut c_void, view: *mut c_void);
    fn drill_gl_activate(context: *mut c_void, view: *mut c_void) -> bool;
    fn drill_gl_update(context: *mut c_void);
    fn drill_gl_swap(context: *mut c_void, view: *mut c_void) -> bool;
    fn drill_gl_vsync(context: *mut c_void, vsync: bool);
    fn drill_gl_symbol(name: *const std::ffi::c_char) -> *const c_void;
}

pub struct Context(Rc<ContextHandle>);

struct ContextHandle(NonNull<c_void>);

impl Drop for ContextHandle {
    fn drop(&mut self) {
        // SAFETY: This is the unique owner of the context. The surrounding Rc
        // keeps release on the creating thread and after all its surfaces.
        unsafe { drill_gl_free_context(self.0.as_ptr()) };
    }
}

pub struct Surface {
    context: Rc<ContextHandle>,
    view: NonNull<c_void>,
}

impl Context {
    pub fn new(
        depth: u8,
        stencil: u8,
        samples: u8,
        accelerated: bool,
        transparent: bool,
    ) -> Option<Self> {
        // SAFETY: The native function validates the main thread and returns an
        // owned AppKit context, or a null pointer on failure.
        let handle = unsafe { drill_gl_context(depth, stencil, samples, accelerated, transparent) };
        Some(Self(Rc::new(ContextHandle(NonNull::new(handle)?))))
    }

    /// Retains the native view and prepares its window drawable.
    ///
    /// # Safety
    ///
    /// The caller must supply a live AppKit NSView attached to a window on the
    /// current (main) thread.
    pub unsafe fn attach(&self, view: NonNull<c_void>) -> Option<Surface> {
        // SAFETY: The caller guarantees a live NSView on the main thread.
        let view = unsafe { drill_gl_surface(view.as_ptr()) };
        Some(Surface {
            context: Rc::clone(&self.0),
            view: NonNull::new(view)?,
        })
    }

    pub fn proc_address(name: &CStr) -> *const c_void {
        // SAFETY: The native function borrows the valid C string only for this call.
        unsafe { drill_gl_symbol(name.as_ptr()) }
    }
}

impl Surface {
    pub fn activate(&self) -> bool {
        // SAFETY: Both retained AppKit objects belong to this main thread.
        unsafe { drill_gl_activate(self.context.0.as_ptr(), self.view.as_ptr()) }
    }

    /// Updates the drawable for the currently active surface.
    pub fn resize(&self) {
        // SAFETY: The retained context is used on its creating thread.
        unsafe { drill_gl_update(self.context.0.as_ptr()) };
    }

    /// Presents this surface if it is currently active.
    pub fn swap(&self) -> bool {
        // SAFETY: Both retained AppKit objects belong to this main thread.
        unsafe { drill_gl_swap(self.context.0.as_ptr(), self.view.as_ptr()) }
    }

    pub fn set_vsync(&self, vsync: bool) {
        // SAFETY: The retained context is used on its creating thread.
        unsafe { drill_gl_vsync(self.context.0.as_ptr(), vsync) };
    }
}

impl Drop for Surface {
    fn drop(&mut self) {
        // SAFETY: This is the unique owner of the native view reference, and
        // it keeps the context alive until the native call detaches the view.
        unsafe { drill_gl_free_surface(self.context.0.as_ptr(), self.view.as_ptr()) };
    }
}
