// Optional SQL regression harness, not a mobile runtime dependency.
const { PGlite } = require('@electric-sql/pglite');
const { pgcrypto } = require('@electric-sql/pglite/contrib/pgcrypto');
const { readFileSync, readdirSync } = require('node:fs');
const path = require('node:path');
const supabase = path.resolve(__dirname, '../..');
async function main() {
  if (!process.env.PGTAP_SQL) throw new Error('Set PGTAP_SQL to the pgTAP installation SQL file.');
  const pg = new PGlite({ extensions: { pgcrypto } });
  try {
    await pg.exec(readFileSync(path.join(__dirname, 'bootstrap.sql'), 'utf8'));
    await pg.exec(readFileSync(process.env.PGTAP_SQL, 'utf8'));
    const migrations = readdirSync(path.join(supabase, 'migrations')).filter(f => f.endsWith('.sql')).sort();
    const selected = process.argv.includes('--baseline') ? migrations.slice(0, 1) : migrations;
    for (const file of selected) await pg.exec(readFileSync(path.join(supabase, 'migrations', file), 'utf8'));
    let failed = false;
    let assertions = 0;
    const testDirectory = path.join(supabase, 'tests/database');
    for (const file of readdirSync(testDirectory).filter(f => f.endsWith('.test.sql')).sort()) {
      console.log(`# ${file}`);
      const results = await pg.exec(readFileSync(path.join(testDirectory, file), 'utf8'));
      for (const result of results) for (const row of result.rows) for (const value of Object.values(row)) {
        if (typeof value !== 'string' || !/^(ok|not ok|1\.\.|#)/m.test(value)) continue;
        console.log(value);
        if (/^(?:not )?ok /m.test(value)) assertions++;
        if (/^not ok|^# Looks like/m.test(value)) failed = true;
      }
    }
    if (assertions === 0 || failed) process.exitCode = 1;
  } finally { await pg.close(); }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
