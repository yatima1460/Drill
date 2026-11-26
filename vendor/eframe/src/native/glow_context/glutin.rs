use std::{
    ffi::{c_void, CStr},
    num::NonZeroU32,
};

use glutin::{
    config::GlConfig,
    context::NotCurrentGlContext,
    display::GetGlDisplay,
    prelude::{GlDisplay, PossiblyCurrentGlContext},
    surface::GlSurface,
};
use raw_window_handle::HasWindowHandle;
use winit::{
    dpi::PhysicalSize,
    event_loop::ActiveEventLoop,
    window::{Window, WindowAttributes},
};

use crate::{NativeOptions, Result};

pub(in crate::native) type Surface = glutin::surface::Surface<glutin::surface::WindowSurface>;

pub(in crate::native) struct Backend {
    swap_interval: glutin::surface::SwapInterval,
    gl_config: glutin::config::Config,
    current_gl_context: Option<glutin::context::PossiblyCurrentContext>,
    not_current_gl_context: Option<glutin::context::NotCurrentContext>,
}

impl Backend {
    #[allow(unsafe_code)]
    pub(in crate::native) fn new(
        egui_ctx: &egui::Context,
        viewport_builder: &egui::ViewportBuilder,
        native_options: &NativeOptions,
        event_loop: &ActiveEventLoop,
    ) -> Result<(Self, Option<Window>)> {
        // There is a lot of complexity with opengl creation,
        // so prefer extensive logging to get all the help we can to debug issues.

        // convert native options to glutin options
        let hardware_acceleration = match native_options.hardware_acceleration {
            crate::HardwareAcceleration::Required => Some(true),
            crate::HardwareAcceleration::Preferred => None,
            crate::HardwareAcceleration::Off => Some(false),
        };
        let swap_interval = if native_options.vsync {
            glutin::surface::SwapInterval::Wait(NonZeroU32::MIN)
        } else {
            glutin::surface::SwapInterval::DontWait
        };
        /*  opengl setup flow goes like this:
            1. we create a configuration for opengl "Display" / "Config" creation
            2. choose between special extensions like glx or egl or wgl and use them to create config/display
            3. opengl context configuration
            4. opengl context creation
        */
        // start building config for gl display
        let config_template_builder = glutin::config::ConfigTemplateBuilder::new()
            .prefer_hardware_accelerated(hardware_acceleration)
            .with_depth_size(native_options.depth_buffer)
            .with_stencil_size(native_options.stencil_buffer)
            .with_transparency(native_options.viewport.transparent.unwrap_or(false));
        // we don't know if multi sampling option is set. so, check if its more than 0.
        let config_template_builder = if native_options.multisampling > 0 {
            config_template_builder.with_multisampling(
                native_options
                    .multisampling
                    .try_into()
                    .expect("failed to fit multisamples option of native_options into u8"),
            )
        } else {
            config_template_builder
        };

        log::debug!("trying to create glutin Display with config: {config_template_builder:?}");

        // Create GL display. This may probably create a window too on most platforms. Definitely on `MS windows`. Never on Android.
        let display_builder = glutin_winit::DisplayBuilder::new()
            // we might want to expose this option to users in the future. maybe using an env var or using native_options.
            //
            // The justification for FallbackEgl over PreferEgl is at https://github.com/emilk/egui/pull/2526#issuecomment-1400229576 .
            .with_preference(glutin_winit::ApiPreference::FallbackEgl)
            .with_window_attributes(Some(egui_winit::create_winit_window_attributes(
                egui_ctx,
                event_loop,
                viewport_builder.clone(),
            )));

        let (window, gl_config) = {
            profiling::scope!("DisplayBuilder::build");

            display_builder
                .build(
                    event_loop,
                    config_template_builder.clone(),
                    |mut config_iterator| {
                        let config = config_iterator.next().expect(
                            "failed to find a matching configuration for creating glutin config",
                        );
                        log::debug!(
                            "using the first config from config picker closure. config: {config:?}"
                        );
                        config
                    },
                )
                .map_err(|e| crate::Error::NoGlutinConfigs(config_template_builder.build(), e))?
        };
        if let Some(window) = &window {
            egui_winit::apply_viewport_builder_to_window(egui_ctx, window, viewport_builder);
        }

        let gl_display = gl_config.display();
        log::debug!(
            "successfully created GL Display with version: {} and supported features: {:?}",
            gl_display.version_string(),
            gl_display.supported_features()
        );
        let glutin_raw_window_handle = window.as_ref().map(|w| {
            w.window_handle()
                .expect("Failed to get window handle")
                .as_raw()
        });
        log::debug!("creating gl context using raw window handle: {glutin_raw_window_handle:?}");

        // create gl context. if core context cannot be created, try gl es context as fallback.
        let context_attributes =
            glutin::context::ContextAttributesBuilder::new().build(glutin_raw_window_handle);
        let fallback_context_attributes = glutin::context::ContextAttributesBuilder::new()
            .with_context_api(glutin::context::ContextApi::Gles(None))
            .build(glutin_raw_window_handle);

        let gl_context_result = unsafe {
            profiling::scope!("create_context");
            gl_config
                .display()
                .create_context(&gl_config, &context_attributes)
        };

        let gl_context = match gl_context_result {
            Ok(it) => it,
            Err(err) => {
                log::warn!("Failed to create context using default context attributes {context_attributes:?} due to error: {err}");
                log::debug!(
                    "Retrying with fallback context attributes: {fallback_context_attributes:?}"
                );
                let fallback = unsafe {
                    gl_config
                        .display()
                        .create_context(&gl_config, &fallback_context_attributes)
                };
                #[cfg(target_os = "windows")]
                {
                    match fallback {
                        Ok(context) => context,
                        Err(error) => {
                            log::warn!("Failed to create OpenGL ES context: {error}; trying a desktop compatibility context");
                            let compatibility_attributes =
                                glutin::context::ContextAttributesBuilder::new()
                                    .with_profile(glutin::context::GlProfile::Compatibility)
                                    .build(glutin_raw_window_handle);
                            unsafe {
                                gl_config
                                    .display()
                                    .create_context(&gl_config, &compatibility_attributes)?
                            }
                        }
                    }
                }
                #[cfg(not(target_os = "windows"))]
                fallback?
            }
        };

        Ok((
            Self {
                swap_interval,
                gl_config,
                current_gl_context: None,
                not_current_gl_context: Some(gl_context),
            },
            window,
        ))
    }

    pub(in crate::native) fn create_window(
        &self,
        event_loop: &ActiveEventLoop,
        window_attributes: WindowAttributes,
    ) -> Result<Window> {
        if window_attributes.transparent() && self.gl_config.supports_transparency() == Some(false)
        {
            log::error!("Cannot create transparent window: the GL config does not support it");
        }
        Ok(glutin_winit::finalize_window(
            event_loop,
            window_attributes,
            &self.gl_config,
        )?)
    }

    #[allow(unsafe_code)]
    pub(in crate::native) fn attach(&mut self, window: &Window) -> Result<Surface> {
        // surface attributes
        let (width_px, height_px): (u32, u32) = window.inner_size().into();
        let width_px = NonZeroU32::new(width_px).unwrap_or(NonZeroU32::MIN);
        let height_px = NonZeroU32::new(height_px).unwrap_or(NonZeroU32::MIN);
        let surface_attributes = {
            glutin::surface::SurfaceAttributesBuilder::<glutin::surface::WindowSurface>::new()
                .build(
                    window
                        .window_handle()
                        .expect("Failed to get display handle")
                        .as_raw(),
                    width_px,
                    height_px,
                )
        };

        log::trace!("creating surface with attributes: {surface_attributes:?}");
        let gl_surface = unsafe {
            self.gl_config
                .display()
                .create_window_surface(&self.gl_config, &surface_attributes)?
        };

        log::trace!("surface created successfully: {gl_surface:?}. making context current");

        let not_current_gl_context =
            if let Some(not_current_context) = self.not_current_gl_context.take() {
                not_current_context
            } else {
                self.current_gl_context
                    .take()
                    .unwrap()
                    .make_not_current()
                    .unwrap()
            };
        let current_gl_context = not_current_gl_context.make_current(&gl_surface)?;

        // try setting swap interval. but its not absolutely necessary, so don't panic on failure.
        log::trace!("made context current. setting swap interval for surface");
        if let Err(err) = gl_surface.set_swap_interval(&current_gl_context, self.swap_interval) {
            log::warn!("Failed to set swap interval due to error: {err}");
        }

        self.current_gl_context = Some(current_gl_context);
        Ok(gl_surface)
    }

    pub(in crate::native) fn activate(&mut self, surface: &Surface) -> Result {
        profiling::function_scope!();

        if !cfg!(target_os = "windows") {
            // According to https://github.com/emilk/egui/issues/4289
            // we cannot do this early-out on Windows.
            // TODO(emilk): optimize context switching on Windows too.
            // See https://github.com/emilk/egui/issues/4173

            if let Some(current_gl_context) = &self.current_gl_context {
                profiling::scope!("is_current");
                if surface.is_current(current_gl_context) {
                    return Ok(()); // Early-out to save a lot of time.
                }
            }
        }

        let not_current = if let Some(not_current_context) = self.not_current_gl_context.take() {
            not_current_context
        } else {
            profiling::scope!("make_not_current");
            self.current_gl_context
                .take()
                .expect("no OpenGL context")
                .make_not_current()?
        };

        profiling::scope!("make_current");
        self.current_gl_context = Some(not_current.make_current(surface)?);
        Ok(())
    }

    pub(in crate::native) fn swap(&self, surface: &Surface) -> Result {
        let context = self.current_gl_context.as_ref().ok_or_else(|| {
            egui_glow::PainterError::from(
                "failed to get current context to swap buffers".to_owned(),
            )
        })?;
        surface.swap_buffers(context)?;
        Ok(())
    }

    pub(in crate::native) fn resize(
        &mut self,
        surface: &Surface,
        size: PhysicalSize<u32>,
    ) -> Result {
        let width = NonZeroU32::new(size.width).unwrap_or(NonZeroU32::MIN);
        let height = NonZeroU32::new(size.height).unwrap_or(NonZeroU32::MIN);
        self.activate(surface)?;
        surface.resize(
            self.current_gl_context.as_ref().expect("no OpenGL context"),
            width,
            height,
        );
        Ok(())
    }

    pub(in crate::native) fn suspend(&mut self) -> Result {
        if let Some(current) = self.current_gl_context.take() {
            self.not_current_gl_context = Some(current.make_not_current()?);
        }
        Ok(())
    }

    pub(in crate::native) fn proc_address(&self, addr: &CStr) -> *const c_void {
        self.gl_config.display().get_proc_address(addr)
    }
}
