param(
	[int]$Count = 500,
	[switch]$SkipPrepare
)

$ErrorActionPreference = "Stop"

if ($Count -ne 500) {
	throw "This script is designed to generate exactly 500 WAV files. Use -Count 500."
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Resolve-Path (Join-Path $ScriptDir "..")

$DatasetDir = Join-Path $RootDir "dataset"
$AudioDir = Join-Path $DatasetDir "audio"
$PreparedDir = Join-Path $DatasetDir "prepared"
$MetadataCsv = Join-Path $DatasetDir "metadata.csv"
$PrepareScript = Join-Path $ScriptDir "2_prepare_dataset.py"

New-Item -ItemType Directory -Force -Path $AudioDir | Out-Null
New-Item -ItemType Directory -Force -Path $PreparedDir | Out-Null

Write-Host "=" * 64
Write-Host "Note Lingo - Windows Built-in TTS Dataset Generator"
Write-Host "=" * 64

# Build a deterministic set of 500 readable study-related transcripts.
$subjects = @(
	"the student",
	"the lecturer",
	"the researcher",
	"the engineer",
	"the team",
	"the developer",
	"the analyst",
	"the professor",
	"the presenter",
	"the project manager"
)

$verbs = @(
	"reviews",
	"summarizes",
	"explains",
	"records",
	"tests",
	"organizes",
	"compares",
	"improves",
	"documents",
	"verifies"
)

$objects = @(
	"the lecture notes for machine learning",
	"the meeting action items for this week",
	"the code changes before release",
	"the model training results from today",
	"the project timeline and next milestones"
)

$indexWords = @(
	"one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
	"eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty",
	"twenty one", "twenty two", "twenty three", "twenty four", "twenty five"
)

$sentences = New-Object System.Collections.Generic.List[string]
for ($objIndex = 0; $objIndex -lt $objects.Count; $objIndex++) {
	for ($subjectIndex = 0; $subjectIndex -lt $subjects.Count; $subjectIndex++) {
		for ($verbIndex = 0; $verbIndex -lt $verbs.Count; $verbIndex++) {
			$roundWord = $indexWords[$objIndex * $verbs.Count + $verbIndex]
			$sentence = "{0} {1} {2} in round {3}" -f $subjects[$subjectIndex], $verbs[$verbIndex], $objects[$objIndex], $roundWord
			[void]$sentences.Add($sentence)
		}
	}
}

if ($sentences.Count -ne 500) {
	throw "Unexpected sentence count: $($sentences.Count)"
}

Write-Host "Removing existing WAV files from audio and prepared folders..."
Get-ChildItem -Path $AudioDir -Filter *.wav -File -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -Path $PreparedDir -Filter *.wav -File -ErrorAction SilentlyContinue | Remove-Item -Force

Write-Host "Generating 500 WAV files with Windows SAPI voice..."
$voice = New-Object -ComObject SAPI.SpVoice
$voice.Rate = 0
$voice.Volume = 100

$metadataRows = New-Object System.Collections.Generic.List[object]

for ($i = 1; $i -le $Count; $i++) {
	$fileName = "sample_{0:D4}.wav" -f $i
	$outputPath = Join-Path $AudioDir $fileName
	$text = $sentences[$i - 1]

	$stream = New-Object -ComObject SAPI.SpFileStream
	# SSFMCreateForWrite = 3
	$stream.Open($outputPath, 3, $false)
	$voice.AudioOutputStream = $stream
	[void]$voice.Speak($text)
	$stream.Close()

	$metadataRows.Add([PSCustomObject]@{
		file = $fileName
		transcript = $text
	}) | Out-Null

	if (($i % 50) -eq 0) {
		Write-Host "  Generated $i/$Count"
	}
}

$voice.AudioOutputStream = $null

Write-Host "Writing metadata.csv..."
$csvLines = New-Object System.Collections.Generic.List[string]
[void]$csvLines.Add("file,transcript")

foreach ($row in $metadataRows) {
	$safeTranscript = $row.transcript.Replace('"', '""')
	[void]$csvLines.Add("$($row.file),`"$safeTranscript`"")
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($MetadataCsv, $csvLines, $utf8NoBom)

Write-Host "Done generating WAV dataset."
Write-Host "  audio:    $AudioDir"
Write-Host "  metadata: $MetadataCsv"

if ($SkipPrepare) {
	Write-Host "Skipping dataset preparation (requested by -SkipPrepare)."
	exit 0
}

if (-not (Test-Path $PrepareScript)) {
	throw "Could not find prepare script at: $PrepareScript"
}

Write-Host "Running dataset preparation script..."

$pythonCmd = $null
if (Get-Command py -ErrorAction SilentlyContinue) {
	$pythonCmd = "py"
	$pythonArgs = @("-3.11", $PrepareScript)
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
	$pythonCmd = "python"
	$pythonArgs = @($PrepareScript)
} else {
	throw "Python was not found (tried 'py' and 'python')."
}

Push-Location $RootDir
try {
	& $pythonCmd @pythonArgs
	if ($LASTEXITCODE -ne 0) {
		throw "Dataset preparation failed with exit code $LASTEXITCODE"
	}
}
finally {
	Pop-Location
}

Write-Host "All done: 500 WAV files generated and dataset prepared."
