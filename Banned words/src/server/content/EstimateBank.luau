--!strict
-- 숫자 근사 quiz (bundle 8c, owner 2026-10-24): everyone types a whole number, the farthest from the answer flies.
-- Data only: `q` asks for a number (the unit, and the standard or rounding when it matters, is in the question),
-- `answer` is a whole number from 1 to Config.ESTIMATE_MAX. Facts that stay put (no counts a law can change, no values
-- whose sources disagree, no ranges like a pulse), mostly ones to estimate or work out rather than recall; nothing
-- sensitive. None repeats a fact of the quiz bank or the O/X bank (one game would give another's answer away).
-- Questions containing a banned word in play are skipped.

export type Question = { q: string, answer: number }

local EstimateBank: { Question } = {
	-- Time and numbers to work out
	{ q = "하루는 몇 초?", answer = 86400 },
	{ q = "1주일은 몇 분?", answer = 10080 },
	{ q = "1년(평년)은 몇 시간?", answer = 8760 },
	{ q = "정이십면체의 모서리는 모두 몇 개?", answer = 30 },
	{ q = "하루 동안 시계의 분침은 몇 바퀴 돌까?", answer = 24 },
	{ q = "3을 10번 곱하면?", answer = 59049 },
	{ q = "99 × 99 = ?", answer = 9801 },
	{ q = "11 × 11 × 11 = ?", answer = 1331 },
	{ q = "1부터 9까지 모두 곱하면?", answer = 362880 },
	{ q = "시속 100km로 1시간 30분 달리면 몇 km를 갈까?", answer = 150 },
	{ q = "가로·세로·높이가 모두 1m인 통에 물을 가득 채우면 몇 리터?", answer = 1000 },
	-- Earth and space
	{ q = "지구에서 달까지의 평균 거리는 약 몇 km?", answer = 384400 },
	{ q = "지구 적도의 둘레는 약 몇 km?", answer = 40075 },
	{ q = "지구의 평균 반지름은 약 몇 km?", answer = 6371 },
	{ q = "달의 평균 지름은 약 몇 km? (반올림)", answer = 3475 },
	{ q = "태양의 지름은 지구 지름의 약 몇 배?", answer = 109 },
	{ q = "화성이 태양을 한 바퀴 도는 데 걸리는 날은 약 며칠?", answer = 687 },
	{ q = "섭씨 20도 공기 속에서 소리는 1초에 약 몇 미터를 갈까?", answer = 343 },
	-- Sizes by a standard
	{ q = "1마일은 약 몇 미터?", answer = 1609 },
	{ q = "에베레스트산의 높이는 약 몇 미터? (2020년 발표)", answer = 8849 },
	{ q = "부르즈 할리파의 높이는 약 몇 미터?", answer = 828 },
	{ q = "국제 규격 농구 골대 링의 높이는 몇 cm?", answer = 305 },
	{ q = "국제 규격 축구 골대의 가로 폭은 몇 cm?", answer = 732 },
	{ q = "국제 규격 탁구공의 지름은 몇 mm?", answer = 40 },
	{ q = "야구에서 투수판부터 홈 플레이트까지는 약 몇 cm?", answer = 1844 },
	{ q = "표준 피아노의 건반은 모두 몇 개?", answer = 88 },
	{ q = "A4 용지의 긴 변은 몇 mm?", answer = 297 },
	-- Years
	{ q = "훈민정음이 반포된 해는?", answer = 1446 },
	{ q = "임진왜란이 일어난 해는?", answer = 1592 },
	{ q = "콜럼버스가 아메리카에 처음 도착한 해는?", answer = 1492 },
	{ q = "첫 근대 올림픽(아테네)이 열린 해는?", answer = 1896 },
	{ q = "에펠탑이 완성된 해는?", answer = 1889 },
	{ q = "사람이 처음 달에 발을 디딘 해는?", answer = 1969 },
	{ q = "서울 올림픽이 열린 해는?", answer = 1988 },
}

return EstimateBank
