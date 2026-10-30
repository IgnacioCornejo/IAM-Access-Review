# Script de Access Review - FinTech Global (Sin tildes)
$BasePath = "OU=FinTech Global,OU=Proyectos IAM,DC=empresa,DC=local"
$ReportPathHTML = "C:\Access_Review_Report.html"
$ReportPathCSV = "C:\Access_Review_Findings.csv"

Write-Host "Iniciando auditoria de accesos..." -ForegroundColor Cyan

$Expirados = Get-ADUser -Filter {Enabled -eq $true} -SearchBase $BasePath -Properties AccountExpirationDate | Where-Object { $_.AccountExpirationDate -ne $null -and $_.AccountExpirationDate -lt (Get-Date) }

$Mismatch = @()
$Usuarios = Get-ADUser -Filter * -SearchBase $BasePath -Properties Department, MemberOf
foreach ($u in $Usuarios) {
    if ($u.Department) {
        foreach ($grupo in $u.MemberOf) {
            $nombreGrupo = (Get-ADGroup -Identity $grupo).Name
            if ($nombreGrupo -like "*Finanzas*" -and $u.Department -ne "Finanzas") {
                $Mismatch += "$($u.Name) (Depto: $($u.Department)) tiene acceso al grupo $nombreGrupo"
            }
            if ($nombreGrupo -like "*IT*" -and $u.Department -ne "IT") {
                $Mismatch += "$($u.Name) (Depto: $($u.Department)) tiene acceso al grupo $nombreGrupo"
            }
        }
    }
}

$Admins = @()
$UsuariosAdmin = Get-ADUser -Filter * -SearchBase $BasePath -Properties Title, MemberOf
foreach ($u in $UsuariosAdmin) {
    foreach ($grupo in $u.MemberOf) {
        $nombreGrupo = (Get-ADGroup -Identity $grupo).Name
        if ($nombreGrupo -like "*Admin*" -and $u.Title -notmatch "Directora|Gerente|Soporte Sr") {
            $Admins += "$($u.Name) - Cargo: $($u.Title) - Grupo: $nombreGrupo"
        }
    }
}

$dataCSV = @()
foreach ($e in $Expirados) { $dataCSV += [PSCustomObject]@{ Tipo="Cuenta Expirada"; Usuario=$e.Name; Detalle="Vencimiento: $($e.AccountExpirationDate.ToShortDateString())" } }
foreach ($m in $Mismatch) { $dataCSV += [PSCustomObject]@{ Tipo="Mismatch de Area"; Usuario=$m.Split(" ")[0]; Detalle=$m } }
foreach ($a in $Admins) { $dataCSV += [PSCustomObject]@{ Tipo="Privilegio Excesivo"; Usuario=$a.Split(" ")[0]; Detalle=$a } }

if ($dataCSV.Count -gt 0) {
    $dataCSV | Export-Csv -Path $ReportPathCSV -NoTypeInformation -Encoding UTF8
}

$html = @"
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 40px; color: #333; background-color: #f4f6f9; }
        .container { background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); max-width: 800px; margin: auto; }
        h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        h2 { color: #e74c3c; margin-top: 30px; }
        ul { list-style-type: none; padding-left: 0; }
        li { background-color: #f8f9fa; margin-bottom: 10px; padding: 15px; border-left: 5px solid #e74c3c; border-radius: 4px; }
        .info { background-color: #e8f4f8; padding: 15px; border-radius: 5px; border-left: 5px solid #3498db; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Reporte de Auditoria de Accesos (Access Review)</h1>
        <div class="info">
            <p><strong>Empresa:</strong> FinTech Global</p>
            <p><strong>Total de usuarios auditados:</strong> $($Usuarios.Count)</p>
        </div>
        
        <h2>1. Cuentas Expiradas (Contratistas)</h2>
"@

if ($Expirados.Count -eq 0) { $html += "<p>No se encontraron cuentas expiradas.</p>" }
else { $html += "<ul>"; foreach ($e in $Expirados) { $html += "<li><strong>$($e.Name)</strong>: Cuenta activa pero vencio el $($e.AccountExpirationDate.ToShortDateString())</li>" }; $html += "</ul>" }

$html += "<h2>2. Inconsistencias de Acceso (Minimo Privilegio)</h2>"
if ($Mismatch.Count -eq 0) { $html += "<p>No se encontraron inconsistencias.</p>" }
else { $html += "<ul>"; foreach ($m in $Mismatch) { $html += "<li>$m</li>" }; $html += "</ul>" }

$html += "<h2>3. Privilegios Excesivos (Usuarios con Admin)</h2>"
if ($Admins.Count -eq 0) { $html += "<p>No se encontraron privilegios excesivos.</p>" }
else { $html += "<ul>"; foreach ($a in $Admins) { $html += "<li>$a</li>" }; $html += "</ul>" }

$html += "</div></body></html>"

[System.IO.File]::WriteAllText($ReportPathHTML, $html, [System.Text.Encoding]::UTF8)

Write-Host "Auditoria completada. Reportes generados." -ForegroundColor Green