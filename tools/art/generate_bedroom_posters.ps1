# Deterministic typography/diagram placeholders; no external artwork dependencies.
Add-Type -AssemblyName System.Drawing
$destination = Join-Path $PSScriptRoot '../../assets/meatspace/posters'
$names = @('VIRUS', 'PHREAKERS', 'WAREZ')
$files = @('poster_virus', 'poster_phreaker', 'poster_warez')
$colors = @('#cb654c', '#77b3a1', '#c8af62')
for ($index = 0; $index -lt 3; $index++) {
    $bitmap = New-Object System.Drawing.Bitmap 512, 640
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#242a2b'))
    $ink = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($colors[$index]))
    $paper = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#d2c9ad'))
    $pen = New-Object System.Drawing.Pen $ink, 5
    $title = New-Object System.Drawing.Font 'Consolas', 44, ([System.Drawing.FontStyle]::Bold)
    $small = New-Object System.Drawing.Font 'Consolas', 15
    $graphics.FillRectangle($ink, 26, 25, 460, 12)
    $graphics.DrawString('LOCAL / UNDERGROUND', $small, $paper, 28, 55)
    $graphics.DrawString($names[$index], $title, $ink, 24, 100)
    for ($line = 0; $line -lt 8; $line++) {
        $y = 230 + $line * 28
        if ($index -eq 0) {
            $graphics.DrawRectangle($pen, 120 + ($line % 3) * 17, $y, 220 - ($line % 3) * 34, 24)
        } elseif ($index -eq 1) {
            $graphics.DrawLine($pen, 60, $y, 450, $y)
            $graphics.DrawEllipse($pen, 90 + ($line % 4) * 80, $y - 14, 28, 28)
        } else {
            $graphics.DrawRectangle($pen, 90 + $line * 12, 215 + $line * 22, 240, 150)
        }
    }
    $graphics.DrawString(@('REPLICATE / MUTATE', 'THE LINE IS OURS', 'COPY / KEEP / SHARE')[$index], $small, $paper, 28, 540)
    $graphics.DrawString('NO. 0' + ($index + 1) + '   //   AFTER HOURS', $small, $paper, 28, 580)
    $bitmap.Save((Join-Path $destination ($files[$index] + '.png')), [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $bitmap.Dispose(); $ink.Dispose(); $paper.Dispose(); $pen.Dispose(); $title.Dispose(); $small.Dispose()
}
