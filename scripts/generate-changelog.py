#!/usr/bin/env python3
"""
Generate Ora release notes from merged pull requests between two tags.

Usage:
  ./scripts/generate-changelog.py <previous-tag> <new-tag> <owner/repo>

The script collects merged PR metadata with GitHub CLI, asks Codex CLI to write:
  - Markdown release notes for GitHub Releases
  - HTML release notes for Sparkle

If Codex is unavailable, or if --no-llm is used, it falls back to a small local
renderer that filters low-signal work and writes basic notes.
"""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import textwrap
from pathlib import Path
from string import Template
from typing import Any


DEFAULT_MODEL = "gpt-5"
SECTION_ORDER = ["Highlights", "Improvements", "Fixes", "Under the hood"]
SPARKLE_SECTION_ORDER = ["Highlights", "Improvements"]
SCRIPT_DIR = Path(__file__).resolve().parent
PROMPT_TEMPLATE_PATH = SCRIPT_DIR / "prompts" / "changelog_prompt.txt"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate Markdown and Sparkle release notes from merged pull requests."
    )
    parser.add_argument("previous_tag", help="Starting tag, for example v0.2.11")
    parser.add_argument("new_tag", help="Ending tag, for example v0.2.12")
    parser.add_argument("repository", help="GitHub repository in owner/name format")
    parser.add_argument(
        "--output-markdown",
        default="CHANGELOG.md",
        help="Path for the generated Markdown changelog",
    )
    parser.add_argument(
        "--output-html",
        default="sparkle_release_notes.html",
        help="Path for the generated Sparkle HTML notes",
    )
    parser.add_argument(
        "--model",
        default=os.environ.get("ORA_CHANGELOG_MODEL", os.environ.get("OPENAI_MODEL", DEFAULT_MODEL)),
        help="Codex model to use for the rewrite step",
    )
    parser.add_argument(
        "--no-llm",
        action="store_true",
        help="Skip Codex and use deterministic fallback notes",
    )
    parser.add_argument(
        "--review",
        action="store_true",
        help="Open the generated files in $EDITOR after writing them",
    )
    return parser.parse_args()


def ensure_tool(name: str) -> None:
    if not shutil.which(name):
        raise RuntimeError(f"required tool not found: {name}")


def run_command(cmd: list[str]) -> str:
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        stderr = result.stderr.strip()
        stdout = result.stdout.strip()
        raise RuntimeError(stderr or stdout or f"command failed: {' '.join(cmd)}")
    return result.stdout


def git_ref_exists(ref: str) -> bool:
    result = subprocess.run(
        ["git", "rev-parse", "--verify", "--quiet", ref],
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


def commits_in_range(previous_tag: str, new_tag: str) -> list[str]:
    if not git_ref_exists(f"refs/tags/{previous_tag}"):
        raise RuntimeError(f"tag not found: {previous_tag}")

    revision_range = f"{previous_tag}..{new_tag}" if git_ref_exists(f"refs/tags/{new_tag}") else f"{previous_tag}..HEAD"
    output = run_command(["git", "rev-list", "--reverse", revision_range])
    return [line.strip() for line in output.splitlines() if line.strip()]


def fetch_pr_numbers_for_commit(repository: str, commit_sha: str) -> list[int]:
    output = run_command(
        [
            "gh",
            "api",
            "-H",
            "Accept: application/vnd.github+json",
            f"repos/{repository}/commits/{commit_sha}/pulls",
        ]
    )
    data = json.loads(output)
    return [entry["number"] for entry in data if isinstance(entry.get("number"), int)]


def fetch_pr_details(repository: str, pr_number: int) -> dict[str, Any]:
    output = run_command(
        [
            "gh",
            "pr",
            "view",
            str(pr_number),
            "--repo",
            repository,
            "--json",
            "number,title,author,url,labels,mergedAt",
        ]
    )
    data = json.loads(output)
    author = data.get("author") or {}
    labels = data.get("labels") or []
    return {
        "number": data["number"],
        "title": data["title"].strip(),
        "author": (author.get("login") or "unknown").strip(),
        "url": data["url"],
        "labels": [label["name"] for label in labels if label.get("name")],
        "mergedAt": data.get("mergedAt") or "",
    }


def collect_pull_requests(previous_tag: str, new_tag: str, repository: str) -> list[dict[str, Any]]:
    pr_numbers: set[int] = set()
    for commit_sha in commits_in_range(previous_tag, new_tag):
        pr_numbers.update(fetch_pr_numbers_for_commit(repository, commit_sha))

    prs = [fetch_pr_details(repository, pr_number) for pr_number in sorted(pr_numbers)]
    prs = [pr for pr in prs if pr["mergedAt"]]
    prs.sort(key=lambda pr: (pr["mergedAt"], pr["number"]))
    return prs


def release_title_from_tag(tag: str) -> str:
    version = tag[1:] if tag.startswith("v") else tag
    return f"Ora {version}"


def compare_url(repository: str, previous_tag: str, new_tag: str) -> str:
    return f"https://github.com/{repository}/compare/{previous_tag}...{new_tag}"


def load_prompt_template() -> Template:
    return Template(PROMPT_TEMPLATE_PATH.read_text(encoding="utf-8"))


def codex_output_schema() -> dict[str, Any]:
    return {
        "type": "object",
        "properties": {
            "markdown": {"type": "string"},
            "html": {"type": "string"},
        },
        "required": ["markdown", "html"],
        "additionalProperties": False,
    }


def call_codex(prompt: str, model: str) -> dict[str, str]:
    ensure_tool("codex")

    with tempfile.TemporaryDirectory(prefix="ora-changelog-") as temp_dir:
        temp_path = Path(temp_dir)
        schema_path = temp_path / "schema.json"
        output_path = temp_path / "response.json"

        schema_path.write_text(json.dumps(codex_output_schema(), indent=2), encoding="utf-8")

        result = subprocess.run(
            [
                "codex",
                "exec",
                "-C",
                os.getcwd(),
                "--sandbox",
                "read-only",
                "--output-schema",
                str(schema_path),
                "--output-last-message",
                str(output_path),
                "-m",
                model,
                "-",
            ],
            input=prompt,
            text=True,
            capture_output=True,
        )

        if result.returncode != 0:
            stderr = result.stderr.strip()
            stdout = result.stdout.strip()
            raise RuntimeError(stderr or stdout or "codex exec failed")

        if not output_path.exists():
            raise RuntimeError("codex did not return a final message")

        payload = json.loads(output_path.read_text(encoding="utf-8"))
        markdown = payload.get("markdown", "").strip()
        html_output = payload.get("html", "").strip()
        if not markdown or not html_output:
            raise RuntimeError("codex returned empty release notes")

        return {"markdown": markdown + "\n", "html": html_output + "\n"}


def normalize_summary(text: str) -> str:
    cleaned = re.sub(r"\s+", " ", (text or "").strip())
    cleaned = cleaned.strip("-* ")
    if not cleaned:
        return ""
    return cleaned.rstrip(".") + "."


def strip_conventional_prefix(title: str) -> str:
    return re.sub(r"^[a-z]+(?:\([^)]+\))?!?:\s*", "", title, flags=re.IGNORECASE).strip()


def clean_title_for_users(title: str) -> str:
    cleaned = strip_conventional_prefix(title)
    cleaned = re.sub(r"\bUI\b", "interface", cleaned)
    cleaned = re.sub(r"\bUX\b", "experience", cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned).strip(" -")
    if cleaned:
        cleaned = cleaned[0].upper() + cleaned[1:]
    return normalize_summary(cleaned or title)


def is_low_signal(pr: dict[str, Any]) -> bool:
    labels = {label.lower() for label in pr.get("labels", [])}
    title = pr.get("title", "").lower()

    if {"feature", "improvement", "fix", "bug", "bugfix", "ui", "security"} & labels:
        if re.search(r"\b(type|typing|lint|format|formatting|typo|readme)\b", title):
            return True
        return False

    low_signal_labels = {
        "internal",
        "refactor",
        "chore",
        "docs",
        "documentation",
        "build",
        "ci",
        "tests",
        "dependencies",
    }
    if labels & low_signal_labels:
        return True

    low_signal_patterns = [
        r"\btype(?:s|ing)?\b",
        r"\blint\b",
        r"\bformat(?:ting)?\b",
        r"\btypo\b",
        r"\breadme\b",
        r"\bdocs?\b",
        r"\brefactor\b",
        r"\bcleanup\b",
        r"\btest(?:s|ing)?\b",
        r"\bci\b",
        r"\bbuild\b",
        r"\brelease\b",
        r"\bdependency\b",
        r"\bbump\b",
    ]
    return any(re.search(pattern, title) for pattern in low_signal_patterns)


def classify_pr(pr: dict[str, Any]) -> str:
    labels = {label.lower() for label in pr.get("labels", [])}
    title = pr.get("title", "").lower()

    if {"feature", "security"} & labels:
        return "Highlights"
    if "ui" in labels and any(token in title for token in ["new", "add", "support", "improve", "redesign"]):
        return "Highlights"
    if {"fix", "bug", "bugfix"} & labels or any(token in title for token in ["fix", "crash", "resolve"]):
        return "Fixes"
    if {"internal", "refactor", "chore", "build", "ci", "docs", "dependencies"} & labels:
        return "Under the hood"
    return "Improvements"


def build_fallback_sections(prs: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    sections = {section: [] for section in SECTION_ORDER}
    for pr in prs:
        if is_low_signal(pr):
            continue
        sections[classify_pr(pr)].append(pr)
    return sections


def markdown_attribution(pr: dict[str, Any]) -> str:
    return (
        f"*(by [@{pr['author']}](https://github.com/{pr['author']}) "
        f"in [#{pr['number']}]({pr['url']}))*"
    )


def html_attribution(pr: dict[str, Any]) -> str:
    author = html.escape(pr["author"])
    url = html.escape(pr["url"])
    return (
        f'<em>(by <a href="https://github.com/{author}">@{author}</a> '
        f'in <a href="{url}">#{pr["number"]}</a>)</em>'
    )


def render_markdown_fallback(title: str, compare_link: str, sections: dict[str, list[dict[str, Any]]]) -> str:
    lines = [f"## {title}", ""]

    for section in SECTION_ORDER:
        items = sections.get(section, [])
        if not items:
            continue
        lines.append(f"### {section}")
        for pr in items:
            lines.append(f"- {clean_title_for_users(pr['title'])} {markdown_attribution(pr)}")
        lines.append("")

    lines.extend(["### Full Changelog", compare_link, ""])
    return "\n".join(lines)


def render_html_fallback(title: str, compare_link: str, sections: dict[str, list[dict[str, Any]]]) -> str:
    improvements = list(sections.get("Improvements", [])) + list(sections.get("Fixes", []))
    sparkle_sections = {
        "Highlights": sections.get("Highlights", []),
        "Improvements": improvements,
    }

    parts = ["<!doctype html>", "<html>", "<body>", f"<h2>{html.escape(title)}</h2>"]
    for section in SPARKLE_SECTION_ORDER:
        items = sparkle_sections.get(section, [])
        if not items:
            continue
        parts.append(f"<h3>{html.escape(section)}</h3>")
        parts.append("<ul>")
        for pr in items[:6]:
            summary = html.escape(clean_title_for_users(pr["title"]))
            parts.append(f"<li>{summary} {html_attribution(pr)}</li>")
        parts.append("</ul>")

    parts.append(
        f'<p><strong>Full Changelog:</strong> <a href="{html.escape(compare_link)}">{html.escape(compare_link)}</a></p>'
    )
    parts.extend(["</body>", "</html>"])
    return "\n".join(parts) + "\n"


def render_empty_release(title: str, compare_link: str) -> dict[str, str]:
    markdown = textwrap.dedent(
        f"""\
        ## {title}

        ### Full Changelog
        {compare_link}
        """
    )
    html_output = textwrap.dedent(
        f"""\
        <!doctype html>
        <html>
        <body>
        <h2>{html.escape(title)}</h2>
        <p><strong>Full Changelog:</strong> <a href="{html.escape(compare_link)}">{html.escape(compare_link)}</a></p>
        </body>
        </html>
        """
    )
    return {"markdown": markdown, "html": html_output}


def build_prompt(
    template: Template,
    previous_tag: str,
    new_tag: str,
    repository: str,
    release_title: str,
    compare_link: str,
    prs: list[dict[str, Any]],
) -> str:
    return template.safe_substitute(
        previous_tag=previous_tag,
        new_tag=new_tag,
        repository=repository,
        release_title=release_title,
        compare_url=compare_link,
        pr_json=json.dumps(prs, indent=2),
    )


def generate_with_fallback(
    previous_tag: str,
    new_tag: str,
    repository: str,
    prs: list[dict[str, Any]],
) -> dict[str, str]:
    title = release_title_from_tag(new_tag)
    compare_link = compare_url(repository, previous_tag, new_tag)
    sections = build_fallback_sections(prs)
    return {
        "markdown": render_markdown_fallback(title, compare_link, sections),
        "html": render_html_fallback(title, compare_link, sections),
    }


def write_file(path: str, contents: str) -> None:
    output_path = Path(path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(contents, encoding="utf-8")


def open_in_editor(paths: list[str]) -> None:
    editor = os.environ.get("EDITOR", "").strip()
    if not editor:
        print("warning: --review requested, but $EDITOR is not set", file=sys.stderr)
        return
    editor_cmd = shlex.split(editor)
    for path in paths:
        subprocess.run([*editor_cmd, path], check=False)


def main() -> int:
    args = parse_args()

    ensure_tool("git")
    ensure_tool("gh")

    prs = collect_pull_requests(args.previous_tag, args.new_tag, args.repository)
    if not prs:
        outputs = render_empty_release(
            release_title_from_tag(args.new_tag),
            compare_url(args.repository, args.previous_tag, args.new_tag),
        )
        write_file(args.output_markdown, outputs["markdown"])
        write_file(args.output_html, outputs["html"])
        print(f"Wrote {args.output_markdown}")
        print(f"Wrote {args.output_html}")
        return 0

    if args.no_llm:
        outputs = generate_with_fallback(args.previous_tag, args.new_tag, args.repository, prs)
        mode = "fallback"
    else:
        prompt = build_prompt(
            load_prompt_template(),
            args.previous_tag,
            args.new_tag,
            args.repository,
            release_title_from_tag(args.new_tag),
            compare_url(args.repository, args.previous_tag, args.new_tag),
            prs,
        )
        try:
            outputs = call_codex(prompt, args.model)
            mode = "codex"
        except Exception as exc:  # noqa: BLE001
            print(f"warning: {exc}", file=sys.stderr)
            outputs = generate_with_fallback(args.previous_tag, args.new_tag, args.repository, prs)
            mode = "fallback"

    write_file(args.output_markdown, outputs["markdown"])
    write_file(args.output_html, outputs["html"])

    if args.review:
        open_in_editor([args.output_markdown, args.output_html])

    print(f"Wrote {args.output_markdown}")
    print(f"Wrote {args.output_html}")
    print(f"Mode: {mode}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
