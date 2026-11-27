#![cfg(target_os = "linux")]
#![deny(unsafe_code)]

#[cfg(test)]
#[allow(unsafe_code)]
mod desktop_theme;
#[allow(unsafe_code)]
pub mod linux_app_catalog;
