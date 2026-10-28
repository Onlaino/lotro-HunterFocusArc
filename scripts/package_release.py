"""Create an installable HunterFocusArc ZIP from the repository."""

import argparse
import hashlib
from pathlib import Path
import xml.etree.ElementTree as ET
from zipfile import ZIP_DEFLATED, ZipFile


def package(source: Path, output: Path, tag: str) -> Path:
    manifest = source / "HunterFocusArc.plugin"
    main = source / "Main.lua"
    readme = source / "README-ru.md"
    for path in (manifest, main, readme):
        if not path.is_file():
            raise SystemExit(f"Missing required file: {path}")

    version = ET.parse(manifest).findtext("./Information/Version")
    if not version or tag != f"v{version}":
        raise SystemExit(f"Tag {tag!r} does not match plugin version v{version}")

    image_root = source / "Images"
    if not image_root.is_dir():
        raise SystemExit("Missing Images directory")
    image_files = sorted(image_root.rglob("*.tga"))
    if not image_files:
        raise SystemExit("No TGA images found")
    for directory in {path.parent for path in image_files}:
        missing = [n for n in range(10) if not (directory / f"focus_{n}.tga").is_file()]
        if missing:
            raise SystemExit(f"Incomplete focus frames in {directory}: {missing}")

    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"HunterFocusArc-{tag}.zip"
    with ZipFile(archive, "w", compression=ZIP_DEFLATED, compresslevel=9) as zip_file:
        for path in (manifest, main, readme, *image_files):
            zip_file.write(path, Path("HunterFocusArc") / path.relative_to(source))

    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (output / f"{archive.name}.sha256").write_text(
        f"{digest}  {archive.name}\n", encoding="ascii"
    )
    print(f"Created {archive} with {len(image_files)} focus frames (SHA-256: {digest})")
    return archive


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True, help="Release tag, such as v1.10.0")
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()
    package(args.source, args.output or args.source / "dist", args.tag)
