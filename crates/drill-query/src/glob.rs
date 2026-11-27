//! Filename glob syntax compiled to an anchored Rust regular expression.

use std::collections::VecDeque;

use regex::Regex;

use crate::normalized;

#[cfg(windows)]
const SEPARATORS: &str = r"/\\";
#[cfg(not(windows))]
const SEPARATORS: &str = "/";

const MAX_DEPTH: usize = 8;
const MAX_FIXED_SIZE: usize = 65_536;
const LITERAL_ESCAPES: &str = "?*$:<>()[]{},";
type Error = &'static str;

pub(super) fn compile(pattern: &str) -> Result<Regex, Error> {
    // Removing combining marks can change which character a backslash escapes.
    // Preserve the input limit before parsing the normalized expression.
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
                if depth > MAX_DEPTH {
                    return Err("glob groups can nest up to 8 levels");
                }
            }
            '}' | '>' if !in_class => depth = depth.saturating_sub(1),
            _ => {}
        }
    }
    let pattern = normalized(pattern);
    let tokens = Parser {
        rest: &pattern,
        insensitive: cfg!(windows),
    }
    .sequence("", 0)?;
    validate(&tokens)?;
    let mut expression = String::from(r"\A");
    encode(&tokens, &mut expression, None);
    expression.push_str(r"\z");
    Regex::new(&expression).map_err(|_| "pattern is too large to compile")
}

type Sequence = Vec<Token>;

enum Token {
    Literal(String, bool),
    Class(String),
    One,
    Many { lazy: bool },
    Tree { rooted: bool },
    Separator,
    Alternatives(Vec<Sequence>),
    Repeat(Sequence, usize, Option<usize>),
}

struct Parser<'a> {
    rest: &'a str,
    insensitive: bool,
}

impl Parser<'_> {
    fn take(&mut self, prefix: &str) -> bool {
        if let Some(rest) = self.rest.strip_prefix(prefix) {
            self.rest = rest;
            true
        } else {
            false
        }
    }

    fn peek(&self) -> Option<char> {
        self.rest.chars().next()
    }

    fn next(&mut self) -> Option<char> {
        let c = self.peek()?;
        self.rest = &self.rest[c.len_utf8()..];
        Some(c)
    }

    fn flags(&mut self) -> Result<(), Error> {
        while self.take("(?") {
            let mut saw_flag = false;
            loop {
                if self.take("i") {
                    self.insensitive = true;
                } else if self.take("-i") {
                    self.insensitive = false;
                } else if saw_flag && self.take(")") {
                    break;
                } else {
                    return Err("expected a case flag such as (?i) or (?-i)");
                }
                saw_flag = true;
            }
        }
        Ok(())
    }

    fn sequence(&mut self, ends: &str, depth: usize) -> Result<Sequence, Error> {
        if depth > MAX_DEPTH {
            return Err("glob groups can nest up to 8 levels");
        }
        let mut tokens = Vec::new();
        while self.peek().is_some_and(|c| !ends.contains(c)) {
            let before_flags = self.rest;
            self.flags()?;
            let start = tokens.is_empty() && self.rest == before_flags;
            let token = match self.peek() {
                Some('/') => {
                    self.next();
                    self.tree(ends)
                        .map_or(Token::Separator, |()| Token::Tree { rooted: true })
                }
                Some('*') if start && self.tree(ends).is_some() => Token::Tree { rooted: false },
                Some('*' | '$') => {
                    let lazy = self.next() == Some('$');
                    if tokens.last().is_some_and(Token::many) {
                        return Err("adjacent zero-or-more wildcards");
                    }
                    Token::Many { lazy }
                }
                Some('?') => {
                    self.next();
                    Token::One
                }
                Some('[') => {
                    self.next();
                    Token::Class(self.class()?)
                }
                Some('{') => {
                    self.next();
                    let mut branches = vec![self.sequence(",}", depth + 1)?];
                    while self.take(",") {
                        branches.push(self.sequence(",}", depth + 1)?);
                    }
                    if !self.take("}") {
                        return Err("expected a closing brace");
                    }
                    Token::Alternatives(branches)
                }
                Some('<') => {
                    self.next();
                    let body = self.sequence(":>", depth + 1)?;
                    let (min, max) = self.bounds()?;
                    if !self.take(">") {
                        return Err("expected a closing angle bracket");
                    }
                    Token::Repeat(body, min, max)
                }
                Some(c) if c != '/' && !LITERAL_ESCAPES.contains(c) => {
                    Token::Literal(self.literal()?, self.insensitive)
                }
                _ => return Err("expected a glob expression"),
            };
            if tokens.last().is_some_and(Token::boundary) && token.boundary() {
                return Err("adjacent path boundaries");
            }
            tokens.push(token);
        }
        if depth != 0 && tokens.is_empty() {
            return Err("empty glob group");
        }
        Ok(tokens)
    }

    // A tree wildcard takes its surrounding separators as part of the token.
    fn tree(&mut self, ends: &str) -> Option<()> {
        let original = (self.rest, self.insensitive);
        if self.flags().is_ok() && self.take("**") {
            if self.peek().is_none_or(|c| ends.contains(c)) {
                return Some(());
            }
            if self.flags().is_ok() && self.take("/") {
                return Some(());
            }
        }
        (self.rest, self.insensitive) = original;
        None
    }

    fn literal(&mut self) -> Result<String, Error> {
        let mut text = String::new();
        while let Some(c) = self.peek() {
            if c == '\\' {
                self.next();
                let escaped = self
                    .next()
                    .filter(|&c| LITERAL_ESCAPES.contains(c))
                    .ok_or("invalid glob escape")?;
                text.push(escaped);
            } else if c == '/' || LITERAL_ESCAPES.contains(c) {
                break;
            } else {
                self.next();
                text.push(c);
            }
        }
        Ok(text)
    }

    fn class_atom(&mut self) -> Result<char, Error> {
        match self.next() {
            Some('\\') => self
                .next()
                .filter(|&c| "[]-".contains(c))
                .ok_or("invalid character class escape"),
            Some(c) if !"[]-".contains(c) => Ok(c),
            _ => Err("expected a character or range in the class"),
        }
    }

    fn class(&mut self) -> Result<String, Error> {
        let negated = self.take("!");
        let mut class = String::from(if negated { "[^" } else { "[" });
        let mut reversed = false;
        loop {
            let first = self.class_atom()?;
            class.push_str(&regex::escape(&first.to_string()));
            if self.take("-") {
                let last = self.class_atom()?;
                reversed |= first > last;
                class.push('-');
                class.push_str(&regex::escape(&last.to_string()));
            }
            if self.take("]") {
                break;
            }
        }
        if !negated {
            class.push_str("&&[^");
        }
        class.push_str(SEPARATORS);
        class.push(']');
        if !negated {
            class.push(']');
        }
        // The entire class matches nothing if any range is reversed.
        Ok(if reversed { "[a&&b]".into() } else { class })
    }

    fn count(&mut self) -> Result<Option<usize>, Error> {
        let count = self.rest.len()
            - self
                .rest
                .trim_start_matches(|c: char| c.is_ascii_digit())
                .len();
        let (digits, rest) = self.rest.split_at(count);
        self.rest = rest;
        if digits.is_empty() {
            Ok(None)
        } else {
            digits
                .parse()
                .map(Some)
                .map_err(|_| "invalid repetition count")
        }
    }

    fn bounds(&mut self) -> Result<(usize, Option<usize>), Error> {
        if !self.take(":") {
            return Ok((0, None));
        }
        let Some(min) = self.count()? else {
            return Ok((1, None));
        };
        let max = if self.take(",") {
            self.count()?
        } else {
            Some(min)
        };
        if max.is_some_and(|max| min > max || max == 0) {
            return Err("invalid repetition bounds");
        }
        Ok((min, max))
    }
}

impl Token {
    fn boundary(&self) -> bool {
        matches!(self, Self::Separator | Self::Tree { .. })
    }

    fn many(&self) -> bool {
        matches!(self, Self::Many { .. })
    }

    fn edge_matches(&self, start: bool, test: fn(&Token) -> bool) -> bool {
        match self {
            Self::Alternatives(branches) => branches.iter().any(|branch| {
                branch_edge(branch, start).is_some_and(|token| token.edge_matches(start, test))
            }),
            Self::Repeat(branch, ..) => {
                branch_edge(branch, start).is_some_and(|token| token.edge_matches(start, test))
            }
            token => test(token),
        }
    }
}

fn branch_edge(branch: &[Token], start: bool) -> Option<&Token> {
    if start {
        branch.first()
    } else {
        branch.last()
    }
}

fn validate(tokens: &[Token]) -> Result<(), Error> {
    fn check_branch(
        branch: &[Token],
        repeat_min: Option<usize>,
        left: Option<&Token>,
        right: Option<&Token>,
    ) -> Result<(), Error> {
        let first = &branch[0];
        let last = &branch[branch.len() - 1];
        if branch.len() == 1 && matches!(first, Token::Tree { .. }) {
            return Err("a glob group cannot consist of a single tree wildcard");
        }
        if left.is_none()
            && repeat_min.unwrap_or(0) == 0
            && matches!(first, Token::Separator | Token::Tree { rooted: true })
        {
            return Err("a glob branch cannot optionally start at a path root");
        }
        if (first.boundary() && left.is_some_and(|t| t.edge_matches(false, Token::boundary)))
            || (last.boundary() && right.is_some_and(|t| t.edge_matches(true, Token::boundary)))
        {
            return Err("adjacent path boundaries");
        }
        if (first.many() && left.is_some_and(|t| t.edge_matches(false, Token::many)))
            || (last.many() && right.is_some_and(|t| t.edge_matches(true, Token::many)))
        {
            return Err("adjacent zero-or-more wildcards");
        }
        if repeat_min.is_some() && first.boundary() && last.boundary() {
            return Err("repeated path boundaries would be adjacent");
        }
        if repeat_min.is_some() && branch.len() == 1 && first.many() {
            return Err("a repetition cannot consist of a single zero-or-more wildcard");
        }
        Ok(())
    }

    // Preserve boundary checks across groups, including nested groups and
    // groups adjacent to each other in the source expression.
    let (mut left, mut right) = (None, None);
    // The syntax also checks component boundaries between consecutive groups at
    // the same nesting level and alternative position. For example, <a/>b</c:1>
    // has adjacent boundaries between the two repetition bodies.
    let mut previous_boundary = None;
    let mut pending = VecDeque::from([(tokens, 0, 0, 0)]);
    while let Some((sequence, depth, alternatives, arm)) = pending.pop_front() {
        let position = (depth, alternatives, arm);
        if previous_boundary == Some(position) && sequence.first().is_some_and(Token::boundary) {
            return Err("adjacent path boundaries");
        }
        previous_boundary = sequence
            .last()
            .is_some_and(Token::boundary)
            .then_some(position);
        for (index, token) in sequence.iter().enumerate() {
            let (branches, repeat_min) = match token {
                Token::Alternatives(branches) => (branches.as_slice(), None),
                Token::Repeat(branch, min, _) => (std::slice::from_ref(branch), Some(*min)),
                _ => continue,
            };
            left = index.checked_sub(1).and_then(|i| sequence.get(i)).or(left);
            right = sequence.get(index + 1).or(right);
            for (i, branch) in branches.iter().enumerate() {
                check_branch(branch, repeat_min, left, right)?;
                let (alternatives, arm) = if repeat_min.is_none() {
                    (alternatives + 1, i)
                } else {
                    (alternatives, arm)
                };
                pending.push_back((branch, depth + 1, alternatives, arm));
            }
        }
    }
    fixed_size(tokens)?;
    Ok(())
}

fn fixed_size(tokens: &[Token]) -> Result<Option<usize>, Error> {
    let mut total = Some(0_usize);
    for token in tokens {
        let size = match token {
            Token::Literal(text, _) => Some(text.len()),
            // Reserve the largest UTF-8 code point for single-character tokens.
            Token::Class(_) | Token::One => Some(4),
            Token::Separator => Some(1),
            Token::Many { .. } | Token::Tree { .. } => None,
            Token::Alternatives(branches) => {
                let mut sizes = branches.iter().map(|branch| fixed_size(branch));
                let first = sizes.next().transpose()?.flatten();
                sizes.try_fold(first, |size, next| -> Result<_, Error> {
                    let next = next?;
                    Ok(size.filter(|&n| next == Some(n)))
                })?
            }
            Token::Repeat(branch, min, max) => {
                let size = fixed_size(branch)?;
                if Some(*min) == *max {
                    size.map(|size| size.saturating_mul(*min))
                } else {
                    None
                }
            }
        };
        if size.is_some_and(|size| size >= MAX_FIXED_SIZE) {
            return Err("fixed-size glob is too large");
        }
        total = total.zip(size).map(|(sum, size)| sum + size);
    }
    if total.is_some_and(|size| size >= MAX_FIXED_SIZE) {
        return Err("fixed-size glob is too large");
    }
    Ok(total)
}

fn encode(tokens: &[Token], out: &mut String, outer: Option<(bool, bool)>) {
    use std::fmt::Write as _;

    for (index, token) in tokens.iter().enumerate() {
        let first = index == 0;
        let last = index + 1 == tokens.len();
        match token {
            Token::Literal(text, insensitive) => {
                out.push_str(if *insensitive { "(?i)" } else { "(?-i)" });
                out.push_str(&regex::escape(text));
            }
            Token::Class(class) => out.push_str(class),
            Token::Separator => write!(out, "[{SEPARATORS}]").unwrap(),
            Token::One => write!(out, "[^{SEPARATORS}]").unwrap(),
            Token::Many { lazy } => {
                let modifier = if *lazy { "*?" } else { "*" };
                write!(out, "[^{SEPARATORS}]{modifier}").unwrap();
            }
            Token::Tree { rooted } => {
                let outer_first = outer.is_none_or(|(first, _)| first);
                let outer_last = outer.is_none_or(|(_, last)| last);
                if first && last {
                    out.push_str(".*");
                } else if first && outer_first {
                    if *rooted {
                        write!(out, "[{SEPARATORS}].*[{SEPARATORS}]?").unwrap();
                    } else {
                        write!(out, "(?:[{SEPARATORS}]?|.*[{SEPARATORS}])").unwrap();
                    }
                } else if last && outer_last {
                    write!(out, "(?:[{SEPARATORS}]?|[{SEPARATORS}].*)").unwrap();
                } else {
                    write!(out, "[{SEPARATORS}](?:.*[{SEPARATORS}])?").unwrap();
                }
            }
            Token::Alternatives(branches) => {
                out.push_str("(?:");
                for (i, branch) in branches.iter().enumerate() {
                    if i != 0 {
                        out.push('|');
                    }
                    out.push_str("(?:");
                    encode(branch, out, outer.or(Some((first, last))));
                    out.push(')');
                }
                out.push(')');
            }
            Token::Repeat(body, min, max) => {
                out.push_str("(?:");
                encode(body, out, outer.or(Some((first, last))));
                write!(out, "){{{min},").unwrap();
                if let Some(max) = max {
                    write!(out, "{max}").unwrap();
                }
                out.push('}');
            }
        }
    }
}
