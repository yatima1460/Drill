export default {
  extends: ["stylelint-config-recommended"],
  rules: {
    // The page deliberately orders shared button styles after platform-specific selectors.
    "no-descending-specificity": null,
  },
};
