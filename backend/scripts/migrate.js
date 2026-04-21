// MySQL 스키마를 init.sql 파일 기반으로 적용한다.
// 로컬 Docker 환경에서는 docker-entrypoint-initdb.d가 자동으로 init.sql을 실행해 주지만,
// Azure MySQL Flexible Server 같은 관리형 환경에서는 별도 실행 경로가 없으므로
// 이 스크립트로 수동 적용 혹은 배포 파이프라인에서 호출한다.
//
// 사용 예:
//   node --env-file-if-exists=.env scripts/migrate.js
//   (또는) npm run db:migrate

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import mysql from 'mysql2/promise';

import { loadConfig } from '../src/config.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_SQL_PATH = path.resolve(__dirname, '../docker/mysql/init.sql');

function splitStatements(sql) {
  // 간단한 statement splitter. init.sql은 FK/커멘트 등이 포함되나
  // 문자열 리터럴 내부 세미콜론을 사용하지 않으므로 이 수준으로 충분하다.
  return sql
    .split(/;\s*[\r\n]+/)
    .map((statement) => statement.trim())
    .filter((statement) => statement.length > 0 && !statement.startsWith('--'));
}

async function runMigration() {
  const sqlPath = process.env.MYSQL_INIT_SQL_PATH
    ? path.resolve(process.env.MYSQL_INIT_SQL_PATH)
    : DEFAULT_SQL_PATH;

  if (!fs.existsSync(sqlPath)) {
    throw new Error(`마이그레이션 SQL 파일을 찾을 수 없습니다: ${sqlPath}`);
  }

  const config = loadConfig();
  const { host, port, user, password, database, ssl } = config.database;

  const connection = await mysql.createConnection({
    host,
    port,
    user,
    password,
    database,
    multipleStatements: false,
    ssl: ssl ?? undefined
  });

  const rawSql = fs.readFileSync(sqlPath, 'utf8');
  const statements = splitStatements(rawSql);

  console.log(`[migrate] target=${host}:${port}/${database} statements=${statements.length}`);

  try {
    for (const [index, statement] of statements.entries()) {
      const preview = statement.replace(/\s+/g, ' ').slice(0, 80);
      console.log(`[migrate] (${index + 1}/${statements.length}) ${preview}...`);
      await connection.query(statement);
    }
    console.log('[migrate] done');
  } finally {
    await connection.end();
  }
}

runMigration().catch((error) => {
  console.error('[migrate] failed:', error);
  process.exitCode = 1;
});
