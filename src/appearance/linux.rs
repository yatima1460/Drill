use eframe::egui::{Context, Theme};
use gio::prelude::*;
use gtk::{gio, glib};
use std::{
    cell::Cell,
    collections::HashMap,
    rc::Rc,
    sync::{Arc, Mutex},
    thread,
};

const PORTAL: &str = "org.freedesktop.portal.Desktop";
const PATH: &str = "/org/freedesktop/portal/desktop";
const SETTINGS: &str = "org.freedesktop.portal.Settings";
const APPEARANCE: &str = "org.freedesktop.appearance";
const KEY: &str = "color-scheme";

pub(crate) struct DesktopTheme {
    value: Arc<Mutex<Option<Theme>>>,
    stop: gio::Cancellable,
}

impl DesktopTheme {
    pub(crate) fn new(ctx: Context) -> Self {
        let value = Arc::new(Mutex::new(None));
        let stop = gio::Cancellable::new();
        let cache = value.clone();
        let cancel = stop.clone();
        let _ = thread::Builder::new()
            .name("drill-desktop-theme".into())
            .spawn(move || {
                glib::MainContext::new().block_on(async {
                    let Ok(address) =
                        gio::dbus_address_get_for_bus_sync(gio::BusType::Session, Some(&cancel))
                    else {
                        return;
                    };
                    // A private connection can disappear without terminating the desktop app.
                    let Ok(bus) = gio::DBusConnection::for_address_sync(
                        &address,
                        gio::DBusConnectionFlags::AUTHENTICATION_CLIENT
                            | gio::DBusConnectionFlags::MESSAGE_BUS_CONNECTION,
                        None::<&gio::DBusAuthObserver>,
                        Some(&cancel),
                    ) else {
                        return;
                    };
                    observe(&bus, ctx, cache, &cancel).await;
                });
            });
        Self { value, stop }
    }

    pub(crate) fn current(&self) -> Option<Theme> {
        *self.value.lock().unwrap()
    }
}
impl Drop for DesktopTheme {
    fn drop(&mut self) {
        self.stop.cancel();
    }
}

fn theme(value: &glib::Variant) -> Option<Theme> {
    // The portal treats unknown numbers as no preference. Drill uses light for that case.
    Some(Theme::from_dark_mode(value.get::<u32>()? == 1))
}

fn read_all(reply: &glib::Variant) -> Option<Theme> {
    type Settings = HashMap<String, HashMap<String, glib::Variant>>;
    let (settings,) = reply.get::<(Settings,)>()?;
    theme(settings.get(APPEARANCE)?.get(KEY)?)
}

fn changed(params: &glib::Variant) -> Option<Option<Theme>> {
    let (namespace, key, value) = params.get::<(String, String, glib::Variant)>()?;
    (namespace == APPEARANCE && key == KEY).then(|| theme(&value))
}

async fn observe(
    bus: &gio::DBusConnection,
    ctx: Context,
    cache: Arc<Mutex<Option<Theme>>>,
    stop: &gio::Cancellable,
) {
    let publish = move |value| {
        let mut previous = cache.lock().unwrap();
        if *previous != value {
            *previous = value;
            drop(previous);
            ctx.request_repaint();
        }
    };
    // All callbacks run on this worker's GLib context. A reply from a previous
    // portal owner or an older read must not overwrite a live SettingChanged.
    let generation = Rc::new(Cell::new(0_u64));
    let next = {
        let generation = generation.clone();
        move || {
            let n = generation.get().wrapping_add(1);
            generation.set(n);
            n
        }
    };
    let _signals = bus.subscribe_to_signal(
        Some(PORTAL),
        Some(SETTINGS),
        Some("SettingChanged"),
        Some(PATH),
        Some(APPEARANCE),
        gio::DBusSignalFlags::NONE,
        {
            let publish = publish.clone();
            let next = next.clone();
            move |signal| {
                if let Some(value) = changed(signal.parameters) {
                    next();
                    publish(value);
                }
            }
        },
    );
    let watch = gio::bus_watch_name_on_connection(
        bus,
        PORTAL,
        gio::BusNameWatcherFlags::AUTO_START,
        {
            let next = next.clone();
            let publish = publish.clone();
            let stop = stop.clone();
            move |bus, _, owner| {
                let before = next();
                let generation = generation.clone();
                let publish = publish.clone();
                bus.call(
                    Some(owner),
                    PATH,
                    SETTINGS,
                    "ReadAll",
                    Some(&(vec![APPEARANCE],).to_variant()),
                    None,
                    gio::DBusCallFlags::NONE,
                    2000,
                    Some(&stop),
                    move |reply| {
                        if generation.get() == before {
                            publish(reply.ok().as_ref().and_then(read_all));
                        }
                    },
                );
            }
        },
        move |_, _| {
            next();
            publish(None);
        },
    );
    stop.future().await;
    gio::bus_unwatch_name(watch);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_standard_desktop_theme_variants() {
        for (raw, expected) in [
            (0_u32, Some(Theme::Light)),
            (1, Some(Theme::Dark)),
            (2, Some(Theme::Light)),
            (33, Some(Theme::Light)),
        ] {
            let value = raw.to_variant();
            let settings = HashMap::from([(APPEARANCE, HashMap::from([(KEY, value.clone())]))]);
            assert_eq!(read_all(&(settings,).to_variant()), expected);
            assert_eq!(
                changed(&(APPEARANCE, KEY, value).to_variant()),
                Some(expected)
            );
        }
        assert_eq!(read_all(&("bad reply",).to_variant()), None);
        assert_eq!(
            changed(&(APPEARANCE, "contrast", 1_u32.to_variant()).to_variant()),
            None
        );
        assert_eq!(
            changed(&("other namespace", KEY, 1_u32.to_variant()).to_variant()),
            None
        );
        assert_eq!(
            changed(&(APPEARANCE, KEY, "bad value".to_variant()).to_variant()),
            Some(None)
        );
    }

    // Run the real adapter against a private session bus without touching the user's desktop.
    #[test]
    fn native_portal_tracks_initial_theme_live_changes_and_owner_loss() {
        const CHILD: &str = "DRILL_TEST_ISOLATED_THEME_BUS";
        const TEST: &str = "native_portal_tracks_initial_theme_live_changes_and_owner_loss";
        if std::env::var_os(CHILD).is_none() {
            let status = std::process::Command::new("dbus-run-session")
                .arg("--")
                .arg(std::env::current_exe().unwrap())
                .args([TEST, "--nocapture"])
                .env(CHILD, "1")
                .status()
                .expect("native desktop theme test requires dbus-run-session");
            assert!(status.success());
            return;
        }
        glib::MainContext::new().block_on(async {
            let bus = gio::bus_get_sync(gio::BusType::Session, None::<&gio::Cancellable>).unwrap();
            let iface = gio::DBusNodeInfo::for_xml(&format!(r#"<node><interface name="{SETTINGS}">
                <method name="ReadAll"><arg direction="in" type="as"/><arg direction="out" type="a{{sa{{sv}}}}"/></method>
                </interface></node>"#)).unwrap().lookup_interface(SETTINGS).unwrap();
            let _registration = bus.register_object(PATH, &iface)
                .method_call(|_, _, _, _, _, params, invocation| {
                    let mut values = HashMap::new();
                    if params.get::<(Vec<String>,)>() == Some((vec![APPEARANCE.to_owned()],)) {
                        values.insert(APPEARANCE, HashMap::from([(KEY, 1_u32.to_variant())]));
                    }
                    invocation.return_value(Some(&(values,).to_variant()));
                }).build().unwrap();
            let name_call = |method, args: glib::Variant| {
                let reply = bus.call_sync(Some("org.freedesktop.DBus"), "/org/freedesktop/DBus",
                    "org.freedesktop.DBus", method, Some(&args), None, gio::DBusCallFlags::NONE, 2000,
                    None::<&gio::Cancellable>).unwrap();
                assert_eq!(reply.get::<(u32,)>(),Some((1,)));
            };
            name_call("RequestName", (PORTAL,4_u32).to_variant());
            let observer = DesktopTheme::new(Context::default());
            async fn wait_for(observer: &DesktopTheme, expected: Option<Theme>) {
                let start = std::time::Instant::now();
                while observer.current() != expected {
                    assert!(start.elapsed() < std::time::Duration::from_secs(5),
                        "expected {expected:?}, got {:?}", observer.current());
                    glib::timeout_future(std::time::Duration::from_millis(10)).await;
                }
            }
            wait_for(&observer, Some(Theme::Dark)).await;
            bus.emit_signal(None, PATH, SETTINGS, "SettingChanged",
                Some(&(APPEARANCE, KEY, 0_u32.to_variant()).to_variant())).unwrap();
            wait_for(&observer, Some(Theme::Light)).await;
            name_call("ReleaseName",(PORTAL,).to_variant());
            wait_for(&observer, None).await;
        });
    }
}
