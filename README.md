# Software English Podcast

[![License: CC BY-SA 4.0](https://img.shields.io/badge/License-CC_BY--SA_4.0-lightgrey.svg)](LICENSE.md)

這是一個為了滿足我個人學習需求而製作的 Side Project。

因為買了單字書卻沒時間看，查發音又很麻煩，所以決定用工程師的方式解決這個問題 —— 自己寫腳本、串 API，生出一個可以陪我通勤的 Podcast。

目標很簡單：**聽懂關鍵字、矯正台式發音、學會怎麼在工作中使用這些詞。**

## 🎧 想要解決的問題

1. **沒時間看書**：把學習變成「被動輸入」，洗澡、通勤、運動都能聽。
2. **發音不標準**：工程師常把 `Azure` 念成 `Agile`，或是 `Nginx` 亂念。不如讓 Azure 的 Neural TTS (Phoebe) 來示範標準唸法。
3. **單字背了不會用**：單純背 `Dependency Injection` 沒意義，重點是在 Code Review 時要怎麼說 "We should use DI here to reduce coupling."

## 🛠️ 怎麼做的？

不想手動剪輯，所以全自動化處理：

1. **劇本 (Transcripts)**：使用 **SSML** (Speech Synthesis Markup Language) 撰寫，精細控制發音、語氣 (`express-as`) 與節奏 (`prosody`)。包含中英對照、例句與模擬對話。
2. **角色 (Voices)**：
   - **曉臻**：中文主持人。由 `zh-TW-HsiaoChenNeural` 飾演。負責引導話題、提供背景脈絡，並替聽眾提出疑問。
   - **Phoebe**：英文技術專家。由 `en-US-PhoebeMultilingualNeural` 飾演。負責發音示範、技術解說，以及職場溝通的情境演練。
   - **特別調整**：加上了 `Cheerful` 風格，讓她們聽起來像在聊天，而不是機器人唸經。
3. **自動化 (Scripts)**：寫了 PowerShell 腳本，一鍵把 30 集 SSML 全部轉成 MP3。

## 📂 專案結構

```mermaid
graph TD
    Root[SoftwareEnglishPodcast] --> Transcripts[transcripts/]
    Root --> Scripts[scripts/]
    Root --> Workflows[.github/workflows/]
    Root --> AgentSkills[.agent/skills/]
```

- **transcripts/**: 每一集的內容 (XML)。
- **scripts/**: 轉換用的工具程式（本機手動執行）。
- **.github/workflows/**: CI/CD 自動化流程。
  - `release.yml`：push tag 時建立 GitHub Release，自動轉換變更的 SSML 並上傳 MP3，也支援手動指定 tag 重跑。
- **.agent/skills/**: AI 技能定義目錄。
  - `podcast-episode/`：Episode XML 生成規範。
  - `podcast-vocab/`：詞彙擴充流程規範。

## 📖 內容規劃

目前整理了 30 集，涵蓋我平常工作或未來可能會碰到的領域：

- **基礎**：CS Basics (OS, Network, Algo)。
- **開發**：Git, Database, Backend (.NET), Frontend。
- **進階**：Cloud (AWS/Azure), Architecture, DevOps。
- **軟實力**：溝通、開會、職涯發展。

## 🎙️ 訂閱 Podcast

Podcast RSS feed：<https://cloudywing.github.io/software-english-podcast/rss.xml>

- Apple Podcasts：在資料庫中搜尋本節目；若尚未上架，可於支援 URL 訂閱的 Podcast App 貼上 RSS feed。
- Spotify：在 Spotify 搜尋本節目，平台審核完成後即可追蹤。
- YouTube／YouTube Music：頻道擁有者於 YouTube Studio 選「建立 → 新 Podcast → 提交 RSS feed」提交上述 feed，YouTube 會為每集自動產生「靜態封面＋音訊」影片並公開發布至 Channel，同一節目亦會出現在 YouTube Music。
- 其他 Podcast App：選擇「透過 URL 加入」或「Add by RSS Feed」，再貼上上述 RSS feed。

> YouTube Studio 提交屬公開上架（同時出現在 YouTube 與 YouTube Music）；YouTube Music App 內的「Add podcast by RSS feed」只把節目加入個人媒體庫，不等於公開發布。

## 🚀 How to Run

### 本機手動執行

```powershell
# 設定 Azure Speech Key
$env:TTS_KEY = "your_key"
$env:TTS_REGION = "eastasia"

# 一次轉換所有集數
./scripts/Batch-Convert.ps1

# 或單獨轉換某一集
./scripts/Convert-Podcast.ps1 -InputFile "transcripts/Episode 01 - ..." -ApiKey $env:TTS_KEY -Region $env:TTS_REGION
```

## 🔗 Reference

- [Speech Synthesis Markup Language (SSML) overview](https://learn.microsoft.com/zh-tw/azure/ai-services/speech-service/speech-synthesis-markup-voice)

## ⚠️ Disclaimer

本專案語音由 Azure AI 生成。內容是我自己整理加上 AI 輔助的，主要自用，僅供參考。

## 📄 License

CC BY-SA 4.0
