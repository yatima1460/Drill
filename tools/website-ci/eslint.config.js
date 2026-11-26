import js from "@eslint/js";

export default [
  js.configs.recommended,
  {
    files: ["docs/**/*.{js,mjs}"],
    languageOptions: {
      globals: { document: "readonly", fetch: "readonly", navigator: "readonly" },
    },
  },
  {
    files: ["docs/**/*.js"],
    languageOptions: { sourceType: "script" },
  },
];
