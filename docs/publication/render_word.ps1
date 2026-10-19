param(
    [Parameter(Mandatory=$true)][string]$SourceDirectory,
    [Parameter(Mandatory=$true)][string]$QaDirectory,
    [string]$FileName = '*.docx'
)
# Windows fallback when the Documents skill renderer has no LibreOffice.
# Read-only Word export changes neither source Markdown nor generated DOCX.
$ErrorActionPreference = 'Stop'
$wordApp = New-Object -ComObject Word.Application
$wordApp.Visible = $false
$wordApp.DisplayAlerts = 0
$wordApp.AutomationSecurity = 3
$results = @()
try {
    foreach ($source in Get-ChildItem -LiteralPath $SourceDirectory -Recurse -File -Filter $FileName) {
        $relativeName = [System.IO.Path]::GetRelativePath($SourceDirectory, $source.FullName)
        $outputDirectory = Join-Path $QaDirectory ([System.IO.Path]::ChangeExtension($relativeName, $null))
        New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
        $pdf = Join-Path $outputDirectory ($source.BaseName + '.pdf')
        $document = $null
        try {
            $document = $wordApp.Documents.Open($source.FullName, $false, $true, $false)
            $document.Repaginate()
            $pages = $document.ComputeStatistics(2)
            $document.ExportAsFixedFormat($pdf, 17)
            $results += [pscustomobject]@{document=$relativeName; pages=$pages; pdf=$pdf; renderer='Microsoft Word 16 PDF export'}
            Write-Output ($relativeName + ' ' + $pages + ' pages')
        } finally {
            if ($null -ne $document) {
                $document.Close(0)
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($document) | Out-Null
            }
        }
    }
} finally {
    $wordApp.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wordApp) | Out-Null
}
ConvertTo-Json -InputObject @($results) -Depth 4 | Set-Content -LiteralPath (Join-Path $QaDirectory 'word-render-results.json') -Encoding utf8
