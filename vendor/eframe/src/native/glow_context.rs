//! Native drawable operations for the shared Glow renderer.

#[cfg(not(target_os = "macos"))]
mod glutin;
#[cfg(target_os = "macos")]
mod macos;

#[cfg(not(target_os = "macos"))]
pub(super) use glutin::{Backend, Surface};
#[cfg(target_os = "macos")]
pub(super) use macos::{Backend, Surface};
