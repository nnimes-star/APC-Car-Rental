import {FlatCompat} from "@eslint/eslintrc";
import {fileURLToPath} from "node:url";
import {dirname} from "node:path";

const here=dirname(fileURLToPath(import.meta.url));
const compat=new FlatCompat({baseDirectory:here});

const config=[
  {ignores:[".next/**","node_modules/**"]},
  ...compat.extends("next/core-web-vitals","next/typescript"),
  {
    rules:{
      "@typescript-eslint/no-explicit-any":"off",
      "@typescript-eslint/triple-slash-reference":"off",
    },
  },
];

export default config;
