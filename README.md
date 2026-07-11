# 옐리 대쉬보드

8단계 구조의 종목 실적 리포트를 검색·열람하는 **정적 웹 대시보드**.
서버·API 키 없이 GitHub Pages로 배포된다.

## 구성
```
stock-report-web/
├─ index.html            대시보드 (GitHub Pages·서버용, reports/를 fetch)
├─ dashboard.html        ★ 자체완결 단일 파일 — 더블클릭으로 열림(서버·인터넷 불필요)
├─ build_manifest.ps1    reports/*.md → reports/manifest.json 생성
├─ build_html.ps1        모든 리포트+라이브러리를 박아 dashboard.html 생성
├─ vendor/               인라인용 marked / DOMPurify 캐시
└─ reports/
   ├─ manifest.json       대시보드가 읽는 목록(자동 생성)
   └─ *.md                리포트 (Claude Code /stock-report 로 생성)
```

## 탭
- **📋 리포트**: 종목 실적 리포트 검색·열람 (타입 필터: 전체/실적/프리뷰/리뷰).
- **📅 실적 캘린더**: `reports/earnings.json` 기반, 향후 ~1개월 실적발표 일정(D-day·확정/예정). 각 일정에서 **프리뷰(D-3)**·**리뷰(D+1)** 리포트로 바로 이동.
- **🔭 섹터 뷰**: `reports/sectors.json` 기반, 세부산업별 **좋은 뷰/나쁜 뷰**와 심리(긍정/중립/부정). **5일 주기** 자동 갱신(스케줄 `yellini-sector-view`, 매월 1·6·11·16·21·26일). 갱신마다 `reports/sectors-history/sectors_YYYYMMDD.json` 스냅샷을 보관하며, 섹터 탭 우측 **날짜 드롭다운**으로 과거 시점을 되돌아볼 수 있다(스냅샷 2개 이상일 때 표시).

## 리포트 타입
- `{티커}_{날짜}.md` = 실적 리포트, `{티커}_preview_{발표일}.md` = 발표 전 프리뷰(기대/우려), `{티커}_review_{발표일}.md` = 발표 후 리뷰(변화). 카드에 타입 배지 표시.

## 두 가지 사용법
| 파일 | 여는 법 | 용도 |
|---|---|---|
| **dashboard.html** | **그냥 더블클릭** | 내 PC에서 바로 보기. 서버·인터넷 불필요(모든 리포트 내장) |
| index.html | 웹서버/GitHub Pages | 온라인 배포, 폰에서 접속 |

> 리포트를 추가/수정하면 `build_html.ps1`을 다시 실행해야 `dashboard.html`에 반영됩니다.

## 새 종목 추가하는 법
1. Claude Code에서 분석 생성:
   ```
   /stock-report NVDA
   ```
   → `reports/NVDA_YYYYMMDD.md` 저장 + `build_manifest.ps1` 자동 실행됨.
2. (수동으로 .md를 추가/수정했다면) 대시보드 다시 빌드:
   ```powershell
   powershell -File build_manifest.ps1   # index.html 목록 갱신
   powershell -File build_html.ps1        # dashboard.html 재생성
   ```
3. 커밋 & push → 사이트에 자동 반영:
   ```powershell
   git add . ; git commit -m "add NVDA report" ; git push
   ```

## 로컬에서 미리보기
`file://`로 바로 열면 브라우저 보안정책(fetch)이 막으므로 간단한 서버로 연다:
```powershell
python -m http.server 8765 --directory .
# → http://localhost:8765
```

## GitHub Pages 최초 배포 (한 번만)
```powershell
cd stock-report-web
git init
git add .
git commit -m "init stock report dashboard"
# gh CLI 사용 시:
gh repo create stock-report-web --public --source=. --push
```
그 다음 GitHub 저장소 → **Settings → Pages → Source: Deploy from a branch → main / (root)** 선택.
몇 분 뒤 `https://<아이디>.github.io/stock-report-web/` 에서 접속(폰 포함).

> 깃 없이 수동: GitHub에서 새 저장소 만들고 이 폴더 파일을 업로드해도 됩니다.

## 투자 메모 (📝 메모 버튼 / Alt+M)
- 우측 슬라이드 패널에서 메모 작성. 입력 즉시 **자동 저장**(브라우저 localStorage).
- **종목 메모**: 현재 열려 있는 리포트에 묶여 저장 → 메모가 있는 카드엔 📌 표시.
- **자유 메모**: 종목과 무관한 전체 스크래치패드.
- 저장은 그 브라우저(기기)에만 남습니다. 기기/브라우저가 바뀌면 메모는 공유되지 않습니다.

## 메모
- 리포트 본문의 `<mark>`(형광펜), `**굵게**`, 표가 그대로 렌더링됨.
- `#티커`로 딥링크 가능 (예: `.../stock-report-web/#MU`).
- 마크다운 렌더는 marked + DOMPurify(CDN) 사용 → 인터넷 연결 필요.
