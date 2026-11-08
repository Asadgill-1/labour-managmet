#!/usr/bin/env python3
"""Fail if a PRD requirement is untracked, or marked done without evidence (AI-02, AI-03)."""
import re
import sys
from pathlib import Path

REQ = re.compile(r'\b[A-Z]{2,6}-\d{2}\b')
STATES = {'NOT_STARTED', 'IN_PROGRESS', 'BLOCKED', 'IMPLEMENTED_UNVERIFIED', 'VERIFIED', 'OWNER_ACCEPTED'}
DONE = {'VERIFIED', 'OWNER_ACCEPTED'}


def problems(prd, matrix):
    """Matrix rows: | ID | Ch | Summary | Tasks | Status | Tests | Evidence |"""
    found, seen, prd_ids = [], set(), set(REQ.findall(prd))
    for line in matrix.splitlines():
        cells = [c.strip() for c in line.strip('| ').split('|')]
        if not REQ.fullmatch(cells[0]):
            continue
        rid = cells[0]
        if len(cells) != 7:
            found.append(f'{rid}: expected 7 columns, got {len(cells)}')
            continue
        _, _, _, tasks, status, tests, evidence = cells
        if rid in seen:
            found.append(f'{rid}: duplicate row')
        seen.add(rid)
        if rid not in prd_ids:
            found.append(f'{rid}: not in PRD')
        if not re.search(r'\bT\d{2}\b', tasks):
            found.append(f'{rid}: no task')
        if status not in STATES:
            found.append(f'{rid}: unknown status {status}')
        if status in DONE and '-' in (tests, evidence):
            found.append(f'{rid}: {status} needs a test and evidence')
    found += [f'{rid}: missing from matrix' for rid in sorted(prd_ids - seen)]
    return found


def self_check():
    def row(rid='PAY-01', task='T11', status='NOT_STARTED', test='-', evidence='-'):
        return f'| {rid} | 07 | summary | {task} | {status} | {test} | {evidence} |'

    assert problems('PAY-01', row()) == []
    assert problems('PAY-01 PAY-02', row()) == ['PAY-02: missing from matrix']
    assert problems('PAY-01', row() + '\n' + row()) == ['PAY-01: duplicate row']
    assert problems('PAY-01', row() + '\n' + row('PAY-99')) == ['PAY-99: not in PRD']
    assert problems('PAY-01', row(task='-')) == ['PAY-01: no task']
    assert problems('PAY-01', row(status='DONE')) == ['PAY-01: unknown status DONE']
    assert problems('PAY-01', row(status='VERIFIED')) == ['PAY-01: VERIFIED needs a test and evidence']
    assert problems('PAY-01', row(status='VERIFIED', test='TC-001')) == ['PAY-01: VERIFIED needs a test and evidence']
    assert problems('PAY-01', row(status='VERIFIED', test='TC-001', evidence='CI run 7')) == []
    assert problems('PAY-01', '| PAY-01 | too | short |') == ['PAY-01: expected 7 columns, got 3', 'PAY-01: missing from matrix']


def main():
    self_check()
    root = Path(__file__).resolve().parent.parent
    prd = (root / 'PRD_Roman_Urdu.md').read_text(encoding='utf-8')
    found = problems(prd, (root / 'REQUIREMENTS_TRACEABILITY.md').read_text(encoding='utf-8'))
    for problem in found:
        print(f'FAIL {problem}')
    if found:
        sys.exit(1)
    print(f'OK: {len(set(REQ.findall(prd)))} PRD requirements traced')


if __name__ == '__main__':
    main()
