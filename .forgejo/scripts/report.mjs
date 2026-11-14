// Reports a `tofu plan` from a Forgejo Actions job back to Forgejo.
//
//   node report.mjs pr    <plan.txt> <exitcode>   comment on the PR (updated in place)
//   node report.mjs drift <plan.txt> <exitcode>   open/update/close the drift issue
//
// Only the resource headers ("# x will be created", "# y has changed") and
// the summary line are posted — never the attribute diff, which can carry
// values that aren't marked sensitive (cloud-init, NetBox comments, ...).
// The full plan stays in the job log.
//
// Env: GITHUB_SERVER_URL, GITHUB_REPOSITORY (set by the runner), TOKEN,
// PR_NUMBER (pr), RUN_URL.
import { readFileSync } from "node:fs";

const [mode, planFile, exitArg] = process.argv.slice(2);
const exit = Number(exitArg); // tofu plan -detailed-exitcode: 0 none, 1 error, 2 changes
const api = `${process.env.GITHUB_SERVER_URL}/api/v1/repos/${process.env.GITHUB_REPOSITORY}`;
const MARK = mode === "pr" ? "<!-- tofu-plan -->" : "<!-- tofu-drift -->";
const DRIFT_TITLE = "Tofu drift: plan not empty";

async function call(method, path, body) {
  const res = await fetch(api + path, {
    method,
    headers: {
      Authorization: `token ${process.env.TOKEN}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: body && JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`${method} ${path}: ${res.status} ${await res.text()}`);
  return res.status === 204 ? null : res.json();
}

function summary() {
  const lines = readFileSync(planFile, "utf8").split("\n");
  const keep = lines.filter((l) =>
    /^\s*# \S.* (will be|must be|has been|has changed|is tainted)/.test(l) ||
    /^(Plan:|No changes\.|Changes to Outputs:|Error:)/.test(l.trim()),
  );
  return keep.map((l) => l.trim()).join("\n") || "(no summary lines found — see the job log)";
}

function body(title) {
  const state = { 0: "no changes", 1: "**plan failed**", 2: "changes" }[exit] ?? `exit ${exit}`;
  return `${MARK}\n### ${title}: ${state}\n\n\`\`\`\n${summary()}\n\`\`\`\n\n` +
    `Full plan (attribute diff): [job log](${process.env.RUN_URL})`;
}

if (mode === "pr") {
  const n = process.env.PR_NUMBER;
  const comments = await call("GET", `/issues/${n}/comments`);
  const mine = comments.find((c) => c.body.startsWith(MARK));
  const text = body("tofu plan");
  if (mine) await call("PATCH", `/issues/comments/${mine.id}`, { body: text });
  else await call("POST", `/issues/${n}/comments`, { body: text });
} else if (mode === "drift") {
  const open = await call("GET", `/issues?state=open&type=issues&limit=50`);
  const issue = open.find((i) => i.body?.startsWith(MARK));
  if (exit === 0) {
    if (issue) {
      await call("POST", `/issues/${issue.number}/comments`, { body: "Plan is empty again — closing." });
      await call("PATCH", `/issues/${issue.number}`, { state: "closed" });
    }
  } else {
    const text = body("Nightly drift check");
    if (issue) {
      await call("PATCH", `/issues/${issue.number}`, { body: text });
    } else {
      await call("POST", `/issues`, { title: DRIFT_TITLE, body: text });
    }
  }
} else {
  console.error("usage: report.mjs pr|drift <plan.txt> <exitcode>");
  process.exit(64);
}
