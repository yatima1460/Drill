import SwiftUI

struct SyntaxHelp: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Files searches file and folder names. An empty Apps search lists applications.")
            Text("Use a lowercase prefix at the start of the query. Without a prefix, an asterisk selects wildcard search. Otherwise Drill searches for words.")

            mode("Words",
                 "Every word must occur somewhere in the name, in any order. Matching ignores case and accents. Dots, question marks and quotes are literal.",
                 examples: ["project notes"])
            mode("Fuzzy words",
                 "Each query word must resemble a word in the name. Use this for approximate spellings. Matching ignores case and accents.",
                 examples: ["fuzzy:projecx notes"])
            mode("Wildcards",
                 "Match the whole name. An asterisk (*) matches any number of characters, a question mark (?) matches one, [0-9] matches a digit, and {jpg,png} offers alternatives. Matching ignores case and accents. Use a backslash to escape a wildcard.",
                 examples: ["*.md", "glob:page[0-9]?.pdf", #"glob:literal\*.txt"#])
            mode("Regular expressions",
                 "A Rust regex can match anywhere in the name. Use ^ for the start and $ for the end. Matching ignores case by default and preserves accents. Add (?-i) for case-sensitive matching.",
                 examples: [#"regex:^IMG_[0-9]{4}\.jpg$"#])

            Text("Invalid patterns show an error. Globs and regexes accept up to 4,096 bytes. Glob groups can nest up to eight levels.")
            DisclosureGroup("More pattern syntax") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: "In a glob, [!0-9] matches one character other than a digit. <[0-9]:4> matches exactly four digits. The $ wildcard is a lazy version of *.")
                    Link("Wax 0.7 glob syntax", destination: URL(string: "https://github.com/olson-sean-k/wax/blob/v0.7.0/README.md#patterns")!)
                    Text(verbatim: "In a regex, use | for alternatives, parentheses for groups, and + to repeat the preceding item one or more times. Rust regexes exclude look-around and backreferences.")
                    Link("Rust regex reference", destination: URL(string: "https://docs.rs/regex/1/regex/#syntax")!)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private func mode(_ title: String, _ description: String, examples: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            Text(verbatim: description)
            ForEach(examples, id: \.self) { example in
                Text(verbatim: example)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
    }
}
