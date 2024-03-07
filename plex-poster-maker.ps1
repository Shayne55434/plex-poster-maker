function Write-Log {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory)]
      [string]$Path,
      
      [string]$Message,
      
      [Parameter(Mandatory)]
      [ValidateSet('Info', 'Warning', 'Error', 'Optional', 'Debug', 'Trace', 'Success')]
      [string]$Type,
      
      [string]$Subtext = $null
   )
   switch ($Type) {
      'Info' {
         $Color = 'white'
      }
      'Warning' {
         $Color = 'yellow'
      }
      'Error' {
         $Color = 'red'
      }
      'Optional' {
         $Color = 'blue'
      }
      'Debug' {
         $Color = 'darkmagenta'
      }
      'Trace' {
         $Color = 'cyan'
      }
      'Success' {
         $Color = 'green'
      }
   }
   # ASCII art header
   if (-not $global:HeaderWritten) {
      $Header = @"
===============================================================================
____  _             ____           _              __  __       _        
|  _ \| | _____  __ |  _ \ ___  ___| |_ ___ _ __  |  \/  | __ _| | _____ _ __
| |_) | |/ _ \ \/ / | |_) / _ \/ __| __/ _ \ '__| | |\/| |/ _``` | |/ / _ \ '__|
|  __/| |  __/>  <  |  __/ (_) \__ \ ||  __/ |    | |  | | (_| |   <  __/ |
|_|   |_|\___/_/\_\ |_|   \___/|___/\__\___|_|    |_|  |_|\__,_|_|\_\___|_|

===============================================================================
"@
      Write-Host $Header
      $Header | Out-File $Path -Append
      $global:HeaderWritten = $true
   }
   $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
   $PaddedType = $Type.PadRight(8)
   $Linenumber = "L.$($MyInvocation.ScriptLineNumber)"
   if ($Linenumber.Length -eq '5') {
      $Linenumber = $Linenumber + ' '
   }
   $TypeFormatted = '[{0}] {1}|{2}' -f $Timestamp, $PaddedType.ToUpper(), $Linenumber
   
   if ($Message) {
      $FormattedLine1 = '{0}| {1}' -f ($TypeFormatted, $Message)
      $FormattedLineWritehost = '{0}| ' -f ($TypeFormatted)
   }
   
   if ($Subtext) {
      $FormattedLine = '{0}|      {1}' -f ($TypeFormatted, $Subtext)
      $FormattedLineWritehost = '{0}|      ' -f ($TypeFormatted)
      Write-Host $FormattedLineWritehost -NoNewline
      Write-Host $Subtext -ForegroundColor $Color
      $FormattedLine | Out-File $Path -Append
   }
   else {
      Write-Host $FormattedLineWritehost -NoNewline
      Write-Host $Message -ForegroundColor $Color
      $FormattedLine1 | Out-File $Path -Append
   }
}

$Header = @"

===============================================================================
  ____  _             ____           _              __  __       _             
 |  _ \| | _____  __ |  _ \ ___  ___| |_ ___ _ __  |  \/  | __ _| | _____ _ __ 
 | |_) | |/ _ \ \/ / | |_) / _ \/ __| __/ _ \ '__| | |\/| |/ _``` | |/ / _ \ '__|
 |  __/| |  __/>  <  |  __/ (_) \__ \ ||  __/ |    | |  | | (_| |   <  __/ |   
 |_|   |_|\___/_/\_\ |_|   \___/|___/\__\___|_|    |_|  |_|\__,_|_|\_\___|_|   

===============================================================================
"@
Write-Log -Message $Header -Path '.\logs\script.log' -Type Info