from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[3]
BUNDLE = ROOT / 'evaluation_artifacts' / 'co5_testing_bundle'
SRC = ROOT / 'testing_assignment'

REPORT_SRC = SRC / 'report.html'
REPORT_DST = BUNDLE / 'outputs' / 'reports' / 'report.html'

SCREENSHOTS = [
    'success_login.png',
    'success_add_semester.png',
    'failed_login.png',
    'real_test.png',
]


def copy_if_exists(src: Path, dst: Path):
    if src.exists():
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        print(f'Copied: {src} -> {dst}')
    else:
        print(f'Skipped (not found): {src}')


def main():
    copy_if_exists(REPORT_SRC, REPORT_DST)

    for name in SCREENSHOTS:
        s = SRC / name
        d = BUNDLE / 'outputs' / 'screenshots' / name
        copy_if_exists(s, d)

    print('\nEvidence collection complete.')


if __name__ == '__main__':
    main()
