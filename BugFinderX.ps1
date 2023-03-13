$url = "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/directory-list-lowercase-2.3-big.txt"
$folders = (Invoke-WebRequest $url).Content -split "\r?\n" | Where-Object { $_ -notmatch '^#|\s|^$' }

$targetUrl = Read-Host "Ingrese la URL a verificar"
Write-Host "Verificando la URL: $targetUrl"

$existingFolders = @()
$totalFolders = $folders.Count
$progress = 0

$jobs = @()
$jobCounter = 0
foreach ($folder in $folders) {
    $folderUrl = "$targetUrl/$folder"
    $jobs += Start-Job -ScriptBlock {
        param($folderUrl, $folder)
        $response = Invoke-WebRequest $folderUrl -Method HEAD -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            $output = "{0,-50} {1,10}" -f "La carpeta {2} existe en {3}", "[OK]", $folder, $targetUrl
            Write-Output $output
            return $folder
        }
    } -ArgumentList $folderUrl, $folder
    $jobCounter++
    if ($jobCounter -eq 5) {
        $finishedJobs = $jobs | Wait-Job
        foreach ($job in $finishedJobs) {
            $result = Receive-Job $job
            if ($result) {
                $existingFolders += $result
            }
            Write-Progress -Activity "Verificando carpetas" -Status "Progreso: $progress/$totalFolders" -PercentComplete (($progress/$totalFolders)*100)
            $progress++
        }
        $jobs = @()
        $jobCounter = 0
    }
}

if ($jobs) {
    $finishedJobs = $jobs | Wait-Job
    foreach ($job in $finishedJobs) {
        $result = Receive-Job $job
        if ($result) {
            $existingFolders += $result
        }
        Write-Progress -Activity "Verificando carpetas" -Status "Progreso: $progress/$totalFolders" -PercentComplete (($progress/$totalFolders)*100)
        $progress++
    }
}

if ($existingFolders.Count -gt 0) {
    Write-Host "`nLas siguientes carpetas existen en $using:targetUrl:`n"
    $existingFolders | ForEach-Object { Write-Host $_ -ForegroundColor Green }
} else {
    Write-Host "`nNo se encontraron carpetas que existan en $targetUrl" -ForegroundColor Red
}
