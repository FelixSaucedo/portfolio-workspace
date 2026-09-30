const fs = require('node:fs');
for (const file of [
  'tailwind.config.js', 'tailwind.config.cjs', 'tailwind.config.mjs', 'tailwind.config.ts',
  'postcss.config.js', 'postcss.config.cjs', 'postcss.config.mjs', 'postcss.config.ts',
]) fs.rmSync(file, { force: true });
const file = 'src/style.css';
const css = (fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '')
  .replace(/^[ \t]*@tailwind\s+(base|components|utilities);[ \t]*\r?\n?/gm, '')
  .replace(/^[ \t]*@import\s+["']tailwindcss["'];[ \t]*\r?\n?/gm, '');
fs.writeFileSync(file, '@import "tailwindcss";\n' + css);
