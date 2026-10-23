import hashlib
import json
import re
from pathlib import Path


ASSETS_DIR = Path(__file__).parent
SUPPORTED_EXTENSIONS = {".pdf", ".mp3", ".jpg", ".jpeg", ".png"}
LEVEL_PATTERN = re.compile(r"\bHSK\s*([1-6])\b", re.IGNORECASE)
TEST_PATTERN = re.compile(r"^H([1-6])\d{4,}", re.IGNORECASE)


def get_level(path: Path) -> int | None:
    text = str(path)
    match = LEVEL_PATTERN.search(text)
    if match:
        return int(match.group(1))
    match = TEST_PATTERN.match(path.stem)
    return int(match.group(1)) if match else None


def get_category(path: Path, extension: str) -> str:
    text = str(path).casefold()
    if extension == ".mp3":
        return "listening"
    if any(term in text for term in ("ngữ pháp", "ngu phap", "语法")):
        return "theory"
    if "hskk" in text:
        return "speaking"
    if re.match(r"^h[1-6]\d{4}", path.stem, re.IGNORECASE) or any(
        term in text for term in ("đề thi", "đề thử", "bộ 11 đề")
    ):
        return "exam"
    return "course"


def get_title(path: Path, level: int | None, image_index: int | None) -> str:
    title = re.sub(r"\s+", " ", path.stem).strip()
    if path.suffix.casefold() == ".mp3" and level:
        return f"Bài nghe HSK {level} · {title}"
    if image_index is not None:
        parent = path.parent.name.casefold()
        if "3+4" in parent:
            return f"Ngữ pháp HSK 3–4 · trang {image_index}"
        if "quyển 1 và 2" in parent:
            return f"Ngữ pháp quyển 1–2 · trang {image_index}"
    if re.match(r"^H[1-6]\d{4}", title, re.IGNORECASE) and level:
        return f"Đề HSK {level} · {title}"
    return title


def build_catalog() -> dict:
    files = sorted(
        {
            path
            for folder in ASSETS_DIR.rglob("Tổng hợp*")
            for path in folder.rglob("*")
            if path.is_file()
        }
    )
    items = []
    archives = []
    image_indexes = {}
    image_counts = {}
    for path in files:
        if path.suffix.casefold() in {".jpg", ".jpeg", ".png"}:
            image_counts[path.parent] = image_counts.get(path.parent, 0) + 1
            image_indexes[path] = image_counts[path.parent]

    for path in files:
        extension = path.suffix.casefold()
        relative_path = path.relative_to(ASSETS_DIR).as_posix()
        if extension == ".rar":
            archives.append(
                {
                    "file_name": path.name,
                    "level": get_level(path),
                    "source": relative_path,
                    "size_bytes": path.stat().st_size,
                }
            )
            continue
        if extension not in SUPPORTED_EXTENSIONS:
            continue

        level = get_level(path)
        category = get_category(path, extension)
        items.append(
            {
                "id": hashlib.sha1(relative_path.encode("utf-8")).hexdigest()[:16],
                "title": get_title(path, level, image_indexes.get(path)),
                "file_name": path.name,
                "type": (
                    "audio"
                    if extension == ".mp3"
                    else "image"
                    if extension in {".jpg", ".jpeg", ".png"}
                    else "pdf"
                ),
                "category": category,
                "level": level,
                "source": relative_path,
            }
        )

    return {
        "items": items,
        "archives": {
            "count": len(archives),
            "total_bytes": sum(item["size_bytes"] for item in archives),
            "items": archives,
        },
    }


if __name__ == "__main__":
    catalog = build_catalog()
    output = ASSETS_DIR / "library" / "catalog.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    counts = {}
    for item in catalog["items"]:
        counts[item["type"]] = counts.get(item["type"], 0) + 1
    print(
        f"Wrote {len(catalog['items'])} materials ({counts}); "
        f"{catalog['archives']['count']} RAR archives require extraction."
    )
