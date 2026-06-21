const eslint = require("@eslint/js");
const { defineConfig, globalIgnores } = require("eslint/config");
const prettierRecommended = require("eslint-plugin-prettier/recommended");
const roblox = require("eslint-plugin-roblox-ts");
const tseslint = require("typescript-eslint");

module.exports = defineConfig(
	eslint.configs.recommended,
	tseslint.configs.recommended,
	roblox.configs.tsRecommendedCompat,
	roblox.configs.recommended,
	{
		rules: {
			"@typescript-eslint/no-explicit-any": "off",
			"roblox-ts/no-any": "off",
		},
	},
	globalIgnores(["out/**", "eslint.config.js"]),
	prettierRecommended,
);
