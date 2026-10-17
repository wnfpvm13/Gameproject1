"""Score the STT probe with the design's confirmed-judge rule (word-initial match + particle list)."""
import io, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
PARTICLES = ["", "이", "가", "을", "를", "은", "는", "도", "만", "에", "로", "으로", "야", "이야", "예요", "이에요", "랑", "이랑", "하고", "의"]

def confirmed(word, text):
    for eojeol in re.sub(r"[^\w\s]", " ", text).split():
        if eojeol.startswith(word) and eojeol[len(word):] in PARTICLES:
            return True
    return False

def main(results_file):
    manifest = {m["id"]: m for m in json.load(io.open(os.path.join(HERE, "manifest.json"), encoding="utf-8-sig"))}
    results = json.load(io.open(os.path.join(HERE, results_file), encoding="utf-8"))
    hit = empty = miss = 0
    lat = []
    for r in results:
        m = manifest[r["id"]]
        if not r["text"]:
            empty += 1; status = "EMPTY"
        elif confirmed(m["word"], r["text"]):
            hit += 1; status = "HIT"; lat.append(r["latency"])
        else:
            miss += 1; status = "MISS"
        if status != "HIT":
            print(f'{r["id"]} {status:5} {m["word"]:6} | {m["sentence"]} -> {r["text"]}')
    n = len(results)
    print(f"total={n} hit={hit} ({hit/n:.0%}) miss={miss} empty={empty} | latency avg={sum(lat)/len(lat):.2f}s max={max(lat):.2f}s")

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "results_2026-10-17.json")
