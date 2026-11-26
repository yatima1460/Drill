use std::ffi::{c_void, CStr};

use raw_window_handle::{HasWindowHandle, RawWindowHandle};
use winit::{
    dpi::PhysicalSize,
    event_loop::ActiveEventLoop,
    window::{Window, WindowAttributes},
};

use crate::{HardwareAcceleration, NativeOptions, Result};

pub(in crate::native) use drill_macos::opengl::Surface;

pub(in crate::native) struct Backend {
    context: drill_macos::opengl::Context,
    transparent: bool,
    vsync: bool,
}

impl Backend {
    pub(in crate::native) fn new(
        egui_ctx: &egui::Context,
        viewport_builder: &egui::ViewportBuilder,
        options: &NativeOptions,
        event_loop: &ActiveEventLoop,
    ) -> Result<(Self, Option<Window>)> {
        let transparent = options.viewport.transparent.unwrap_or(false);
        let samples = options
            .multisampling
            .try_into()
            .map_err(|_| gl_error("multisampling option does not fit in u8"))?;
        let context = drill_macos::opengl::Context::new(
            options.depth_buffer,
            options.stencil_buffer,
            samples,
            matches!(
                options.hardware_acceleration,
                HardwareAcceleration::Required
            ),
            transparent,
        )
        .ok_or_else(|| gl_error("could not create an AppKit OpenGL context"))?;
        let backend = Self {
            context,
            transparent,
            vsync: options.vsync,
        };
        let attributes = egui_winit::create_winit_window_attributes(
            egui_ctx,
            event_loop,
            viewport_builder.clone(),
        );
        let window = backend.create_window(event_loop, attributes)?;
        egui_winit::apply_viewport_builder_to_window(egui_ctx, &window, viewport_builder);
        Ok((backend, Some(window)))
    }

    pub(in crate::native) fn create_window(
        &self,
        event_loop: &ActiveEventLoop,
        mut attributes: WindowAttributes,
    ) -> Result<Window> {
        if attributes.transparent() && !self.transparent {
            log::error!("Cannot create transparent window: the GL config does not support it");
            attributes = attributes.with_transparent(false);
        }
        Ok(event_loop.create_window(attributes)?)
    }

    #[allow(unsafe_code)]
    pub(in crate::native) fn attach(&mut self, window: &Window) -> Result<Surface> {
        let handle = window.window_handle().map_err(|error| {
            egui_glow::PainterError::from(format!("could not obtain the AppKit view: {error}"))
        })?;
        let RawWindowHandle::AppKit(handle) = handle.as_raw() else {
            return Err(gl_error("expected an AppKit view").into());
        };
        // SAFETY: The winit handle borrows its live AppKit view while this
        // initializes a retained reference. Glow's event loop runs on the main thread.
        let surface = unsafe { self.context.attach(handle.ns_view) }
            .ok_or_else(|| gl_error("could not attach the OpenGL drawable"))?;
        self.activate(&surface)?;
        surface.set_vsync(self.vsync);
        Ok(surface)
    }

    pub(in crate::native) fn activate(&mut self, surface: &Surface) -> Result {
        if surface.activate() {
            Ok(())
        } else {
            Err(gl_error("could not activate the AppKit OpenGL drawable").into())
        }
    }

    pub(in crate::native) fn resize(&mut self, surface: &Surface, _: PhysicalSize<u32>) -> Result {
        self.activate(surface)?;
        surface.resize();
        Ok(())
    }

    pub(in crate::native) fn swap(&self, surface: &Surface) -> Result {
        if surface.swap() {
            Ok(())
        } else {
            Err(gl_error("cannot present an inactive AppKit OpenGL drawable").into())
        }
    }

    pub(in crate::native) fn suspend(&mut self) -> Result {
        // Dropping each surface detaches its view before the winit window is released.
        Ok(())
    }

    pub(in crate::native) fn proc_address(&self, name: &CStr) -> *const c_void {
        drill_macos::opengl::Context::proc_address(name)
    }
}

fn gl_error(message: &str) -> egui_glow::PainterError {
    egui_glow::PainterError::from(message.to_owned())
}
