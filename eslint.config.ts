import eslint from "@eslint/js";
import { defineConfig, globalIgnores } from "eslint/config";
import prettierRecommended from "eslint-plugin-prettier/recommended";
import roblox from "eslint-plugin-roblox-ts";
import tseslint from "typescript-eslint";

export default defineConfig(
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
	globalIgnores(["out/**"]),
	prettierRecommended,
);
