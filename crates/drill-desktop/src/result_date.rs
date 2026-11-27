use std::time::{SystemTime, UNIX_EPOCH};

pub(super) fn display(time: Option<SystemTime>) -> String {
    time.and_then(unix_seconds)
        .and_then(local_fields)
        .map(format_fields)
        .unwrap_or_else(|| "?".into())
}

fn format_fields([year, month, day, hour, minute, second]: [i32; 6]) -> String {
    if (0..=9999).contains(&year) {
        format!("{year:04}/{month:02}/{day:02} {hour:02}:{minute:02}:{second:02}")
    } else {
        format!("{year:+05}/{month:02}/{day:02} {hour:02}:{minute:02}:{second:02}")
    }
}

fn unix_seconds(time: SystemTime) -> Option<i64> {
    // Dropping fractional seconds rounds toward the past, including before 1970.
    let seconds = match time.duration_since(UNIX_EPOCH) {
        Ok(duration) => i128::from(duration.as_secs()),
        Err(error) => {
            let duration = error.duration();
            -i128::from(duration.as_secs()) - i128::from(duration.subsec_nanos() != 0)
        }
    };
    // Keep the previously supported Gregorian years, -262143 through +262142.
    const MIN: i128 = -8_334_601_228_800;
    const MAX: i128 = 8_210_266_876_799;
    (MIN..=MAX).contains(&seconds).then_some(seconds as i64)
}

#[cfg(unix)]
#[allow(unsafe_code)]
fn local_fields(seconds: i64) -> Option<[i32; 6]> {
    use std::mem::MaybeUninit;

    #[cfg(target_os = "linux")]
    refresh_time_zone();

    #[allow(clippy::useless_conversion)]
    let seconds = libc::time_t::try_from(seconds).ok()?;
    let mut local = MaybeUninit::uninit();
    // SAFETY: The timestamp and caller-owned storage are valid for this call.
    if unsafe { libc::localtime_r(&seconds, local.as_mut_ptr()) }.is_null() {
        return None;
    }
    // SAFETY: localtime_r initialized the tm on success.
    let local = unsafe { local.assume_init() };
    Some([
        local.tm_year.checked_add(1900)?,
        local.tm_mon + 1,
        local.tm_mday,
        local.tm_hour,
        local.tm_min,
        local.tm_sec,
    ])
}

#[cfg(target_os = "linux")]
#[allow(unsafe_code)]
fn refresh_time_zone() {
    use std::cell::Cell;
    use std::time::{Duration, Instant};

    unsafe extern "C" {
        fn tzset();
    }
    thread_local! {
        static LAST_REFRESH: Cell<Option<Instant>> = const { Cell::new(None) };
    }
    LAST_REFRESH.with(|last| {
        let now = Instant::now();
        if last
            .get()
            .is_none_or(|time| now - time >= Duration::from_secs(1))
        {
            // SAFETY: Drill does not modify the process environment while running.
            // localtime_r can keep using stale rules on glibc unless tzset is called.
            unsafe { tzset() };
            last.set(Some(now));
        }
    });
}

#[cfg(windows)]
use windows::{DynamicTimeZoneInformation, FileTime, SystemTimeFields, TimeZoneInformation};

#[cfg(windows)]
#[allow(unsafe_code)]
mod windows {
    // The field order and widths follow the Windows SDK's minwinbase.h and timezoneapi.h.
    #[repr(C)]
    pub(super) struct FileTime {
        pub(super) low_date_time: u32,
        pub(super) high_date_time: u32,
    }

    #[derive(Default)]
    #[repr(C)]
    pub(super) struct SystemTimeFields {
        pub(super) year: u16,
        pub(super) month: u16,
        day_of_week: u16,
        pub(super) day: u16,
        pub(super) hour: u16,
        pub(super) minute: u16,
        pub(super) second: u16,
        milliseconds: u16,
    }

    #[derive(Default)]
    #[repr(C)]
    pub(super) struct TimeZoneInformation {
        bias: i32,
        standard_name: [u16; 32],
        pub(super) standard_date: SystemTimeFields,
        standard_bias: i32,
        daylight_name: [u16; 32],
        pub(super) daylight_date: SystemTimeFields,
        daylight_bias: i32,
    }

    #[repr(C)]
    pub(super) struct DynamicTimeZoneInformation {
        rules: TimeZoneInformation,
        pub(super) key_name: [u16; 128],
        dynamic_daylight_time_disabled: u8,
    }

    #[cfg(test)]
    impl Default for DynamicTimeZoneInformation {
        fn default() -> Self {
            Self {
                rules: TimeZoneInformation::default(),
                key_name: [0; 128],
                dynamic_daylight_time_disabled: 0,
            }
        }
    }

    #[link(name = "kernel32")]
    unsafe extern "system" {
        #[link_name = "FileTimeToSystemTime"]
        pub(super) fn file_time_to_system_time(
            file: *const FileTime,
            utc: *mut SystemTimeFields,
        ) -> i32;
        #[link_name = "GetTimeZoneInformationForYear"]
        pub(super) fn get_time_zone_information_for_year(
            year: u16,
            zone: *mut DynamicTimeZoneInformation,
            rules: *mut TimeZoneInformation,
        ) -> i32;
        #[link_name = "SystemTimeToTzSpecificLocalTime"]
        pub(super) fn system_time_to_local_time(
            rules: *const TimeZoneInformation,
            utc: *const SystemTimeFields,
            local: *mut SystemTimeFields,
        ) -> i32;
    }

    #[cfg(test)]
    #[link(name = "advapi32")]
    unsafe extern "system" {
        #[link_name = "EnumDynamicTimeZoneInformation"]
        pub(super) fn enum_dynamic_time_zone_information(
            index: u32,
            zone: *mut DynamicTimeZoneInformation,
        ) -> u32;
    }
}

#[cfg(windows)]
fn local_fields(seconds: i64) -> Option<[i32; 6]> {
    local_fields_in_zone(seconds, None)
}

#[cfg(windows)]
#[allow(unsafe_code)]
fn local_fields_in_zone(
    seconds: i64,
    zone: Option<&mut DynamicTimeZoneInformation>,
) -> Option<[i32; 6]> {
    // Gregorian dates repeat every 400 years. Use an equivalent calendar within
    // Win32's range and look up the time-zone rules for the original UTC year.
    const YEAR_2000: i64 = 946_684_800;
    const CYCLE: i64 = 146_097 * 86_400;
    const UNIX_EPOCH_FROM_FILETIME: i64 = 11_644_473_600;
    const TICKS_PER_SECOND: u64 = 10_000_000;
    let cycles = (seconds - YEAR_2000).div_euclid(CYCLE);
    let year_shift = i32::try_from(cycles * 400).ok()?;
    let equivalent_seconds = seconds - cycles * CYCLE;
    let ticks =
        u64::try_from(equivalent_seconds + UNIX_EPOCH_FROM_FILETIME).ok()? * TICKS_PER_SECOND;
    let file = FileTime {
        low_date_time: ticks as u32,
        high_date_time: (ticks >> 32) as u32,
    };
    let mut utc = SystemTimeFields::default();
    // SAFETY: The FILETIME input and caller-owned SYSTEMTIME output are valid.
    if unsafe { windows::file_time_to_system_time(&file, &mut utc) } == 0 {
        return None;
    }
    let year = i32::from(utc.year) + year_shift;
    let mut rules = TimeZoneInformation::default();
    let zone = zone.map_or(std::ptr::null_mut(), std::ptr::from_mut);
    // SAFETY: A null zone requests the active time zone. A supplied zone points
    // to the caller's initialized structure. Win32 writes into `rules`.
    if unsafe {
        windows::get_time_zone_information_for_year(
            year.clamp(1601, 30827) as u16,
            zone,
            &mut rules,
        )
    } == 0
    {
        return None;
    }
    for transition in [&mut rules.standard_date, &mut rules.daylight_date] {
        // A zero year encodes a recurring rule such as the last Sunday in March.
        if transition.year != 0 {
            transition.year = u16::try_from(i32::from(transition.year) - year_shift).ok()?;
        }
    }
    let mut local = SystemTimeFields::default();
    // SAFETY: The UTC time and time-zone rules have been initialized. The local
    // time output is valid and disjoint from both inputs.
    if unsafe { windows::system_time_to_local_time(&rules, &utc, &mut local) } == 0 {
        return None;
    }
    Some([
        i32::from(local.year) + year_shift,
        i32::from(local.month),
        i32::from(local.day),
        i32::from(local.hour),
        i32::from(local.minute),
        i32::from(local.second),
    ])
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Duration;

    #[test]
    fn timestamps_keep_their_second_before_and_after_the_epoch() {
        // Windows SystemTime uses 100-nanosecond ticks.
        let fraction = Duration::from_nanos(100);
        assert_eq!(unix_seconds(UNIX_EPOCH - fraction), Some(-1));
        assert_eq!(unix_seconds(UNIX_EPOCH - Duration::from_secs(1)), Some(-1));
        assert_eq!(unix_seconds(UNIX_EPOCH + fraction), Some(0));
        assert_eq!(display(None), "?");
    }

    #[cfg(all(unix, target_pointer_width = "64"))]
    #[test]
    fn timestamps_outside_the_supported_range_show_the_fallback() {
        let before = UNIX_EPOCH - Duration::from_secs(8_334_601_228_801);
        let after = UNIX_EPOCH + Duration::from_secs(8_210_266_876_800);
        assert_eq!(display(Some(before)), "?");
        assert_eq!(display(Some(after)), "?");
    }

    #[test]
    fn timestamps_keep_their_numeric_format_for_wide_years() {
        assert_eq!(format_fields([42, 2, 3, 4, 5, 6]), "0042/02/03 04:05:06");
        assert_eq!(format_fields([-42, 2, 3, 4, 5, 6]), "-0042/02/03 04:05:06");
        assert_eq!(
            format_fields([10000, 2, 3, 4, 5, 6]),
            "+10000/02/03 04:05:06"
        );
    }

    #[cfg(windows)]
    #[allow(unsafe_code)]
    #[test]
    fn windows_results_follow_historical_daylight_saving_rules() {
        let eastern_key: Vec<u16> = "Eastern Standard Time\0".encode_utf16().collect();
        let mut zone = DynamicTimeZoneInformation::default();
        for index in 0.. {
            // SAFETY: `zone` is valid caller-owned storage for the enumerated entry.
            let status = unsafe { windows::enum_dynamic_time_zone_information(index, &mut zone) };
            assert_eq!(status, 0, "Windows Eastern time zone missing");
            if zone.key_name.starts_with(&eastern_key) {
                break;
            }
        }
        for (seconds, expected) in [
            (-11_644_473_600, "1600/12/31 19:00:00"),
            (-1, "1969/12/31 18:59:59"),
            (1_142_838_000, "2006/03/20 02:00:00"),
            (1_174_374_000, "2007/03/20 03:00:00"),
            (1_710_053_999, "2024/03/10 01:59:59"),
            (1_710_054_000, "2024/03/10 03:00:00"),
            (1_730_613_599, "2024/11/03 01:59:59"),
            (1_730_613_600, "2024/11/03 01:00:00"),
        ] {
            let fields = local_fields_in_zone(seconds, Some(&mut zone)).unwrap();
            assert_eq!(format_fields(fields), expected);
        }
    }
}
