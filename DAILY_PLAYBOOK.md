# 옐리 대쉬보드 — 매일 자동 리포트 플레이북

> 이 문서는 매일 아침(한국시간 07:30경) 스케줄로 실행되는 작업 지침이다.
> 실행 주체(Claude)는 이 저장소(stock-report-web) 안에서 아래 순서대로 수행한다.

## 목표
시총 **$100B 이상**의 **반도체 / AI** 기업 중, **그날 주목받는(주가 급등·주요 뉴스)** 종목 **4~5개**를 골라
8단계 실적 리포트를 생성하고 옐리 대쉬보드(https://goldpigbankgazua-dev.github.io/stock-report-web/)에 배포한다.

## 1) 종목 선정 (4~5개)
- WebSearch로 "오늘/이번 주 반도체·AI 대형주 급등/뉴스"를 조사한다. 예:
  - `"semiconductor stocks today biggest gainers AI chip"`, `"AI stocks rally today large cap"`, `"엔비디아 반도체 株 급등 오늘"`
- **유니버스(시총 $100B+ 반도체·AI, 예시 — 매일 이 중 주목받는 것 우선):**
  - 미국: NVDA, AVGO, AMD, TSM, ASML, AMAT, LRCX, KLAC, QCOM, ARM, MRVL, MU, INTC, TXN, ADI, SNPS, CDNS, SMCI, ORCL, PLTR, MSFT, GOOGL, AMZN, META, NOW, ANET, DELL, CRWV
  - 한국: 005930(삼성전자), 000660(SK하이닉스)
- **선정 기준**: ① 시총 $100B+ 확인, ② 그날의 주가 상승/촉매(실적·계약·신제품·AI 수요 뉴스)가 뚜렷할 것.
- **로테이션(중복 방지)**: `reports/` 폴더의 파일명을 보고 **최근 5일 이내에 이미 다룬 종목은 제외**한다. 매일 새로운 조합이 되도록 한다. 마땅한 새 종목이 없으면 4개만 만들어도 된다.

## 2) 리포트 작성 (각 종목)
- 형식·톤은 `reports/`의 기존 리포트(MU, SNDK, 삼성전자, SK하이닉스, IREN)를 **예시로 그대로 따른다.** 8단계 구조:
  - 제목 `# 회사명(티커) | 핵심 한 줄` → `### 분기/날짜` → `## 세줄 요약` →
    `1. Key Takeaways` `2. 주요 실적 지표` `3. 가이던스` `4. 부문별` `5. 현금흐름·재무구조` `6. 주주환원` `7. 경영진 자신 부문` `8. 리스크`
  - 각 분석 섹션 끝에 `→ 투자자 입장에서 의미:` 한 단락.
  - 핵심 숫자 **굵게**, 섹션당 가장 중요한 한 문장만 `<mark>…</mark>` 형광펜.
  - 컨센서스 대비 Beat/Miss는 수치로. `회사 주장`·`(추정)`·`확인 불가` 꼬리표로 사실/주장/추정 구분.
  - **그날 주가가 왜 움직였는지(촉매)**를 세줄 요약/Key Takeaways에 반드시 반영.
- **데이터 소스**: 미국은 stockanalysis.com(`/stocks/{TICKER}/financials/`) + 어닝콜·뉴스 WebSearch. 한국은 네이버 금융(Invoke-WebRequest 우회)·DART.
- **수치를 지어내지 말 것.** 못 구하면 "확인 불가". 맨 아래 출처/작성시각/자동생성 고지 줄 포함.
- 저장: `reports/{티커}_{YYYYMMDD}.md` (한국주는 `{코드}_{회사명}_{YYYYMMDD}.md`). 날짜는 실행일.

## 1.5) 실적 캘린더 갱신 + 프리뷰(D-3) + 리뷰(D+1)
오늘 날짜를 기준으로 다음을 수행한다. (시총 $100B+ 반도체·AI·메가캡 유니버스 대상)

### (a) 캘린더 갱신 — `reports/earnings.json`
- WebSearch로 **앞으로 약 1개월(30일) 내** 예정된 실적발표일을 조사해 `reports/earnings.json`의 `events`를 갱신한다.
- 각 항목: `{ "ticker","company","market"("US"|"KR"),"date"("YYYY-MM-DD"),"quarter","confirmed"(bool) }`.
- 공식 확정일이면 `confirmed:true`, 추정/예정이면 `false`. `updated`를 오늘 날짜로. 지난 날짜(이미 발표됨)는 제거.

### (b) D-3 프리뷰
- `events` 중 **발표일이 오늘로부터 정확히 3일 뒤(D-3)** 인 종목에 대해 프리뷰 작성:
  `reports/{티커}_preview_{발표일YYYYMMDD}.md` (한국주는 `{코드}_{회사명}_preview_{발표일YYYYMMDD}.md`).
- 형식은 기존 예시 `reports/TSM_preview_20260716.md` 를 그대로 따른다:
  제목 `# 회사(티커) | Q_ 실적 프리뷰 — 시장이 보는 기대 vs 우려` → `### 발표일 예정 · 프리뷰(발표 전)` →
  `## 세줄 요약(관전 포인트)` → `## 1. 컨센서스/회사 가이던스` → `## 2. 시장이 기대하는 것(Bull)` →
  `## 3. 시장이 우려하는 것(Bear)` → `## 4. 실적발표일 체크리스트` → `## 5. 주가·포지셔닝 맥락`.
- 컨센서스·예상치는 `(추정)` 표기. 발표 전 자동생성 고지 줄 포함.

### (c) D+1 리뷰
- **어제 실적을 발표한** $100B+ 종목에 대해 리뷰 작성:
  `reports/{티커}_review_{발표일YYYYMMDD}.md`.
- 형식: 제목 `# 회사(티커) | Q_ 실적 리뷰 — 발표 후 무엇이 바뀌었나` → `### 발표일 · 리뷰(발표 후)` →
  `## 세줄 요약` → `## 1. 결과 vs 기대(컨센·가이던스 대비 Beat/Miss)` → `## 2. 프리뷰 체크포인트 점검(기대/우려가 어떻게 판가름났나)` →
  `## 3. 가이던스 변화` → `## 4. 주가 반응(시간외/익일 %, 이유)` → `## 5. 투자 포인트 재정리`.
- 가능하면 같은 종목의 직전 프리뷰(`{티커}_preview_*`)와 대조해 "기대/우려가 맞았는지"를 명시.
- 주가 반응 수치는 출처와 함께, 못 구하면 "확인 불가". 자동생성 고지 줄 포함.

## 3) 대시보드 빌드
```
pwsh -File build_manifest.ps1   # 또는 powershell -File ... (환경에 맞게)
pwsh -File build_html.ps1
```
- `.ps1`이 안 되는 환경이면, 같은 로직(reports/*.md → manifest.json, dashboard.html 임베드)을 직접 수행해도 된다.

## 4) 배포 (git push)
```
git add .
git commit -m "daily reports: {YYYY-MM-DD} ({티커들})"
git push
```
- push되면 1~2분 뒤 옐리 대쉬보드 URL에 자동 반영된다.

## 5) 텔레그램 알림 (텔레그램 MCP 사용)
- 텔레그램 MCP 서버(telegram)의 `send-message` 도구로 보낸다. (스키마는 ToolSearch "telegram send-message"로 로드.)
- chatId **"6996572208"**(개인 DM) 과 **"-5008862799"**(100억프로젝트 그룹) 두 곳에 전송. 한 곳 실패해도 다른 곳은 계속.
- 메시지 예: `📊 {날짜} 옐리 대쉬보드 새 리포트 N개` + 종목별 한 줄 + `https://goldpigbankgazua-dev.github.io/stock-report-web/`

## 6) 마무리
- 오늘 생성한 종목/개수, push 결과, 텔레그램 전송 여부를 한 줄로 보고한다.

## 주의
- 평일(미국 증시 개장일) 위주로 의미가 있다. 주말·미국 공휴일엔 새 촉매가 적으니 스킵하거나 최근 실적 복습 1~2개만 올려도 된다.
- 모든 리포트는 자동 생성물 — 투자 권유가 아니며 수치 오류 가능성 고지를 포함한다.
