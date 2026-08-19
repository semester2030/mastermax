import { promises as fs } from 'fs';
import path from 'path';

async function walk(dir: string, acc: string[] = []): Promise<string[]> {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  for (const e of entries) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) {
      if (e.name === 'node_modules' || e.name === 'dist' || e.name === '.tmp-jest') continue;
      await walk(p, acc);
    } else if (e.name.endsWith('.ts')) {
      acc.push(p);
    }
  }
  return acc;
}

async function main(): Promise<void> {
  const root = path.resolve(__dirname, '..');
  const files = [
    ...(await walk(path.join(root, 'src'))),
    ...(await walk(path.join(root, 'test'))),
  ];
  let fail = 0;
  const rows: { file: string; lines: number; status: string }[] = [];
  for (const file of files) {
    const text = await fs.readFile(file, 'utf8');
    const lines = text.split(/\r?\n/).length;
    let status = 'OK';
    if (lines > 800) {
      status = 'FAIL';
      fail += 1;
    } else if (lines > 500) {
      status = 'REVIEW';
    }
    rows.push({ file: path.relative(root, file), lines, status });
  }
  rows.sort((a, b) => b.lines - a.lines);
  for (const r of rows) {
    process.stdout.write(`${r.status.padEnd(7)} ${String(r.lines).padStart(4)}  ${r.file}\n`);
  }
  if (fail) {
    process.exit(1);
  }
}

main();
