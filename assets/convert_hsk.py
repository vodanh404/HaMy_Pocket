import json
import os
import time
import urllib.parse
import urllib.request


def translate_batch(text_list, retries=5):
    """Gộp các câu tiếng Anh thành 1 request duy nhất tới endpoint clients5 của Google.

    Nếu bị HTTP 429, tự động chờ 45-60 giây cho Google mở lại IP rồi chạy
    tiếp.
    """
    if not text_list:
        return []

    combined_text = "\n".join(text_list)

    # Sử dụng endpoint clients5 thay cho gtx để giảm tỉ lệ bị khóa IP
    url = (
        "https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=en&tl=vi&q="
        + urllib.parse.quote(combined_text)
    )

    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
            "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
        )
    }

    req = urllib.request.Request(url, headers=headers)

    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=15) as response:
                result = json.loads(response.read().decode("utf-8"))

                # Dạng response của client dict-chrome-ex
                if isinstance(result, list):
                    translated_lines = []
                    for item in result:
                        if isinstance(item, list) and len(item) > 0:
                            translated_lines.append(str(item[0]))
                        elif isinstance(item, str):
                            translated_lines.append(item)

                    # Nếu trả về chuỗi xuống dòng
                    if len(translated_lines) == 1 and "\n" in translated_lines[0]:
                        translated_lines = translated_lines[0].split("\n")

                    if len(translated_lines) == len(text_list):
                        return [line.strip() for line in translated_lines]

                # Fallback về gtx đơn lẻ nếu cấu trúc trả về không khớp
                return [translate_fallback(text, headers) for text in text_list]

        except urllib.error.HTTPError as e:
            if e.code == 429:
                wait_time = 45 + (attempt * 15)
                print(
                    f"\n⚠️ IP đang bị Google tạm chặn (HTTP 429). Đang chờ {wait_time}s để Google nhả IP..."
                )
                time.sleep(wait_time)
            else:
                time.sleep(3)
        except Exception:
            time.sleep(3)

    return text_list


def translate_fallback(text, headers):
    """Fallback dịch từng câu nếu batching bị lỗi định dạng."""
    if not text or not text.strip():
        return text
    url = (
        "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=vi&dt=t&q="
        + urllib.parse.quote(text)
    )
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            result = json.loads(response.read().decode("utf-8"))
            return "".join([part[0] for part in result[0] if part[0]])
    except Exception:
        return text


def build_han_viet_dictionary():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    data_dir = os.path.join(script_dir, "data")

    input_file = os.path.join(data_dir, "complete.json")
    output_file = os.path.join(data_dir, "complete_han_viet.json")
    cache_file = os.path.join(data_dir, "translation_cache.json")

    if not os.path.exists(input_file):
        print(f"❌ Lỗi: Không tìm thấy file đầu vào tại '{input_file}'.")
        return

    print(f"1. Đang tải dữ liệu từ file: {input_file}")
    with open(input_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    # Đọc cache đã dịch từ trước
    cache = {}
    if os.path.exists(cache_file):
        try:
            with open(cache_file, "r", encoding="utf-8") as f:
                cache = json.load(f)
            print(f"   -> Đã khôi phục {len(cache)} cụm từ đã dịch từ cache.")
        except Exception as e:
            print(f"   -> Không thể đọc file cache: {e}")

    # Lọc danh sách câu chưa dịch
    unique_meanings = []
    seen = set()

    for entry in data:
        for form in entry.get("forms", []):
            for m in form.get("meanings", []):
                if m and m not in cache and m not in seen:
                    unique_meanings.append(m)
                    seen.add(m)

    total_needed = len(unique_meanings)
    print(f"   -> Tổng số từ vựng trong dictionary: {len(data)}")
    print(f"   -> Số cụm từ tiếng Anh duy nhất cần dịch mới: {total_needed}")

    # Cấu hình an toàn tránh dính Rate Limit
    batch_size = 15             # Dịch 15 cụm từ / request
    delay_between_batches = 1.8  # Giãn cách 1.8 giây giữa các request

    if total_needed > 0:
        print(
            f"2. Bắt đầu dịch theo Batch ({batch_size} cụm/request, delay {delay_between_batches}s)..."
        )

        for i in range(0, total_needed, batch_size):
            batch_texts = unique_meanings[i : i + batch_size]
            translated_batch = translate_batch(batch_texts)

            for orig, trans in zip(batch_texts, translated_batch):
                cache[orig] = trans

            done_count = min(i + batch_size, total_needed)
            percent = (done_count / total_needed) * 100
            print(
                f"   Progress: {done_count}/{total_needed} ({percent:.1f}%)   ",
                end="\r",
            )

            # Lưu cache liên tục sau mỗi batch thành công
            with open(cache_file, "w", encoding="utf-8") as f:
                json.dump(cache, f, ensure_ascii=False, indent=2)

            time.sleep(delay_between_batches)

        print("\n   -> Hoàn thành dịch toàn bộ các cụm từ!")

    print("3. Đang ghép nghĩa Tiếng Việt vào file từ điển Hán - Việt...")
    for entry in data:
        for form in entry.get("forms", []):
            meanings_en = form.get("meanings", [])
            form["meanings_vi"] = [cache.get(m, m) for m in meanings_en if m]

    print(f"4. Đang lưu file kết quả ra: {output_file}")
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print("\n✅ HOÀN THÀNH TẤT CẢ!")


if __name__ == "__main__":
    build_han_viet_dictionary()