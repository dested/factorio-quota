// Minimal Lua lint for the mod (there is no Lua on this machine):
// syntax errors, undefined globals, unused locals, and `X.member` reads where
// X = require("lib.y") and lib/y.lua never defines that member.
//
//   bun tools/lualint.ts mod tools      (or: bun run lint)
//
// Each argument is a root; module names are paths relative to their root
// ("lib/gui/hud.lua" -> "lib.gui.hud"), matching Factorio's require().

import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { parse } from "luaparse";
import type { Chunk, Expression, Identifier, Statement } from "luaparse/lib/ast";

const GLOBALS = new Set(
  ("game script storage prototypes helpers rendering remote defines log settings commands serpent " +
    "bit32 math table string pairs ipairs next type tostring tonumber pcall error require select setmetatable " +
    "getmetatable rawget rawset unpack data mods util assert localised_print xpcall table_size").split(" "),
);

type Parsed = { file: string; root: string; ast: Chunk };
type LocalInfo = { used: boolean; line: number; kind: "local" | "param" };

let problems = 0;
const report = (msg: string, counts = true) => {
  console.log(msg);
  if (counts) problems++;
};

function luaFiles(dir: string, out: string[] = []): string[] {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) luaFiles(p, out);
    else if (p.endsWith(".lua")) out.push(p);
  }
  return out;
}

const line = (n: { loc?: { start: { line: number } } | undefined }) => n.loc?.start.line ?? 0;
const modName = (root: string, file: string) =>
  relative(root, file).replace(/\\/g, "/").replace(/\.lua$/, "").replace(/\//g, ".");

// Every statement and expression under `body`, depth first.
function walk(body: Statement[], visit: (n: Statement | Expression) => void): void {
  const expr = (e: Expression | null): void => {
    if (!e) return;
    visit(e);
    switch (e.type) {
      case "FunctionDeclaration": stmts(e.body); break;
      case "TableConstructorExpression":
        for (const f of e.fields) {
          if (f.type === "TableKey") expr(f.key);
          expr(f.value);
        }
        break;
      case "BinaryExpression": case "LogicalExpression": expr(e.left); expr(e.right); break;
      case "UnaryExpression": expr(e.argument); break;
      case "MemberExpression": expr(e.base); break;
      case "IndexExpression": expr(e.base); expr(e.index); break;
      case "CallExpression": expr(e.base); e.arguments.forEach(expr); break;
      case "TableCallExpression": expr(e.base); expr(e.arguments); break;
      case "StringCallExpression": expr(e.base); expr(e.argument); break;
      default: break;
    }
  };
  const stmts = (list: Statement[]): void => {
    for (const s of list) {
      visit(s);
      switch (s.type) {
        case "ReturnStatement": s.arguments.forEach(expr); break;
        case "IfStatement":
          for (const c of s.clauses) {
            if (c.type !== "ElseClause") expr(c.condition);
            stmts(c.body);
          }
          break;
        case "WhileStatement": case "RepeatStatement": expr(s.condition); stmts(s.body); break;
        case "DoStatement": stmts(s.body); break;
        case "LocalStatement": s.init.forEach(expr); break;
        case "AssignmentStatement": s.variables.forEach(expr); s.init.forEach(expr); break;
        case "CallStatement": expr(s.expression); break;
        case "FunctionDeclaration": stmts(s.body); break;
        case "ForNumericStatement": expr(s.start); expr(s.end); expr(s.step); stmts(s.body); break;
        case "ForGenericStatement": s.iterators.forEach(expr); stmts(s.body); break;
        default: break;
      }
    }
  };
  stmts(body);
}

// Members a module defines on the table it returns (`M.x = ...`, `function M.x()`).
function exportsOf(ast: Chunk): Set<string> | null {
  const ret = ast.body.find((s) => s.type === "ReturnStatement");
  const arg = ret?.type === "ReturnStatement" ? ret.arguments[0] : undefined;
  if (!arg || arg.type !== "Identifier") return null;
  const name = arg.name;
  const members = new Set<string>();
  walk(ast.body, (n) => {
    if (n.type === "AssignmentStatement") {
      for (const v of n.variables) {
        if (v.type === "MemberExpression" && v.base.type === "Identifier" && v.base.name === name) members.add(v.identifier.name);
      }
    } else if (n.type === "FunctionDeclaration" && n.identifier?.type === "MemberExpression") {
      const base = n.identifier.base;
      if (base.type === "Identifier" && base.name === name) members.add(n.identifier.identifier.name);
    }
  });
  return members;
}

function lintFile({ file, root, ast }: Parsed, moduleExports: Map<string, Set<string>>): void {
  const rel = relative(root, file);
  const scopes: Map<string, LocalInfo>[] = [];
  const requires = new Map<string, string>(); // local alias -> module name

  const push = () => {
    scopes.push(new Map<string, LocalInfo>());
  };
  const pop = () => {
    const s = scopes.pop();
    if (!s) return;
    for (const [name, info] of s) {
      if (!info.used && !name.startsWith("_") && info.kind === "local") report(`UNUSED ${rel}:${info.line} local '${name}'`, false);
    }
  };
  // Not "declare": bun strips a `declare(...)` statement as a TS ambient declaration.
  const bind = (id: Identifier, kind: LocalInfo["kind"] = "local") => {
    const top = scopes[scopes.length - 1];
    if (top) top.set(id.name, { used: false, line: line(id), kind });
  };
  const use = (id: Identifier) => {
    for (let i = scopes.length - 1; i >= 0; i--) {
      const info = scopes[i]?.get(id.name);
      if (info) {
        info.used = true;
        return;
      }
    }
    if (!GLOBALS.has(id.name)) report(`GLOBAL ${rel}:${line(id)} '${id.name}'`);
  };

  const expr = (e: Expression | null): void => {
    if (!e) return;
    switch (e.type) {
      case "Identifier": use(e); break;
      case "MemberExpression": {
        expr(e.base);
        const mod = e.base.type === "Identifier" && e.indexer === "." ? requires.get(e.base.name) : undefined;
        const ex = mod ? moduleExports.get(mod) : undefined;
        if (mod && ex && e.base.type === "Identifier" && !ex.has(e.identifier.name)) {
          report(`MEMBER ${rel}:${line(e)} ${e.base.name}.${e.identifier.name} not defined in ${mod}`);
        }
        break;
      }
      case "IndexExpression": expr(e.base); expr(e.index); break;
      case "CallExpression": expr(e.base); e.arguments.forEach(expr); break;
      case "TableCallExpression": expr(e.base); expr(e.arguments); break;
      case "StringCallExpression": expr(e.base); break;
      case "BinaryExpression": case "LogicalExpression": expr(e.left); expr(e.right); break;
      case "UnaryExpression": expr(e.argument); break;
      case "TableConstructorExpression":
        for (const f of e.fields) {
          if (f.type === "TableKey") expr(f.key);
          expr(f.value);
        }
        break;
      case "FunctionDeclaration": func(e.parameters, e.body); break;
      default: break;
    }
  };
  const func = (params: Array<Identifier | { type: "VarargLiteral" }>, body: Statement[]) => {
    push();
    for (const p of params) if (p.type === "Identifier") bind(p, "param");
    block(body);
    pop();
  };
  const scoped = (body: Statement[]) => {
    push();
    block(body);
    pop();
  };
  const block = (body: Statement[]) => body.forEach(stmt);
  const stmt = (s: Statement): void => {
    switch (s.type) {
      case "LocalStatement":
        s.init.forEach(expr);
        s.variables.forEach((v, i) => {
          bind(v);
          const init = s.init[i];
          if (init?.type === "CallExpression" && init.base.type === "Identifier" && init.base.name === "require") {
            const arg = init.arguments[0];
            if (arg?.type === "StringLiteral") requires.set(v.name, arg.raw.slice(1, -1));
          }
        });
        break;
      case "AssignmentStatement": s.variables.forEach(expr); s.init.forEach(expr); break;
      case "CallStatement": expr(s.expression); break;
      case "FunctionDeclaration":
        if (s.isLocal && s.identifier?.type === "Identifier") bind(s.identifier);
        else if (s.identifier) expr(s.identifier);
        func(s.parameters, s.body);
        break;
      case "ReturnStatement": s.arguments.forEach(expr); break;
      case "IfStatement":
        for (const c of s.clauses) {
          if (c.type !== "ElseClause") expr(c.condition);
          scoped(c.body);
        }
        break;
      case "WhileStatement": expr(s.condition); scoped(s.body); break;
      case "RepeatStatement": push(); block(s.body); expr(s.condition); pop(); break;
      case "DoStatement": scoped(s.body); break;
      case "ForNumericStatement":
        expr(s.start); expr(s.end); expr(s.step);
        push(); bind(s.variable, "param"); block(s.body); pop();
        break;
      case "ForGenericStatement":
        s.iterators.forEach(expr);
        push(); s.variables.forEach((v) => bind(v, "param")); block(s.body); pop();
        break;
      default: break;
    }
  };
  push();
  block(ast.body);
  pop();
}

const roots = process.argv.slice(2);
if (roots.length === 0) {
  console.log("usage: bun tools/lualint.ts <root> [root...]");
  process.exit(2);
}
for (const root of roots) {
  const parsed: Parsed[] = [];
  for (const file of luaFiles(root)) {
    try {
      parsed.push({ file, root, ast: parse(readFileSync(file, "utf8"), { locations: true, scope: true, luaVersion: "5.2" }) });
    } catch (err) {
      report(`SYNTAX ${file}: ${err instanceof Error ? err.message : String(err)}`);
    }
  }
  const moduleExports = new Map<string, Set<string>>();
  for (const p of parsed) {
    const ex = exportsOf(p.ast);
    if (ex) moduleExports.set(modName(root, p.file), ex);
  }
  for (const p of parsed) lintFile(p, moduleExports);
}
console.log(problems ? `${problems} problem(s)` : "lint clean");
process.exit(problems ? 1 : 0);
