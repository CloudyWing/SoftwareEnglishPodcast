[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$TranscriptDir,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$Mp3Dir,

    [Parameter(Mandatory)]
    [string]$OutputFile,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoOwner,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoName,

    [Parameter(Mandatory)]
    [ValidatePattern('^https://')]
    [string]$FeedBaseUrl,

    [Parameter(Mandatory)]
    [ValidatePattern('^[^\s@]+@[^\s@]+\.[^\s@]+$')]
    [string]$OwnerEmail
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [Parameter(Mandatory)]
        [string]$FailureMessage
    )

    $output = & $Command @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        $details = ($output | Out-String).Trim()
        throw "$FailureMessage $details"
    }

    ($output | Out-String).Trim()
}

function Get-ReleaseAssetName {
    param(
        [Parameter(Mandatory)]
        [string]$FileName
    )

    $normalizedName = [regex]::Replace($FileName, '[^A-Za-z0-9._-]+', '.')
    [regex]::Replace($normalizedName, '\.+', '.')
}

function Get-EpisodeDuration {
    param(
        [Parameter(Mandatory)]
        [string]$Mp3Path
    )

    $durationText = Invoke-NativeCommand `
        -Command 'ffprobe' `
        -Arguments @('-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', $Mp3Path) `
        -FailureMessage "ffprobe 無法讀取音檔：$Mp3Path。"

    $durationSeconds = 0.0
    if (-not [double]::TryParse(
        $durationText,
        [System.Globalization.NumberStyles]::Float,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref]$durationSeconds
    )) {
        throw "ffprobe 回傳無效的 duration：$durationText。"
    }

    $roundedSeconds = [long][Math]::Round($durationSeconds, [MidpointRounding]::AwayFromZero)
    $duration = [TimeSpan]::FromSeconds($roundedSeconds)
    $totalHours = [long][Math]::Floor($duration.TotalHours)
    '{0:D2}:{1:D2}:{2:D2}' -f $totalHours, $duration.Minutes, $duration.Seconds
}

function Get-PublicationDate {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory)]
        [string]$TranscriptPath
    )

    $relativePath = [System.IO.Path]::GetRelativePath($RepositoryRoot, $TranscriptPath).Replace('\', '/')
    $commitDate = Invoke-NativeCommand `
        -Command 'git' `
        -Arguments @('-C', $RepositoryRoot, 'log', '-1', '--format=%cI', '--', $relativePath) `
        -FailureMessage "無法取得 transcript 的 Git commit 時間：$relativePath。"

    if ([string]::IsNullOrWhiteSpace($commitDate)) {
        throw "Git 歷史中找不到 transcript：$relativePath。"
    }

    [DateTimeOffset]::Parse(
        $commitDate,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::RoundtripKind
    )
}

try {
    $resolvedTranscriptDir = (Resolve-Path -LiteralPath $TranscriptDir).Path
    $resolvedMp3Dir = (Resolve-Path -LiteralPath $Mp3Dir).Path
    $repositoryRoot = Invoke-NativeCommand `
        -Command 'git' `
        -Arguments @('-C', $resolvedTranscriptDir, 'rev-parse', '--show-toplevel') `
        -FailureMessage '無法判斷 Git repository 根目錄。'

    $transcripts = @(Get-ChildItem -LiteralPath $resolvedTranscriptDir -File -Filter '*.xml' | Sort-Object Name)
    if ($transcripts.Count -ne 30) {
        throw "預期 30 個 transcript，實際找到 $($transcripts.Count) 個。"
    }

    $episodes = foreach ($transcript in $transcripts) {
        if ($transcript.Name -notmatch '^Episode (\d{2}) - .+\.xml$') {
            throw "Transcript 檔名格式錯誤：$($transcript.Name)。"
        }

        $episodeNumber = $Matches[1]
        $mp3Path = Join-Path $resolvedMp3Dir "$($transcript.BaseName).mp3"
        if (-not (Test-Path -LiteralPath $mp3Path -PathType Leaf)) {
            throw "找不到 Episode $episodeNumber 對應的 MP3：$mp3Path。"
        }

        $publicationDate = Get-PublicationDate -RepositoryRoot $repositoryRoot -TranscriptPath $transcript.FullName
        $releaseAssetName = Get-ReleaseAssetName -FileName "$($transcript.BaseName).mp3"
        $encodedFileName = [Uri]::EscapeDataString($releaseAssetName)

        [pscustomobject]@{
            EpisodeNumber = $episodeNumber
            Title = $transcript.BaseName
            Guid = "sep-episode-$episodeNumber"
            PublicationDate = $publicationDate
            Duration = Get-EpisodeDuration -Mp3Path $mp3Path
            EnclosureUrl = "https://github.com/$RepoOwner/$RepoName/releases/latest/download/$encodedFileName"
            EnclosureLength = (Get-Item -LiteralPath $mp3Path).Length
        }
    }

    $episodeNumbers = @($episodes.EpisodeNumber | Sort-Object -Unique)
    $episodeGuids = @($episodes.Guid | Sort-Object -Unique)
    if ($episodeNumbers.Count -ne 30 -or $episodeGuids.Count -ne 30) {
        throw 'Episode 編號或 GUID 有重複。'
    }

    $outputPath = [System.IO.Path]::GetFullPath($OutputFile)
    $outputDirectory = [System.IO.Path]::GetDirectoryName($outputPath)
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
        $null = New-Item -ItemType Directory -Path $outputDirectory -Force
    }

    $feedRootUrl = $FeedBaseUrl.TrimEnd('/')
    $feedUrl = "$feedRootUrl/rss.xml"
    $coverUrl = "$feedRootUrl/cover.png"
    $itunesNamespace = 'http://www.itunes.com/dtds/podcast-1.0.dtd'
    $atomNamespace = 'http://www.w3.org/2005/Atom'
    $settings = [System.Xml.XmlWriterSettings]::new()
    $settings.Encoding = [System.Text.UTF8Encoding]::new($false)
    $settings.Indent = $true
    $settings.IndentChars = '  '
    $settings.NewLineChars = "`n"

    $writer = [System.Xml.XmlWriter]::Create($outputPath, $settings)
    try {
        $writer.WriteStartDocument()
        $writer.WriteStartElement('rss')
        $writer.WriteAttributeString('version', '2.0')
        $writer.WriteAttributeString('xmlns', 'itunes', $null, $itunesNamespace)
        $writer.WriteAttributeString('xmlns', 'atom', $null, $atomNamespace)
        $writer.WriteStartElement('channel')
        $writer.WriteElementString('title', 'Software English Podcast')
        $writer.WriteElementString('description', '工程師技術英語 Podcast，透過中英對話、發音示範與職場情境學習軟體開發詞彙。')
        $writer.WriteElementString('link', "https://github.com/$RepoOwner/$RepoName")
        $writer.WriteElementString('language', 'zh-tw')
        $writer.WriteElementString('copyright', 'CC BY-SA 4.0')
        $writer.WriteStartElement('atom', 'link', $atomNamespace)
        $writer.WriteAttributeString('href', $feedUrl)
        $writer.WriteAttributeString('rel', 'self')
        $writer.WriteAttributeString('type', 'application/rss+xml')
        $writer.WriteEndElement()
        $writer.WriteElementString('itunes', 'author', $itunesNamespace, $RepoOwner)
        $writer.WriteStartElement('itunes', 'owner', $itunesNamespace)
        $writer.WriteElementString('itunes', 'name', $itunesNamespace, $RepoOwner)
        $writer.WriteElementString('itunes', 'email', $itunesNamespace, $OwnerEmail)
        $writer.WriteEndElement()
        $writer.WriteStartElement('itunes', 'image', $itunesNamespace)
        $writer.WriteAttributeString('href', $coverUrl)
        $writer.WriteEndElement()
        $writer.WriteStartElement('itunes', 'category', $itunesNamespace)
        $writer.WriteAttributeString('text', 'Technology')
        $writer.WriteEndElement()
        $writer.WriteElementString('itunes', 'explicit', $itunesNamespace, 'false')

        foreach ($episode in ($episodes | Sort-Object PublicationDate -Descending)) {
            $writer.WriteStartElement('item')
            $writer.WriteElementString('title', $episode.Title)
            $writer.WriteElementString('description', $episode.Title)
            $writer.WriteStartElement('guid')
            $writer.WriteAttributeString('isPermaLink', 'false')
            $writer.WriteString($episode.Guid)
            $writer.WriteEndElement()
            $writer.WriteElementString('pubDate', $episode.PublicationDate.ToString('r', [System.Globalization.CultureInfo]::InvariantCulture))
            $writer.WriteStartElement('enclosure')
            $writer.WriteAttributeString('url', $episode.EnclosureUrl)
            $writer.WriteAttributeString('length', $episode.EnclosureLength.ToString([System.Globalization.CultureInfo]::InvariantCulture))
            $writer.WriteAttributeString('type', 'audio/mpeg')
            $writer.WriteEndElement()
            $writer.WriteElementString('itunes', 'duration', $itunesNamespace, $episode.Duration)
            $writer.WriteElementString('itunes', 'episode', $itunesNamespace, ([int]$episode.EpisodeNumber).ToString([System.Globalization.CultureInfo]::InvariantCulture))
            $writer.WriteStartElement('itunes', 'image', $itunesNamespace)
            $writer.WriteAttributeString('href', $coverUrl)
            $writer.WriteEndElement()
            $writer.WriteEndElement()
        }

        $writer.WriteEndElement()
        $writer.WriteEndElement()
        $writer.WriteEndDocument()
    }
    finally {
        $writer.Dispose()
    }

    Write-Host "RSS feed 已產生：$outputPath"
    exit 0
}
catch {
    Write-Error "RSS feed 產生失敗：$($_.Exception.Message)"
    exit 1
}
