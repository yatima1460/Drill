use unicode_normalization::{char::is_combining_mark, UnicodeNormalization};
use wax::Program;

pub(super) fn normalized(text: &str) -> String {
    text.to_lowercase()
        .nfd()
        .filter(|c| !is_combining_mark(*c))
        .collect()
}

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

// Wax parses alternation and repetition groups recursively. Check their depth
// before handing a pasted expression to the parser on the UI thread.
fn compile_glob(pattern: &str) -> Result<Matcher, String> {
    const MAX_GROUP_DEPTH: usize = 8;
    let mut depth = 0_usize;
    let mut in_class = false;
    let mut chars = pattern.chars();
    while let Some(c) = chars.next() {
        match c {
            '\\' => {
                chars.next();
            }
            '[' => in_class = true,
            ']' => in_class = false,
            '{' | '<' if !in_class => {
                depth += 1;
                if depth > MAX_GROUP_DEPTH {
                    return Err(format!(
                        "glob groups can nest up to {MAX_GROUP_DEPTH} levels"
                    ));
                }
            }
            '}' | '>' if !in_class => depth = depth.saturating_sub(1),
            _ => {}
        }
    }
    wax::Glob::new(&normalized(pattern))
        .map(|glob| Matcher::Glob(glob.into_owned()))
        .map_err(|e| e.to_string())
}

enum Tokens {
    Plain(Vec<String>),
    Fuzzy(Vec<Vec<char>>),
}

enum Matcher {
    Text { filename: String, tokens: Tokens },
    Glob(wax::Glob<'static>),
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
            return Self::pattern("glob", pattern, compile_glob);
        }
        let filename = normalized(fuzzy.unwrap_or(input).trim());
        let words = filename.split_whitespace();
        let tokens = if fuzzy.is_some() {
            Tokens::Fuzzy(words.map(|word| word.chars().collect()).collect())
        } else {
            Tokens::Plain(words.map(str::to_owned).collect())
        };
        Self(Matcher::Text { filename, tokens })
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

    #[cfg(any(windows, test))]
    pub(super) fn executable_filename(&self) -> Option<&str> {
        let Matcher::Text {
            filename,
            tokens: Tokens::Plain(_),
        } = &self.0
        else {
            return None;
        };
        if !filename.ends_with(".exe")
            || filename.len() > 255
            || filename
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
        Some(filename)
    }

    pub(super) fn exact_stem(&self, stem: &str) -> bool {
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
            Matcher::Text { filename, tokens } => (filename, tokens),
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
