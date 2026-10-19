// Run with the Codex bundled Node runtime. Requires its bundled marked package.
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
const [root, output, markedModule] = process.argv.slice(2);
const { marked } = await import(pathToFileURL(markedModule).href);
const sources = ['README.md', ...fs.readdirSync(path.join(root, 'docs')).filter(x => x.endsWith('.md')).map(x => `docs/${x}`), ...fs.readdirSync(path.join(root, 'docs/archive')).filter(x => x.endsWith('.md')).map(x => `docs/archive/${x}`)];
fs.mkdirSync(output, { recursive: true });
fs.writeFileSync(path.join(output, 'parsed-sources.json'), JSON.stringify(sources.map(source => ({source, html: marked.parse(fs.readFileSync(path.join(root, source), 'utf8'))})), null, 2));
console.log(`Prepared ${sources.length} Markdown sources`);
