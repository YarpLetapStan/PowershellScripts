Clear-Host
Write-Host "Made by YarpLetapStan`nDM YarpLetapStan for Questions or Bugs`n" -ForegroundColor Cyan

# ASCII Art Title - Simple symbols style
$asciiTitle = @"
 __    __  _____  ______  _____  _       _____  _____  _____  _____  _____  _____  __   _  __  _____ 
 \ \  / / /  _  \ | ___ \| ___ \| |     | ____||_   _|/  _  \| ___ \/  ___||_   _|/  \ | |/  |/  ___/
  \ \/ /  | |_| | | |_/ /| |_/ /| |     | |__    | |  | |_| || |_/ /\ `--.   | |  | |\ \| |\  |\ `--. 
   \  /   |  _  | |    / |  __/ | |     |  __|   | |  |  _  ||  __/  `--. \  | |  | | \ \ | \ | `--. \
    | |   | | | | | |\ \ | |    | |___  | |___   | |  | | | || |    /\__/ /  | |  | |  \ \| |\ \/\__/ /
    \_/   \_| |_/ \_| \_|\_|    |_____| |_____|  \_/  \_| |_/\_|    \____/   \_/  \_|  \___| \|\____/ 
                                                                                                         
       __   __  _____  ____     _____  __   _  _____  _       __    __  _____ _____ ______             
      |  \/  |/  _  \|  _ \   /  _  \|  \ | | /  _  \| |      \ \  / / |___  ||  ___|| ___ \            
      | .  . || | | || | | |  | |_| ||   \| | | |_| || |       \ \/ /     / / | |__  | |_/ /            
      | |\/| || | | || | | |  |  _  || |\  ||  _  || |        \  /     / /  |  __| |    /             
      | |  | || |_| || |/ /   | | | || | \ || | | || |____     | |    / /___| |___ | |\ \             
      \_|  |_/\_____/|___/    \_| |_/\_| |_/\_| |_/|______|    \_/   /_____/|_____|\_| \_|            
                                                                                                         
                       \ \   / /  _____     ___      ___                                                
                        \ \ / /  | ____|   | __|    / _ \                                               
                         \ V /   |___ \    |__ \ _ | | | |                                              
                          \_/    |____/ _  |___/(_)|_| |_|                                              
                                      |__|                                                              
"@

Write-Host $asciiTitle -ForegroundColor Blue
Write-Host ""

# Create subtitle box
$subtitleText = "YarpLetapStan's Mod Analyzer V5.0"
$boxWidth = $subtitleText.Length + 4
$border = "=" * $boxWidth
Write-Host "+$border+" -ForegroundColor Cyan
Write-Host "|  $subtitleText  |" -ForegroundColor Cyan
Write-Host "+$border+" -ForegroundColor Cyan
Write-Host ""
