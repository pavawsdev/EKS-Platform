#!/usr/bin/env python3
"""Filter a Trivy JSON vulnerability report down to Critical/High findings
and emit a customer-friendly CSV + JSON summary (CVE ID, package, installed
version, fixed version, severity only - not the full Trivy schema).

This is a reporting step, not a gate: it always exits 0. The actual pass/
fail decision for the pipeline already happens via the SARIF upload (GitHub
code scanning) and, for image scans, Trivy's own exit-code=1 - see
_app-ci.yml. Duplicating that logic here would mean two different places
deciding whether a vulnerability blocks the build.
"""

import argparse
import csv
import json
import sys

SEVERITIES = {"CRITICAL", "HIGH"}
FIELDS = ["cve_id", "package", "installed_version", "fixed_version", "severity"]


def load_trivy_report(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def extract_findings(report):
    findings = []
    for result in report.get("Results") or []:
        for vuln in result.get("Vulnerabilities") or []:
            severity = (vuln.get("Severity") or "").upper()
            if severity not in SEVERITIES:
                continue
            findings.append(
                {
                    "cve_id": vuln.get("VulnerabilityID", ""),
                    "package": vuln.get("PkgName", ""),
                    "installed_version": vuln.get("InstalledVersion", ""),
                    "fixed_version": vuln.get("FixedVersion") or "not yet available",
                    "severity": severity,
                }
            )
    # Critical first, then High; alphabetical by CVE ID within each group.
    findings.sort(key=lambda f: (f["severity"] != "CRITICAL", f["cve_id"]))
    return findings


def write_json(findings, path):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(findings, f, indent=2)
        f.write("\n")


def write_csv(findings, path):
    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(findings)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="Path to a Trivy JSON report (trivy ... --format json)")
    parser.add_argument("--json-out", default="vulnerability-report.json")
    parser.add_argument("--csv-out", default="vulnerability-report.csv")
    args = parser.parse_args()

    try:
        report = load_trivy_report(args.input)
    except (OSError, json.JSONDecodeError) as e:
        print(f"::error::Could not read Trivy report at {args.input}: {e}", file=sys.stderr)
        sys.exit(1)

    findings = extract_findings(report)
    write_json(findings, args.json_out)
    write_csv(findings, args.csv_out)

    print(f"{len(findings)} Critical/High finding(s) written to {args.json_out} and {args.csv_out}")
    for f in findings:
        print(f"  [{f['severity']}] {f['cve_id']} - {f['package']} {f['installed_version']} (fix: {f['fixed_version']})")


if __name__ == "__main__":
    main()
