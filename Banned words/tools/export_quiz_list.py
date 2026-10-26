"""Every quiz question in the game with its answer, as one HTML page for reading (owner 2026-10-27: "전체 문제랑 정답
파일로 뽑아줘"). Reads the data modules in src/server/content (QuizBank, OXBank, EstimateBank, ChosungBank); each
entry there sits on one line, which this relies on and checks. Writes .qa/quiz_list.html (git-excluded) or the path
given.

usage: python -I tools/export_quiz_list.py [out.html]"""
import datetime, html, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(ROOT, "src", "server", "content")
OUT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(ROOT, ".qa", "quiz_list.html")

STRING = r'"([^"\\]*)"'  # (the banks have no escaped quotes; checked below)


def read(name):
    with open(os.path.join(CONTENT, name + ".luau"), encoding="utf-8") as f:
        text = f.read()
    if '\\"' in text:
        sys.exit(f"{name}: escaped quotes, extend the parser")
    return text.splitlines()


def section_lines(lines, start_marker, end_marker=None):
    """Lines after the one containing start_marker, up to the one containing end_marker (or the end)."""
    out, inside = [], False
    for line in lines:
        if not inside:
            inside = start_marker in line
            continue
        if end_marker and end_marker in line:
            break
        out.append(line)
    return out


def quiz(lines):
    """Four-choice questions; section comments (-- ...) become group headings."""
    out = []
    for line in lines:
        m = re.search(r'\{ q = ' + STRING + r', choices = \{(.*)\}, answer = (\d+) \}', line)
        if m:
            choices = re.findall(STRING, m.group(2))
            answer = int(m.group(3))
            if len(choices) != 4 or not 1 <= answer <= 4:
                sys.exit(f"bad quiz line: {line.strip()}")
            out.append((m.group(1), choices, answer))
        elif "{ q =" in line:
            sys.exit(f"unparsed quiz line: {line.strip()}")
    return out


# The banks' group comments are in English; the page is for the owner (a heading not listed shows as it is).
HEADINGS = {
    "Animals and plants": "동물·식물",
    "Science and the sky": "과학·하늘",
    "Places, culture and numbers": "장소·문화·숫자",
    "Time and numbers to work out": "시간·계산",
    "Earth and space": "지구·우주",
    "Sizes by a standard": "크기·높이",
    "Years": "연도",
}


def grouped(lines, pattern, convert):
    """(heading, [entries]) groups from `-- Heading` comments inside a list."""
    groups = [("", [])]
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("-- ") and line.startswith("\t"):
            groups.append((HEADINGS.get(stripped[3:], stripped[3:]), []))
            continue
        m = re.search(pattern, line)
        if m:
            groups[-1][1].append(convert(m))
    return [g for g in groups if g[1]]


CHO = "ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ"


def initials(word):
    """Same rule as src/shared/Hangul.luau: syllables give their initial consonant, anything else stays."""
    return "".join(CHO[(ord(c) - 0xAC00) // 588] if 0xAC00 <= ord(c) <= 0xD7A3 else c for c in word)


quiz_lines = read("QuizBank")
main = quiz(section_lines(quiz_lines, "QuizBank.main = {", "QuizBank.final = {"))
final = quiz(section_lines(quiz_lines, "QuizBank.final = {"))
ox = grouped(read("OXBank"), r'\{ s = ' + STRING + r', o = (true|false) \}', lambda m: (m.group(1), m.group(2) == "true"))
estimate = grouped(read("EstimateBank"), r'\{ q = ' + STRING + r', answer = (\d+) \}', lambda m: (m.group(1), int(m.group(2))))
chosung = []
for line in read("ChosungBank"):
    m = re.search(r'\{ category = ' + STRING + r', words = \{(.*)\} \}', line)
    if m:
        chosung.append((m.group(1), re.findall(STRING, m.group(2))))

e = html.escape
ox_count = sum(len(g[1]) for g in ox)
ox_o = sum(1 for g in ox for s in g[1] if s[1])
est_count = sum(len(g[1]) for g in estimate)
word_count = sum(len(w) for _, w in chosung)

parts = []


def quiz_table(rows):
    parts.append('<table><tr><th>#</th><th>문제</th><th>보기 (정답 굵게)</th><th>정답</th></tr>')
    for i, (q, choices, answer) in enumerate(rows, 1):
        shown = " · ".join(f"<b>{e(c)}</b>" if n == answer else e(c) for n, c in enumerate(choices, 1))
        parts.append(f"<tr><td>{i}</td><td>{e(q)}</td><td>{shown}</td><td class=a>{e(choices[answer - 1])}</td></tr>")
    parts.append("</table>")


parts.append(f"<h2 id=quiz>1. 퀴즈 (4지선다) — {len(main)}문제</h2>")
parts.append("<p>10초 안에 고르기, 틀리거나 안 고르면 날아감. 게임에서는 보기 순서를 섞어서 보여 준다(보기 4개에 모두 숫자가 들어 있으면 이 순서 그대로). "
             "벨 퀴즈(진행자가 있을 때 진행자가 고르는 미션)도 이 문제들에서 3문제를 낸다.</p>")
quiz_table(main)
parts.append(f"<h2 id=final>2. 결승 퀴즈 (4지선다, 더 어려움) — {len(final)}문제</h2>")
parts.append("<p>결승에서만 나온다. 틀리면 탈락(모두 틀리면 그 문제는 무효). 보기 순서는 섞인다(모두 숫자인 보기는 그대로).</p>")
quiz_table(final)

parts.append(f"<h2 id=ox>3. O/X 퀴즈 — {ox_count}문장 (O {ox_o} / X {ox_count - ox_o})</h2>")
parts.append("<p>한 판에 3문제, 가장 많이 틀린 사람이 날아감(모두 만점이면 아무도 안 날아감).</p>")
n = 0
for heading, rows in ox:
    if heading:
        parts.append(f"<h3>{e(heading)}</h3>")
    parts.append('<table><tr><th>#</th><th>문장</th><th>정답</th></tr>')
    for s, right in rows:
        n += 1
        parts.append(f"<tr><td>{n}</td><td>{e(s)}</td><td class=a>{'O' if right else 'X'}</td></tr>")
    parts.append("</table>")

parts.append(f"<h2 id=estimate>4. 숫자 근사 퀴즈 — {est_count}문제</h2>")
parts.append("<p>15초 안에 정수를 적는다. 안 적은 사람이 있으면 그 사람만, 모두 적었으면 정답에서 가장 먼 사람이 날아감. "
             "모두 정확히 맞히면 아무도 안 날아감. 2명 이상일 때만 나온다.</p>")
n = 0
for heading, rows in estimate:
    if heading:
        parts.append(f"<h3>{e(heading)}</h3>")
    parts.append('<table><tr><th>#</th><th>문제</th><th>정답</th></tr>')
    for q, answer in rows:
        n += 1
        parts.append(f"<tr><td>{n}</td><td>{e(q)}</td><td class=a>{answer:,}</td></tr>")
    parts.append("</table>")

parts.append(f"<h2 id=chosung>5. 초성 퀴즈 단어 — {len(chosung)}분야 × 단어 {word_count}개</h2>")
parts.append("<p>단어의 초성과 분야를 보여 주고, 같은 분야에서 초성이 다른 단어 3개와 함께 4개 중 고르게 한다. "
             "머리 위 스무고개도 이 목록에서 두 글자 이상인 단어를 쓴다.</p>")
for category, words in chosung:
    parts.append(f"<h3>{e(category)} ({len(words)})</h3><table><tr><th>초성</th><th>정답 단어</th></tr>")
    for w in words:
        parts.append(f"<tr><td class=c>{e(initials(w))}</td><td class=a>{e(w)}</td></tr>")
    parts.append("</table>")

total = len(main) + len(final) + ox_count + est_count
page = f"""<!DOCTYPE html><html lang=ko><head><meta charset=utf-8><title>의자에서 살아남기! 퀴즈 전체 목록</title>
<style>
body{{font-family:'Malgun Gothic','Apple SD Gothic Neo',sans-serif;max-width:1100px;margin:24px auto;padding:0 16px;color:#222;line-height:1.5}}
h1{{font-size:24px}} h2{{margin-top:36px;border-bottom:2px solid #1c70e2;padding-bottom:4px}} h3{{margin:18px 0 6px;color:#1c70e2}}
table{{border-collapse:collapse;width:100%;font-size:14px}} th,td{{border:1px solid #d6dde3;padding:5px 8px;text-align:left;vertical-align:top}}
th{{background:#eef4fb}} td:first-child{{width:36px;color:#888}} td.a{{font-weight:bold;white-space:nowrap}} td.c{{width:120px;font-size:16px}}
b{{color:#c8202f}} nav a{{margin-right:14px}} .note{{color:#666;font-size:13px}}
</style></head><body>
<h1>의자에서 살아남기! 퀴즈 전체 목록</h1>
<p class=note>{datetime.date.today().isoformat()} 저장소 src/server/content에서 뽑음(tools/export_quiz_list.py). 문제 {total}개 + 초성 단어 {word_count}개.
그 판의 금칙어가 문제나 보기에 들어 있으면 게임에서 건너뛴다.</p>
<nav><a href=#quiz>퀴즈</a><a href=#final>결승</a><a href=#ox>O/X</a><a href=#estimate>숫자 근사</a><a href=#chosung>초성</a></nav>
{''.join(parts)}
</body></html>
"""
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write(page)
print(f"main {len(main)}, final {len(final)}, ox {ox_count} (O {ox_o}), estimate {est_count}, "
      f"chosung {len(chosung)} categories / {word_count} words -> {OUT}")
