# 옐리니 보드 — 매일 자동 리포트 플레이북

> 이 문서는 매일 아침(한국시간 07:30경) 스케줄로 실행되는 작업 지침이다.
> 실행 주체(Claude)는 이 저장소(stock-report-web) 안에서 아래 순서대로 수행한다.

## 목표
시총 **$100B 이상**의 **반도체 / AI** 기업 중, **그날 주목받는(주가 급등·주요 뉴스)** 종목 **4~5개**를 골라
8단계 실적 리포트를 생성하고 옐리니 보드(https://goldpigbankgazua-dev.github.io/stock-report-web/)에 배포한다.

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
- push되면 1~2분 뒤 옐리니 보드 URL에 자동 반영된다.

## 5) 텔레그램 알림
- 환경변수 `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_IDS`가 있으면 전송:
  - 메시지 예: `📊 {날짜} 옐리니 보드 새 리포트 N개\n- NVDA: …\n- AVGO: …\nhttps://goldpigbankgazua-dev.github.io/stock-report-web/`
  - `send_telegram.ps1`을 쓰거나, curl로 `https://api.telegram.org/bot$TOKEN/sendMessage` 호출.
- 환경변수가 없으면 알림은 건너뛴다.

## 6) 마무리
- 오늘 생성한 종목/개수, push 결과, 텔레그램 전송 여부를 한 줄로 보고한다.

## 주의
- 평일(미국 증시 개장일) 위주로 의미가 있다. 주말·미국 공휴일엔 새 촉매가 적으니 스킵하거나 최근 실적 복습 1~2개만 올려도 된다.
- 모든 리포트는 자동 생성물 — 투자 권유가 아니며 수치 오류 가능성 고지를 포함한다.
