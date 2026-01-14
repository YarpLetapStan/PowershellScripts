Clear-Host
Write-Host "Made by YarpLetapStan`nM YarpLetapStan for Questions or Bugs`n" -ForegroundColor Cyan

# ASCII Art Title - Using block characters
$asciiTitle = @"
██╗   ██╗ █████╗ ██████╗ ██████╗ ██╗     ███████╗████████╗ █████╗ ██████╗ ███████╗████████╗ █████╗ ███╗   ██╗ ╗███████╗
╚██╗ ██╔╝██╔══██╗██╔══██╗██╔══██╗██║     ██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝██╔══██╗████╗  ██║╔╝██╔════╝
 ╚████╔╝ ███████║██████╔╝██████╔╝██║     █████╗     ██║   ███████║██████╔╝███████╗   ██║   ███████║██╔██╗ ██║  ███████╗
  ╚██╔╝  ██╔══██║██╔══██╗██╔═══╝ ██║     ██╔══╝     ██║   ██╔══██║██╔═══╝ ╚════██║   ██║   ██╔══██║██║╚██╗██║  ╚════██║
   ██║   ██║  ██║██║  ██║██║     ███████╗███████╗   ██║   ██║  ██║██║     ███████║   ██║   ██║  ██║██║ ╚████║  ███████║
   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝  ╚══════╝

███╗   ███╗ ██████╗ ██████╗      █████╗ ███╗   ██╗ █████╗ ██╗     ██╗   ██╗███████╗███████╗██████╗ 
████╗ ████║██╔═══██╗██╔══██╗    ██╔══██╗████╗  ██║██╔══██╗██║     ╚██╗ ██╔╝╚══███╔╝██╔════╝██╔══██╗
██╔████╔██║██║   ██║██║  ██║    ███████║██╔██╗ ██║███████║██║      ╚████╔╝   ███╔╝ █████╗  ██████╔╝
██║╚██╔╝██║██║   ██║██║  ██║    ██╔══██║██║╚██╗██║██╔══██║██║       ╚██╔╝   ███╔╝  ██╔══╝  ██╔══██╗
██║ ╚═╝ ██║╚██████╔╝██████╔╝    ██║  ██║██║ ╚████║██║  ██║███████╗   ██║   ███████╗███████╗██║  ██║
╚═╝     ╚═╝ ╚═════╝ ╚═════╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚══════╝╚══════╝╚═╝  ╚═╝
"@

Write-Host $asciiTitle -ForegroundColor Blue
Write-Host ""

# Create subtitle line style with double solid lines
$subtitleText = "YarpLetapStan's Mod Analyzer V5.0"
$lineWidth = 80
$line = "─" * $lineWidth

Write-Host $line -ForegroundColor Blue
Write-Host $line -ForegroundColor Blue
Write-Host $subtitleText.PadLeft(($lineWidth + $subtitleText.Length) / 2) -ForegroundColor Cyan
Write-Host $line -ForegroundColor Blue
Write-Host $line -ForegroundColor Blue
Write-Host ""


Clear-Host
Write-Host "Made by YarpLetapStan`nDM YarpLetapStan for Questions or Bugs`n" -ForegroundColor Cyan

# ASCII Art Title - Using block characters
$asciiTitle = @"
██╗   ██╗ █████╗ ██████╗ ██████╗ ██╗     ███████╗████████╗ █████╗ ██████╗ ███████╗████████╗ █████╗ ███╗   ██╗███████╗
╚██╗ ██╔╝██╔══██╗██╔══██╗██╔══██╗██║     ██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝██╔══██╗████╗  ██║██╔════╝
 ╚████╔╝ ███████║██████╔╝██████╔╝██║     █████╗     ██║   ███████║██████╔╝███████╗   ██║   ███████║██╔██╗ ██║███████╗
  ╚██╔╝  ██╔══██║██╔══██╗██╔═══╝ ██║     ██╔══╝     ██║   ██╔══██║██╔═══╝ ╚════██║   ██║   ██╔══██║██║╚██╗██║╚════██║
   ██║   ██║  ██║██║  ██║██║     ███████╗███████╗   ██║   ██║  ██║██║     ███████║   ██║   ██║  ██║██║ ╚████║███████║
   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝

███╗   ███╗ ██████╗ ██████╗      █████╗ ███╗   ██╗ █████╗ ██╗     ██╗   ██╗███████╗███████╗██████╗ 
████╗ ████║██╔═══██╗██╔══██╗    ██╔══██╗████╗  ██║██╔══██╗██║     ╚██╗ ██╔╝╚══███╔╝██╔════╝██╔══██╗
██╔████╔██║██║   ██║██║  ██║    ███████║██╔██╗ ██║███████║██║      ╚████╔╝   ███╔╝ █████╗  ██████╔╝
██║╚██╔╝██║██║   ██║██║  ██║    ██╔══██║██║╚██╗██║██╔══██║██║       ╚██╔╝   ███╔╝  ██╔══╝  ██╔══██╗
██║ ╚═╝ ██║╚██████╔╝██████╔╝    ██║  ██║██║ ╚████║██║  ██║███████╗   ██║   ███████╗███████╗██║  ██║
╚═╝     ╚═╝ ╚═════╝ ╚═════╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚══════╝╚══════╝╚═╝  ╚═╝
"@

Write-Host $asciiTitle -ForegroundColor Blue
Write-Host ""

# Create subtitle line style matching the image
$subtitleText = "YarpLetapStan's Mod Analyzer V5.0"
$lineWidth = 80
$topBorder = "=" * $lineWidth
$bottomBorder = "=" * $lineWidth

Write-Host $topBorder -ForegroundColor Blue
Write-Host $subtitleText.PadLeft(($lineWidth + $subtitleText.Length) / 2) -ForegroundColor Cyan
Write-Host $bottomBorder -ForegroundColor Blue
Write-Host ""
