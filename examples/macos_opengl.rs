//! Runs a real macOS window without generating keyboard or pointer events.
//! Use `cargo run --locked --features macos-egui --example macos_opengl` on a GUI session.

#[cfg(target_os = "macos")]
#[path = "../crates/drill-core/src/test_directory.rs"]
mod test_directory;

fn main() {
    #[cfg(target_os = "macos")]
    probe::run();
    #[cfg(not(target_os = "macos"))]
    eprintln!("The native OpenGL probe requires a macOS GUI session");
}

#[cfg(target_os = "macos")]
mod probe {
    use std::{
        sync::{
            atomic::{AtomicUsize, Ordering},
            Arc,
        },
        time::Duration,
    };

    use eframe::{egui, egui_glow, glow};
    use glow::HasContext as _;

    fn paint_probe(ctx: &egui::Context, color: egui::Color32, count: &Arc<AtomicUsize>) {
        let count = Arc::clone(count);
        let pixels_per_point = ctx.native_pixels_per_point().expect("window scale");
        assert!(pixels_per_point >= 1.0);
        let expected_point_size = ctx.screen_rect().size();
        egui::CentralPanel::default()
            .frame(egui::Frame::NONE.fill(color))
            .show(ctx, |ui| {
                ui.painter().add(egui::PaintCallback {
                    rect: ui.max_rect(),
                    callback: Arc::new(egui_glow::CallbackFn::new(move |info, painter| {
                        assert!((info.pixels_per_point - pixels_per_point).abs() < 0.01);
                        let expected_px = expected_point_size * pixels_per_point;
                        assert!((info.screen_size_px[0] as f32 - expected_px.x).abs() < 2.0);
                        assert!((info.screen_size_px[1] as f32 - expected_px.y).abs() < 2.0);
                        let gl = painter.gl();
                        let mut pixel = [0_u8; 4];
                        // SAFETY: The painter callback runs with a current context and a
                        // single RGBA pixel fits the four-byte output buffer.
                        unsafe {
                            gl.read_pixels(
                                info.screen_size_px[0] as i32 / 2,
                                info.screen_size_px[1] as i32 / 2,
                                1,
                                1,
                                glow::RGBA,
                                glow::UNSIGNED_BYTE,
                                glow::PixelPackData::Slice(Some(&mut pixel)),
                            );
                            assert_eq!(gl.get_error(), glow::NO_ERROR);
                        }
                        let target = color.to_array();
                        assert!(
                            pixel[..3]
                                .iter()
                                .zip(target[..3].iter())
                                .all(|(&a, &b)| a.abs_diff(b) < 8),
                            "read {pixel:?}, expected {target:?}"
                        );
                        let prior = count.fetch_add(1, Ordering::Relaxed);
                        if prior == 0 {
                            let [w, h] = info.screen_size_px;
                            println!("painted and read back {w}×{h} at {pixels_per_point}× scale");
                        }
                    })),
                });
            });
    }

    #[derive(Clone, Copy, Debug, PartialEq, Eq)]
    enum Stage {
        FirstChild,
        CloseChildAndResize,
        ReopenChild,
        WaitForScreenshot,
        Done,
    }

    struct Probe {
        stage: Stage,
        root: Arc<AtomicUsize>,
        child: Arc<AtomicUsize>,
        reopened: Arc<AtomicUsize>,
        exited: Arc<AtomicUsize>,
    }

    impl eframe::App for Probe {
        fn update(&mut self, ctx: &egui::Context, _: &mut eframe::Frame) {
            let child_id = egui::ViewportId::from_hash_of("secondary");
            let child_known = ctx.input(|input| input.raw.viewports.contains_key(&child_id));
            match self.stage {
                Stage::FirstChild if self.child.load(Ordering::Relaxed) > 0 && child_known => {
                    ctx.send_viewport_cmd(egui::ViewportCommand::InnerSize(egui::vec2(
                        447.0, 313.0,
                    )));
                    self.stage = Stage::CloseChildAndResize;
                }
                Stage::CloseChildAndResize
                    if !child_known && (ctx.screen_rect().width() - 447.0).abs() < 1.0 =>
                {
                    self.stage = Stage::ReopenChild;
                }
                Stage::ReopenChild if self.reopened.load(Ordering::Relaxed) > 0 => {
                    ctx.send_viewport_cmd(egui::ViewportCommand::Screenshot(
                        egui::UserData::default(),
                    ));
                    self.stage = Stage::WaitForScreenshot;
                }
                Stage::WaitForScreenshot => {
                    if let Some(image) = ctx.input(|input| {
                        input.events.iter().find_map(|event| match event {
                            egui::Event::Screenshot { image, .. } => Some(Arc::clone(image)),
                            _ => None,
                        })
                    }) {
                        let scale = ctx.native_pixels_per_point().unwrap();
                        let expected = (447.0 * scale).round() as usize;
                        assert_eq!(image.width(), expected);
                        assert!(self.root.load(Ordering::Relaxed) >= 3);
                        println!("verified resized root screenshot after re-opening child");
                        self.stage = Stage::Done;
                        ctx.send_viewport_cmd(egui::ViewportCommand::Close);
                    }
                }
                _ => {}
            }
            let child = match self.stage {
                Stage::FirstChild => Some(([230.0, 170.0], egui::Color32::GREEN, &self.child)),
                Stage::ReopenChild => Some(([260.0, 185.0], egui::Color32::RED, &self.reopened)),
                _ => None,
            };
            if let Some((size, color, counter)) = child {
                ctx.show_viewport_immediate(
                    child_id,
                    egui::ViewportBuilder::default()
                        .with_title("Drill OpenGL secondary probe")
                        .with_inner_size(size)
                        .with_active(false),
                    |ctx, class| {
                        assert!(matches!(class, egui::ViewportClass::Immediate));
                        paint_probe(ctx, color, counter);
                    },
                );
            }
            paint_probe(ctx, egui::Color32::BLUE, &self.root);
            ctx.request_repaint_after(Duration::from_millis(20));
        }

        fn on_exit(&mut self, gl: Option<&glow::Context>) {
            assert_eq!(self.stage, Stage::Done);
            let gl = gl.expect("a current OpenGL context during teardown");
            // SAFETY: eframe makes the live root context current before on_exit.
            assert!(!unsafe { gl.get_parameter_string(glow::VERSION) }.is_empty());
            self.exited.fetch_add(1, Ordering::Relaxed);
        }
    }

    pub(super) fn run() {
        let directory = super::test_directory::private_temp_dir();
        let options = eframe::NativeOptions {
            viewport: egui::ViewportBuilder::default()
                .with_inner_size([403.0, 277.0])
                .with_active(false),
            persist_window: false,
            persistence_path: Some(directory.path().join("opengl-probe.ron")),
            vsync: !std::env::args().any(|arg| arg == "--no-vsync"),
            ..Default::default()
        };
        let (finished, wait) = std::sync::mpsc::channel::<()>();
        let watchdog = std::thread::spawn(move || {
            if wait.recv_timeout(Duration::from_secs(20)).is_err() {
                eprintln!("The native OpenGL probe did not finish in 20 seconds");
                std::process::exit(124);
            }
        });
        let exited = Arc::new(AtomicUsize::new(0));
        let exited_in_app = Arc::clone(&exited);
        eframe::run_native(
            "Drill OpenGL probe",
            options,
            Box::new(move |creation| {
                let gl = creation.gl.as_ref().expect("OpenGL renderer");
                // SAFETY: Creation runs with the root OpenGL drawable current.
                println!("OpenGL {}", unsafe {
                    gl.get_parameter_string(glow::VERSION)
                });
                Ok(Box::new(Probe {
                    stage: Stage::FirstChild,
                    root: Arc::default(),
                    child: Arc::default(),
                    reopened: Arc::default(),
                    exited: exited_in_app,
                }))
            }),
        )
        .unwrap();
        assert_eq!(exited.load(Ordering::Relaxed), 1);
        finished.send(()).unwrap();
        watchdog.join().unwrap();
    }
}
