#![forbid(unsafe_code)]
//! Parse search queries and classify filenames independently of filesystem traversal.

mod glob;
mod normalization;
use normalization::normalized;

// Ratcliff/Obershelp matching, as used by Python's difflib.SequenceMatcher.
fn matching_chars(a: &[char], b: &[char]) -> usize {
    let mut best = (0, 0, 0);
    for i in 0..a.len() {
        for j in 0..b.len() {
            let mut n = 0;
            while i + n < a.len() && j + n < b.len() && a[i + n] == b[j + n] {
                n += 1;
            }
            if n > best.2 {
                best = (i, j, n);
            }
        }
    }
    if best.2 == 0 {
        0
    } else {
        best.2
            + matching_chars(&a[..best.0], &b[..best.1])
            + matching_chars(&a[best.0 + best.2..], &b[best.1 + best.2..])
    }
}

enum Tokens {
    Plain(Vec<String>),
    Fuzzy(Vec<Vec<char>>),
}

enum Matcher {
    Text {
        filename: String,
        tokens: Tokens,
        #[cfg(any(windows, test, feature = "windows-lookups"))]
        literal_exe: Option<String>,
    },
    Glob(regex::Regex),
    Regex(regex::Regex),
    Invalid(String),
}

pub struct SearchQuery(Matcher);

impl SearchQuery {
    pub fn parse(input: &str) -> Self {
        let input = input.trim_start();
        let fuzzy = input.strip_prefix("fuzzy:");
        if let Some(pattern) = input.strip_prefix("regex:") {
            return Self::pattern("regex", pattern, |pattern| {
                regex::RegexBuilder::new(pattern)
                    .case_insensitive(true)
                    .build()
                    .map(Matcher::Regex)
                    .map_err(|e| {
                        e.to_string()
                            .lines()
                            .last()
                            .unwrap_or("invalid expression")
                            .to_owned()
                    })
            });
        }
        if let Some(pattern) = input
            .strip_prefix("glob:")
            .or_else(|| (fuzzy.is_none() && input.contains('*')).then_some(input.trim_end()))
        {
            return Self::pattern("glob", pattern, |pattern| {
                glob::compile(pattern)
                    .map(Matcher::Glob)
                    .map_err(str::to_owned)
            });
        }
        let literal = fuzzy.unwrap_or(input).trim();
        let filename = normalized(literal);
        #[cfg(any(windows, test, feature = "windows-lookups"))]
        let literal_exe = (fuzzy.is_none() && filename.ends_with(".exe") && literal != filename)
            .then(|| literal.to_owned());
        let words = filename.split_whitespace();
        let tokens = if fuzzy.is_some() {
            Tokens::Fuzzy(words.map(|word| word.chars().collect()).collect())
        } else {
            Tokens::Plain(words.map(str::to_owned).collect())
        };
        Self(Matcher::Text {
            filename,
            tokens,
            #[cfg(any(windows, test, feature = "windows-lookups"))]
            literal_exe,
        })
    }

    fn pattern(
        kind: &str,
        pattern: &str,
        compile: impl FnOnce(&str) -> Result<Matcher, String>,
    ) -> Self {
        // Bound parsing work for pasted expressions during interactive search.
        const MAX_PATTERN_BYTES: usize = 4096;
        let matcher = if pattern.is_empty() {
            Err("enter a pattern".to_owned())
        } else if pattern.len() > MAX_PATTERN_BYTES {
            Err(format!("patterns are limited to {MAX_PATTERN_BYTES} bytes"))
        } else {
            compile(pattern)
        };
        Self(matcher.unwrap_or_else(|reason| Matcher::Invalid(format!("Invalid {kind}: {reason}"))))
    }

    pub fn error(&self) -> Option<&str> {
        match &self.0 {
            Matcher::Invalid(message) => Some(message),
            _ => None,
        }
    }

    pub fn is_empty(&self) -> bool {
        matches!(&self.0, Matcher::Text {filename, ..} if filename.is_empty())
    }

    #[cfg(any(windows, test, feature = "windows-lookups"))]
    /// Original filename suitable for a direct Windows executable lookup.
    pub fn executable_filename(&self) -> Option<&str> {
        let Matcher::Text {
            filename,
            tokens: Tokens::Plain(_),
            literal_exe,
        } = &self.0
        else {
            return None;
        };
        let literal = literal_exe.as_deref().unwrap_or(filename);
        if !filename.ends_with(".exe")
            || literal.encode_utf16().take(256).count() > 255
            || literal
                .chars()
                .any(|c| c.is_control() || r#"<>:"/\|?*"#.contains(c))
        {
            return None;
        }
        // A DOS device remains special even when followed by an extension.
        let stem = filename.split('.').next()?.trim_end_matches(' ');
        if matches!(stem, "con" | "aux" | "nul" | "prn" | "conin$" | "conout$")
            || ["com", "lpt"].iter().any(|prefix| {
                stem.strip_prefix(prefix).is_some_and(|n| {
                    matches!(
                        n,
                        "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" | "¹" | "²" | "³"
                    )
                })
            })
        {
            return None;
        }
        Some(literal)
    }

    /// Whether a literal or fuzzy query exactly matches an application stem.
    pub fn exact_stem(&self, stem: &str) -> bool {
        matches!(&self.0, Matcher::Text {filename, ..} if !filename.is_empty() && *filename == normalized(stem))
    }

    pub fn classify(&self, name: &str) -> Option<MatchKind> {
        let (filename, tokens) = match &self.0 {
            Matcher::Glob(glob) => {
                return glob
                    .is_match(normalized(name).as_str())
                    .then_some(MatchKind::Partial)
            }
            Matcher::Regex(regex) => return regex.is_match(name).then_some(MatchKind::Partial),
            Matcher::Invalid(_) => return None,
            Matcher::Text {
                filename, tokens, ..
            } => (filename, tokens),
        };
        let name = normalized(name);
        if !filename.is_empty() && name == *filename {
            return Some(MatchKind::Exact);
        }
        let matched = match tokens {
            Tokens::Plain(tokens) => tokens.iter().all(|token| name.contains(token)),
            Tokens::Fuzzy(tokens) => {
                let words: Vec<Vec<char>> = name
                    .split_whitespace()
                    .map(|word| word.chars().collect())
                    .collect();
                !tokens.is_empty()
                    && tokens.iter().all(|token| {
                        words
                            .iter()
                            .any(|word| 4 * matching_chars(word, token) >= token.len() + word.len())
                    })
            }
        };
        matched.then_some(MatchKind::Partial)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MatchKind {
    Exact,
    Partial,
}

pub fn matches(name: &str, query: &str) -> bool {
    SearchQuery::parse(query).classify(name).is_some()
}

/// Compare a requested Windows filename with the long name returned by the OS.
#[cfg(any(windows, test, feature = "windows-lookups"))]
pub fn equivalent_filenames(a: &str, b: &str) -> bool {
    normalized(a) == normalized(b)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn matching() {
        assert!(matches("Project Nôtés.txt", "project notes"));
        assert!(!matches("Project Notes.txt", "projecx notes"));
        assert!(matches("Project Notes.txt", "fuzzy:projecx notes"));
        assert!(!matches("Project Notes.txt", "fuzzy:unrelated"));
        assert!(matches("diet", "fuzzy:tide"));
    }
    #[test]
    fn wildcard_and_regex_queries_match_filenames() {
        for (query, hit, miss) in [
            ("*.md", "Notes.MD", "notes.md.bak"),
            ("myfile*", "myfile copy", "a-myfile"),
            ("*myfile", "a-myfile", "myfile.bak"),
            ("*myfile*", "a-myfile.bak", "my-file"),
            ("glob:page[0-9]?.pdf", "Page3猫.pdf", "page32x.pdf"),
            (r"glob:literal\*.txt", "literal*.txt", "literal1.txt"),
            (r"regex:^IMG_[0-9]{4}\.jpg$", "img_0027.JPG", "IMG_27.jpg"),
            (r"regex:\S+\.md$", "notes final.md", "notes finalXmd"),
            ("regex:(?-i)^Z", "Zebra", "zebra"),
            ("regex:^café$", "café", "cafe"),
        ] {
            assert!(matches(hit, query), "{query:?} should find {hit:?}");
            assert!(!matches(miss, query), "{query:?} should skip {miss:?}");
        }
        assert!(matches("notes [v2]?.txt", "[v2]?"));
        assert!(!matches("notes v2A.txt", "[v2]?"));
    }

    #[test]
    fn wildcard_groups_preserve_filename_glob_syntax() {
        for (pattern, hit, miss) in [
            ("{*.jpg,IMG_<[0-9]:4>.PNG}", "IMG_0123.png", "IMG_123.png"),
            ("{doc,<é:2,3>}.txt", "ÉÉ.txt", "éééé.txt"),
            ("report$[!0-9].txt", "Report-a.txt", "report-3.txt"),
            (r"[a\-]foo\{bar\}", "-foo{bar}", "bfoo{bar}"),
            ("**/report.txt", "subdir/Report.txt", "old-report.txt"),
            ("report/**", "report", "reports"),
            ("<?:0,2><a:2,>", "xyaaa", "abc"),
            ("?", "\n", "/"),
            ("**", "x/y", "x\ny"),
            ("(?i)σ", "ς", "x"),
            ("(?-i)σ", "σ", "ς"),
        ] {
            let query = SearchQuery::parse(&format!("glob:{pattern}"));
            assert_eq!(query.error(), None, "{pattern:?}");
            assert_eq!(query.classify(hit), Some(MatchKind::Partial), "{pattern:?}");
            assert_eq!(query.classify(miss), None, "{pattern:?}");
        }
        assert_eq!(SearchQuery::parse("glob:[/]").error(), None);
        assert!(!matches("/", "glob:[/]"));
        assert_eq!(SearchQuery::parse("glob:[z-a]").error(), None);
        assert!(!matches("a", "glob:[z-a]"));
        assert!(!matches("a", "glob:[az-a]"));
        assert!(!matches("b", "glob:[!az-a]"));
        assert_eq!(matches("a\\b", "glob:a/b"), cfg!(windows));
        assert_eq!(matches("\\", "glob:?"), !cfg!(windows));
        assert_eq!(matches("ς", "glob:σ"), cfg!(windows));
    }

    #[test]
    fn invalid_globs_report_errors_and_produce_no_matches() {
        for pattern in [
            "",
            "[",
            "[]",
            "[a-]",
            r"\a",
            "a**b",
            "a//b",
            "*{a,*b}",
            "{a,**}",
            "{a,/b}",
            "<*>",
            "<a:0>",
            "<a:2,1>",
            "<a:65536>",
            "<*/>a</*>",
            "<a*:4294967296>",
            "a(?i)",
            "{{{{{{{{{a}}}}}}}}}",
        ] {
            let query = SearchQuery::parse(&format!("glob:{pattern}"));
            assert!(
                query
                    .error()
                    .is_some_and(|error| error.starts_with("Invalid glob:")),
                "{pattern:?}",
            );
            assert_eq!(query.classify("a"), None);
        }
        let literal = "a".repeat(4096);
        assert!(matches(&literal, &format!("glob:{literal}")));
        assert!(SearchQuery::parse(&format!("glob:{literal}a"))
            .error()
            .is_some());
        assert!(matches("a", "glob:{{{{{{{{a}}}}}}}}"));
        let escaped_after_normalizing = "\\\u{301}{".repeat(9);
        assert!(
            SearchQuery::parse(&format!("glob:{escaped_after_normalizing}"))
                .error()
                .is_some()
        );
    }

    #[test]
    fn prepared_queries_handle_whitespace_and_rank_the_whole_filename() {
        let query = SearchQuery::parse("  fuzzy:  röM.EXE  ");
        assert_eq!(query.classify("rom.exe"), Some(MatchKind::Exact));
        assert_eq!(query.classify("rom.exe.bak"), Some(MatchKind::Partial));
        for text in [
            "project  notes",
            "fuzzy: project  notes",
            "fuzzy:project\tnotes",
            "project\u{2003}notes",
        ] {
            assert!(matches("Project Nôtés.txt", text), "{text:?}");
        }
        assert_eq!(
            SearchQuery::parse("a  b").classify("a  b"),
            Some(MatchKind::Exact)
        );
        assert_eq!(
            SearchQuery::parse("a b").classify("b a"),
            Some(MatchKind::Partial)
        );
        assert!(!matches("anything", "fuzzy:   "));
        assert!(matches("anything", ""));
    }

    #[test]
    fn exact_stems_distinguish_text_from_patterns_and_empty_input() {
        assert!(SearchQuery::parse("Notes").exact_stem("Nôtés"));
        assert!(SearchQuery::parse("fuzzy:Notes").exact_stem("Nôtés"));
        assert!(!SearchQuery::parse("Notes").exact_stem("notebook"));
        assert!(!SearchQuery::parse("glob:note*").exact_stem("notes"));
        assert!(!SearchQuery::parse("").exact_stem(""));
    }

    #[test]
    fn executable_lookups_require_a_literal_windows_filename() {
        for text in [
            "notepad",
            "regex:notepad.exe",
            "*.exe",
            "fuzzy:notepad.exe",
            r"sub\tool.exe",
            "sub/tool.exe",
            "aux.exe",
            "lpt1.exe",
            "c:thing.exe",
            "com¹.exe",
            "file?.exe",
            "file\0.exe",
        ] {
            assert_eq!(
                SearchQuery::parse(text).executable_filename(),
                None,
                "{text:?}"
            );
        }
    }

    #[test]
    fn executable_lookups_preserve_the_spelling_of_the_requested_file() {
        assert_eq!(
            SearchQuery::parse("NÔTÉS.EXE").executable_filename(),
            Some("NÔTÉS.EXE")
        );
        assert!(equivalent_filenames("NÔTÉS.EXE", "notes.exe"));
        assert!(!equivalent_filenames("NOTES~1.EXE", "Notes editor.exe"));
    }
}
