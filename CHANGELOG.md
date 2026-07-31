# Changelog

## v2.2.0 (2026-08-01)

### New Features

- 新增 Podcast RSS feed 發布流程，將節目資訊與封面圖部署至 GitHub Pages。
- 補充 30 集現代技術詞彙，校正技術內容並加入縮寫與易誤讀單字的 SSML 發音標記。

## v2.0.0

### New Features

- 新增 `podcast-episode` Skill，提供 Episode XML 標準模板、Pattern 選用規則與格式防範規則，供 AI 生成集數內容使用。
- 新增 `podcast-vocab` Skill，定義詞彙缺口評估與分組擴充流程，供定期補充各集單字使用。
- 新增 GitHub Actions `release.yml`：push tag 觸發時建立 GitHub Release，支援手動指定 tag 重跑，並自動比對前後 tag 差異、呼叫 TTS 腳本轉換變更的 XML，將 MP3 上傳至 Release Assets（含三次 retry 機制）。
- `release.yml` 在呼叫 TTS 前會先驗證 tag 格式、GitHub Release、`TTS_KEY` 與 `TTS_REGION`，避免設定錯誤時消耗 TTS 額度。
- 擴充全部 30 集詞彙，補充現代技術主流單字、補齊單例句詞彙的第二例句，並依功能領域重新分組。
- `.agent/skills/` 取代原有 `.agent/workflows/` 作為 AI 技能定義目錄。
- 移除舊版 `generate_mock_discussion` workflow。

### BREAKING CHANGES

- `assets/` 目錄已從版控移除，既有 MP3 需從 GitHub Release 下載。
