#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable


REPO_ROOT = Path(__file__).resolve().parents[1]
CLASSES_DIR = REPO_ROOT / "force-app" / "main" / "default" / "classes"

DEFAULT_AUTHOR = "Daniel Belini"
DEFAULT_MODIFIED_BY = "Daniel Belini"
NO_TESTS_MAPPED = "NO_TESTS_MAPPED"
RUNNABLE_TEST_SENTINEL = "N/A - classe de teste executavel"
TEST_SUPPORT_SENTINEL = "N/A - classe de apoio a testes"

MANAGED_HEADER_FIELDS = {
    "description",
    "author",
    "group",
    "last modified on",
    "last modified by",
    "test",
}

TEST_METHOD_PATTERN = re.compile(
    r"@isTest\b[\s\r\n]*(?:private|public|global)?[\s\r\n]*static[\s\r\n]+"
    r"(?:(?:testMethod)[\s\r\n]+)?void|"
    r"@IsTest\b[\s\r\n]*(?:private|public|global)?[\s\r\n]*static[\s\r\n]+"
    r"(?:(?:testMethod)[\s\r\n]+)?void",
    re.MULTILINE,
)
HEADER_BLOCK_PATTERN = re.compile(r"\A(/\*\*[\s\S]*?\n\s*\*\*/\s*)")
HEADER_FIELD_PATTERN = re.compile(r"@([^:]+?)\s*:\s*(.*)$")


@dataclass(frozen=True)
class ClassInfo:
    name: str
    path: Path
    source: str
    header_fields: dict[str, str]
    is_test_class: bool
    is_runnable_test: bool


def run_git_diff(diff_range: str) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", diff_range],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def run_git_diff_cached() -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def canonical_field_name(raw_name: str) -> str:
    return " ".join(raw_name.strip().lower().split())


def read_top_header_block(source: str) -> str | None:
    match = HEADER_BLOCK_PATTERN.match(source)
    if not match:
        return None
    block = match.group(1)
    if not any(token in block for token in ("@description", "@author", "@test")):
        return None
    return block


def parse_header_fields(source: str) -> dict[str, str]:
    block = read_top_header_block(source)
    if not block:
        return {}

    fields: dict[str, str] = {}
    current_field: str | None = None
    current_lines: list[str] = []

    def flush() -> None:
        nonlocal current_field, current_lines
        if current_field is not None:
            fields[current_field] = " ".join(part for part in current_lines if part).strip()
        current_field = None
        current_lines = []

    for raw_line in block.splitlines():
        line = raw_line.strip()
        if line.startswith("/**") or line.startswith("*/") or line.startswith("**/"):
            continue
        if line.startswith("*"):
            line = line[1:].strip()
        if line in {"", "*/", "**/"}:
            continue

        match = HEADER_FIELD_PATTERN.match(line)
        if match:
            flush()
            current_field = canonical_field_name(match.group(1))
            current_lines = [match.group(2).strip()]
            continue

        if current_field and not line.startswith("@"):
            current_lines.append(line)

    flush()
    return fields


def is_test_class(name: str, source: str) -> bool:
    return name.endswith("Test") or bool(re.search(r"@isTest\b|@IsTest\b", source))


def is_runnable_test(name: str, source: str) -> bool:
    return name.endswith("Test") or bool(TEST_METHOD_PATTERN.search(source))


def load_class_infos() -> dict[str, ClassInfo]:
    infos: dict[str, ClassInfo] = {}
    for path in sorted(CLASSES_DIR.glob("*.cls")):
        source = path.read_text(encoding="utf-8")
        name = path.stem
        infos[name] = ClassInfo(
            name=name,
            path=path,
            source=source,
            header_fields=parse_header_fields(source),
            is_test_class=is_test_class(name, source),
            is_runnable_test=is_runnable_test(name, source),
        )
    return infos


def build_dependencies(prod_names: list[str], infos: dict[str, ClassInfo]) -> dict[str, set[str]]:
    dependencies = {name: set() for name in prod_names}
    for class_name in prod_names:
        source = infos[class_name].source
        for dependency_name in prod_names:
            if dependency_name in {class_name, "TriggerHandler"}:
                continue
            if re.search(rf"\b{re.escape(dependency_name)}\b", source):
                dependencies[class_name].add(dependency_name)
    return dependencies


def build_callers(dependencies: dict[str, set[str]]) -> dict[str, set[str]]:
    callers = {name: set() for name in dependencies}
    for source_name, dependency_names in dependencies.items():
        for dependency_name in dependency_names:
            callers[dependency_name].add(source_name)
    return callers


def compute_test_mapping(infos: dict[str, ClassInfo]) -> dict[str, list[str]]:
    prod_names = sorted(name for name, info in infos.items() if not info.is_test_class)
    runnable_tests = sorted(
        name for name, info in infos.items() if info.is_runnable_test
    )

    dependencies = build_dependencies(prod_names, infos)
    callers = build_callers(dependencies)
    mapping: dict[str, set[str]] = {name: set() for name in prod_names}

    for test_name in runnable_tests:
        test_source = infos[test_name].source
        for prod_name in prod_names:
            if re.search(rf"\b{re.escape(prod_name)}\b", test_source):
                mapping[prod_name].add(test_name)
            if test_name.startswith(prod_name) and test_name.endswith("Test"):
                mapping[prod_name].add(test_name)

    for prod_name in prod_names:
        if not prod_name.endswith("TriggerHandler"):
            continue

        prefix = prod_name[: -len("TriggerHandler")]
        for candidate in (f"{prefix}TriggerTest", f"{prefix}TriggerHandlerTest"):
            if candidate in runnable_tests:
                mapping[prod_name].add(candidate)
                for dependency_name in dependencies[prod_name]:
                    mapping[dependency_name].add(candidate)

        if not mapping[prod_name]:
            for dependency_name in dependencies[prod_name]:
                dependency_tests = mapping[dependency_name]
                preferred_tests = {
                    test_name
                    for test_name in dependency_tests
                    if test_name.startswith(prefix) or dependency_name.startswith(prefix)
                }
                mapping[prod_name].update(preferred_tests)
            if not mapping[prod_name]:
                for dependency_name in dependencies[prod_name]:
                    mapping[prod_name].update(mapping[dependency_name])

    family_defaults = {
        "IntegracaoSAP": ["IntegracaoSAPTest"],
        "IntegracaoNivello": ["IntegracaoNivelloTest"],
        "NivelloToken": ["NivelloTokenTest"],
        "VOToken": ["TokenAPIVOWsTest"],
        "MessagingSessionSLA": ["MessagingSessionSLABatchTest"],
    }

    for prod_name in prod_names:
        if mapping[prod_name]:
            continue
        for prefix, candidate_tests in family_defaults.items():
            if not prod_name.startswith(prefix):
                continue
            for candidate in candidate_tests:
                if candidate in runnable_tests:
                    mapping[prod_name].add(candidate)

    for prod_name in prod_names:
        if mapping[prod_name]:
            continue
        inherited_tests: set[str] = set()
        for caller_name in callers[prod_name]:
            inherited_tests.update(mapping[caller_name])
        mapping[prod_name].update(inherited_tests)

    return {name: sorted(tests) for name, tests in mapping.items()}


def split_header_test_value(raw_value: str) -> list[str]:
    normalized = raw_value.strip()
    if not normalized or normalized in {
        NO_TESTS_MAPPED,
        RUNNABLE_TEST_SENTINEL,
        TEST_SUPPORT_SENTINEL,
    }:
        return []
    return [part.strip() for part in normalized.split(",") if part.strip()]


def expected_test_value(class_info: ClassInfo, mapping: dict[str, list[str]]) -> str:
    if class_info.is_runnable_test:
        return RUNNABLE_TEST_SENTINEL
    if class_info.is_test_class:
        return TEST_SUPPORT_SENTINEL
    tests = mapping.get(class_info.name, [])
    if not tests:
        return NO_TESTS_MAPPED
    return ", ".join(tests)


def render_field_lines(field_name: str, value: str) -> list[str]:
    prefix = f" * @{field_name:<18}: "
    continuation_prefix = " * " + " " * 20 + "  "
    if not value:
        return [prefix.rstrip()]
    if len(prefix) + len(value) <= 118:
        return [prefix + value]

    parts = [part.strip() for part in value.split(",")]
    lines: list[str] = []
    current = ""
    for part in parts:
        candidate = part if not current else f"{current}, {part}"
        if len(prefix) + len(candidate) <= 118:
            current = candidate
            continue
        if current:
            lines.append(current + ",")
        current = part
    if current:
        lines.append(current)

    rendered: list[str] = []
    for index, line in enumerate(lines):
        rendered.append((prefix if index == 0 else continuation_prefix) + line)
    return rendered


def build_header(
    class_info: ClassInfo,
    mapping: dict[str, list[str]],
    modified_on: str,
    modified_by: str,
    default_author: str,
    preserve_existing_metadata: bool = False,
) -> str:
    existing = class_info.header_fields
    description = existing.get("description", "")
    author = existing.get("author", "") or default_author
    group = existing.get("group", "")
    if preserve_existing_metadata:
        modified_on = existing.get("last modified on", "").strip() or modified_on
        modified_by = existing.get("last modified by", "").strip() or modified_by
    test_value = expected_test_value(class_info, mapping)

    lines = ["/**"]
    lines.extend(render_field_lines("description", description))
    lines.extend(render_field_lines("author", author))
    lines.extend(render_field_lines("group", group))
    lines.extend(render_field_lines("last modified on", modified_on))
    lines.extend(render_field_lines("last modified by", modified_by))
    lines.extend(render_field_lines("test", test_value))
    lines.append(" **/")
    return "\n".join(lines)


def replace_header(source: str, header: str) -> str:
    match = HEADER_BLOCK_PATTERN.match(source)
    if match and any(token in match.group(1) for token in ("@description", "@author", "@test")):
        updated = header + "\n" + source[match.end() :].lstrip("\n")
    else:
        updated = header + "\n" + source.lstrip("\n")
    if not updated.endswith("\n"):
        updated += "\n"
    return updated


def sync_headers(
    infos: dict[str, ClassInfo],
    mapping: dict[str, list[str]],
    modified_on: str,
    modified_by: str,
    default_author: str,
) -> tuple[int, int, list[Path]]:
    changed_count = 0
    changed_paths: list[Path] = []
    for class_info in infos.values():
        header = build_header(
            class_info=class_info,
            mapping=mapping,
            modified_on=modified_on,
            modified_by=modified_by,
            default_author=default_author,
        )
        updated_source = replace_header(class_info.source, header)
        if updated_source == class_info.source:
            continue
        class_info.path.write_text(updated_source, encoding="utf-8")
        changed_count += 1
        changed_paths.append(class_info.path)

    unmapped_prod_classes = sum(
        1
        for class_info in infos.values()
        if not class_info.is_test_class and not mapping.get(class_info.name)
    )
    return changed_count, unmapped_prod_classes, changed_paths


def resolve_target_class_names(
    infos: dict[str, ClassInfo],
    mapping: dict[str, list[str]],
    staged_only: bool,
    explicit_paths: Iterable[str],
) -> list[str]:
    path_candidates: set[str] = set(explicit_paths)
    if staged_only:
        path_candidates.update(run_git_diff_cached())

    class_names = {
        Path(path).stem
        for path in path_candidates
        if path.startswith("force-app/main/default/classes/") and path.endswith(".cls")
    }

    if not class_names:
        return []

    impacted_names = set(class_names)
    changed_runnable_tests = {
        class_name
        for class_name in class_names
        if class_name in infos and infos[class_name].is_runnable_test
    }

    if changed_runnable_tests:
        for prod_name, test_names in mapping.items():
            if changed_runnable_tests.intersection(test_names):
                impacted_names.add(prod_name)

    return sorted(name for name in impacted_names if name in infos)


def sync_test_tags(
    infos: dict[str, ClassInfo],
    mapping: dict[str, list[str]],
    modified_on: str,
    modified_by: str,
    default_author: str,
    staged_only: bool,
    explicit_paths: Iterable[str],
) -> list[Path]:
    target_names = resolve_target_class_names(
        infos=infos,
        mapping=mapping,
        staged_only=staged_only,
        explicit_paths=explicit_paths,
    )

    changed_paths: list[Path] = []
    for class_name in target_names:
        class_info = infos[class_name]
        header = build_header(
            class_info=class_info,
            mapping=mapping,
            modified_on=modified_on,
            modified_by=modified_by,
            default_author=default_author,
            preserve_existing_metadata=True,
        )
        updated_source = replace_header(class_info.source, header)
        if updated_source == class_info.source:
            continue
        class_info.path.write_text(updated_source, encoding="utf-8")
        changed_paths.append(class_info.path)
    return changed_paths


def validate_headers(
    infos: dict[str, ClassInfo],
    mapping: dict[str, list[str]],
    modified_on: str,
    modified_by: str,
    default_author: str,
) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    runnable_tests = {
        name for name, class_info in infos.items() if class_info.is_runnable_test
    }

    for class_info in infos.values():
        fields = class_info.header_fields
        missing_fields = sorted(MANAGED_HEADER_FIELDS - set(fields))
        if missing_fields:
            errors.append(
                f"{class_info.path.relative_to(REPO_ROOT)}: header incompleto ({', '.join(missing_fields)})"
            )
            continue

        expected_value = expected_test_value(class_info, mapping)
        actual_value = fields.get("test", "").strip()
        if split_header_test_value(actual_value) != split_header_test_value(expected_value):
            if actual_value != expected_value:
                errors.append(
                    f"{class_info.path.relative_to(REPO_ROOT)}: @test divergente. "
                    f"Esperado='{expected_value}' Atual='{actual_value}'"
                )

        if not class_info.is_test_class:
            resolved_tests = split_header_test_value(actual_value)
            missing_tests = [
                test_name
                for test_name in resolved_tests
                if test_name not in runnable_tests
            ]
            if missing_tests:
                errors.append(
                    f"{class_info.path.relative_to(REPO_ROOT)}: testes inexistentes/inexecutaveis no header ({', '.join(missing_tests)})"
                )
            if actual_value == NO_TESTS_MAPPED:
                warnings.append(
                    f"{class_info.path.relative_to(REPO_ROOT)}: sem classe de teste executavel mapeada"
                )

        if fields.get("last modified on", "").strip() != modified_on:
            warnings.append(
                f"{class_info.path.relative_to(REPO_ROOT)}: @last modified on difere do valor esperado ({modified_on})"
            )
        if fields.get("last modified by", "").strip() != modified_by:
            warnings.append(
                f"{class_info.path.relative_to(REPO_ROOT)}: @last modified by difere do valor esperado ({modified_by})"
            )
        if not fields.get("author", "").strip():
            warnings.append(
                f"{class_info.path.relative_to(REPO_ROOT)}: @author vazio"
            )

    return errors, warnings


def write_github_output(path: Path, outputs: dict[str, str]) -> None:
    with path.open("a", encoding="utf-8") as handle:
        for key, value in outputs.items():
            handle.write(f"{key}={value}\n")


def collect_tests(
    infos: dict[str, ClassInfo],
    diff_range: str,
    metadata_pattern: str,
    strict_changed_prod: bool,
) -> tuple[dict[str, str], list[str]]:
    changed_files = run_git_diff(diff_range)
    metadata_regex = re.compile(metadata_pattern)
    relevant_changes = [path for path in changed_files if metadata_regex.search(path)]
    apex_changes = [
        path
        for path in relevant_changes
        if path.startswith("force-app/main/default/classes/") and path.endswith(".cls")
    ]

    selected_tests: set[str] = set()
    changed_prod_classes: list[str] = []
    missing_headers: list[str] = []
    invalid_test_references: list[str] = []
    runnable_tests = {
        name for name, class_info in infos.items() if class_info.is_runnable_test
    }

    for path in apex_changes:
        class_name = Path(path).stem
        class_info = infos.get(class_name)
        if not class_info:
            continue
        if class_info.is_runnable_test:
            selected_tests.add(class_name)
            continue
        if class_info.is_test_class:
            continue

        changed_prod_classes.append(class_name)
        header_tests = split_header_test_value(class_info.header_fields.get("test", ""))
        if not header_tests:
            missing_headers.append(class_name)
            continue

        missing_for_class = [
            test_name for test_name in header_tests if test_name not in runnable_tests
        ]
        if missing_for_class:
            invalid_test_references.append(
                f"{class_name}: {', '.join(missing_for_class)}"
            )
            continue

        selected_tests.update(header_tests)

    strict_errors: list[str] = []
    if strict_changed_prod and missing_headers:
        strict_errors.append(
            "Classes Apex alteradas sem @test executavel: " + ", ".join(sorted(missing_headers))
        )
    if strict_changed_prod and invalid_test_references:
        strict_errors.append(
            "Headers @test invalidos: " + " | ".join(sorted(invalid_test_references))
        )

    selection_reason = "no_metadata_changes"
    test_level = "RunLocalTests"
    if relevant_changes:
        if strict_errors:
            selection_reason = "invalid_test_header"
        elif selected_tests:
            test_level = "RunSpecifiedTests"
            selection_reason = "header_mapping"
        else:
            selection_reason = "fallback_local_tests"

    outputs = {
        "has_changes": "true" if relevant_changes else "false",
        "apex_classes": " ".join(sorted(changed_prod_classes)),
        "test_classes": " ".join(sorted(selected_tests)),
        "test_level": test_level,
        "selection_reason": selection_reason,
        "missing_test_mappings": " ".join(sorted(missing_headers)),
        "invalid_test_headers": " | ".join(sorted(invalid_test_references)),
        "changed_files_count": str(len(relevant_changes)),
    }
    return outputs, strict_errors


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Analisa classes Apex, sincroniza headers @test e coleta testes para CI."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    sync_parser = subparsers.add_parser("sync-headers")
    sync_parser.add_argument("--date", default=datetime.now().strftime("%m-%d-%Y"))
    sync_parser.add_argument("--modified-by", default=DEFAULT_MODIFIED_BY)
    sync_parser.add_argument("--default-author", default=DEFAULT_AUTHOR)

    sync_tags_parser = subparsers.add_parser("sync-test-tags")
    sync_tags_parser.add_argument("--date", default=datetime.now().strftime("%m-%d-%Y"))
    sync_tags_parser.add_argument("--modified-by", default=DEFAULT_MODIFIED_BY)
    sync_tags_parser.add_argument("--default-author", default=DEFAULT_AUTHOR)
    sync_tags_parser.add_argument("--staged", action="store_true")
    sync_tags_parser.add_argument("--paths", nargs="*", default=[])
    sync_tags_parser.add_argument("--paths-only", action="store_true")

    validate_parser = subparsers.add_parser("validate")
    validate_parser.add_argument("--date", default=datetime.now().strftime("%m-%d-%Y"))
    validate_parser.add_argument("--modified-by", default=DEFAULT_MODIFIED_BY)
    validate_parser.add_argument("--default-author", default=DEFAULT_AUTHOR)
    validate_parser.add_argument("--fail-on-warning", action="store_true")

    collect_parser = subparsers.add_parser("collect-tests")
    collect_parser.add_argument("--diff-range", required=True)
    collect_parser.add_argument("--metadata-pattern", required=True)
    collect_parser.add_argument("--github-output")
    collect_parser.add_argument("--strict-changed-prod", action="store_true")

    return parser.parse_args()


def main() -> int:
    args = parse_args()
    infos = load_class_infos()
    mapping = compute_test_mapping(infos)

    if args.command == "sync-headers":
        changed_count, unmapped_count, _ = sync_headers(
            infos=infos,
            mapping=mapping,
            modified_on=args.date,
            modified_by=args.modified_by,
            default_author=args.default_author,
        )
        print(
            f"Headers sincronizados: {changed_count} arquivo(s) atualizados | "
            f"classes produtivas sem mapeamento: {unmapped_count}"
        )
        return 0

    if args.command == "sync-test-tags":
        changed_paths = sync_test_tags(
            infos=infos,
            mapping=mapping,
            modified_on=args.date,
            modified_by=args.modified_by,
            default_author=args.default_author,
            staged_only=args.staged,
            explicit_paths=args.paths,
        )
        if args.paths_only:
            for path in changed_paths:
                print(path.relative_to(REPO_ROOT))
        else:
            print(
                f"Tags @test sincronizadas: {len(changed_paths)} arquivo(s) atualizados"
            )
            for path in changed_paths:
                print(path.relative_to(REPO_ROOT))
        return 0

    if args.command == "validate":
        errors, warnings = validate_headers(
            infos=infos,
            mapping=mapping,
            modified_on=args.date,
            modified_by=args.modified_by,
            default_author=args.default_author,
        )
        if warnings:
            print("Warnings:")
            for warning in warnings:
                print(f"- {warning}")
        if errors:
            print("Errors:")
            for error in errors:
                print(f"- {error}")
            return 1
        if args.fail_on_warning and warnings:
            return 1
        print("Headers Apex validados com sucesso.")
        return 0

    if args.command == "collect-tests":
        outputs, strict_errors = collect_tests(
            infos=infos,
            diff_range=args.diff_range,
            metadata_pattern=args.metadata_pattern,
            strict_changed_prod=args.strict_changed_prod,
        )
        if args.github_output:
            write_github_output(Path(args.github_output), outputs)
        for key, value in outputs.items():
            print(f"{key}={value}")
        if strict_errors:
            for error in strict_errors:
                print(error, file=sys.stderr)
            return 1
        return 0

    raise ValueError(f"Comando nao suportado: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())
