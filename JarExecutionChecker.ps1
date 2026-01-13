Clear-Host
Write-Host "Made by YarpLetapStan`nDM YarpLetapStan for Questions or Bugs`n" -ForegroundColor Cyan

# ASCII Art Title - Simple symbols style
$asciiTitle = @"
 __    __  _____  ______  _____  _       _____  _____  _____  _____  _____  _____  _____  __    _    ___   _____           
 \ \  / / /  _  \ | ___ \| ___ \| |     | ____||_   _|/  _  \| ___ \/  ___||_   _|/  _  \ |  \ | |  /  /  /  ___|       
  \ \/ /  | |_| | | |_/ /| |_/ /| |     | |__    | |  | |_| || |_/ /\ '--.   | |  | |_| | |   \| | /__/   \ '--.          
   \  /   |  _  | |    / |  __/ | |     |  __|   | |  |  _  ||  __/  '--. \  | |  |  _  | | |\   |         '--. \        
    | |   | | | | | |\ \ | |    | |___  | |___   | |  | | | || |    /\__/ /  | |  | | | | | | \  |         /\__/ /      
    \_/   \_| |_/ \_| \_|\_|    |_____| |_____|  \_/  \_| |_/\_|    \____/   \_/  \_| |_/ \_| |__/         \____/        
                                                                                                         
       __   __  _____  ____     _____ __   _  _____  _    __    __  _____ _____ ______             
      |  \/  |/  _  \|  _ \   /  _  \|  \ | |/  _  \| |   \ \  / / |___  ||  ___|| ___ \            
      | .  . || | | || | | |  | |_| ||   \| || |_| || |    \ \/ /     / / | |__  | |_/ /            
      | |\/| || | | || | | |  |  _  || |\  ||  _  || |      \  /     / /  |  __| |    /             
      | |  | || |_| || |/ /   | | | || | \ || | | || |____   | |    / /___| |___ | |\ \             
      \_|  |_/\_____/|___/    \_| |_/\_| |_/\_| |_/|______|  \_/   /_____/|_____|\_| \_|
"@

Write-Host $asciiTitle -ForegroundColor cyan
Write-Host ""

# Create subtitle line style matching the image
$subtitleText = "YarpLetapStan's Mod Analyzer V5.0"
$lineWidth = 80
$topBorder = "=" * $lineWidth
$bottomBorder = "=" * $lineWidth

Write-Host $topBorder -ForegroundColor cyan
Write-Host $subtitleText.PadLeft(($lineWidth + $subtitleText.Length) / 2) -ForegroundColor Cyan
Write-Host $bottomBorder -ForegroundColor cyan
Write-Host ""
