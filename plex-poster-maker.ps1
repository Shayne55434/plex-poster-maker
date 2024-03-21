function Write-Log {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$Message,
      
      [Parameter(Mandatory)]
      [ValidateSet('Trace', 'Debug', 'Info', 'Warning', 'Error', 'Optional', 'Success')]
      [string]$Type,
      
      [Parameter(Mandatory)]
      [string]$Path,
      
      [int]$Width = 100,
      
      [switch]$Section,
      
      [switch]$SubText
   )
   
   switch ($Type) {
      'Trace' {
         $Color = 'Cyan'
      }
      'Debug' {
         $Color = 'DarkMagenta'
      }
      'Info' {
         $Color = 'White'
      }
      'Warning' {
         $Color = 'Yellow'
      }
      'Error' {
         $Color = 'Red'
      }
      'Optional' {
         $Color = 'Blue'
      }
      'Success' {
         $Color = 'Green'
      }
   }
   
   # Ensure a multi-lined $Message is displayed correctly
   $MessageLines = ($Message.Replace("`n`n", "`n")) -split "`n"
   
   foreach ($Line in $MessageLines) {
      $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
      $PaddedType = "[$($Type.ToUpper())]".PadRight(10)
      $LineNumber = "[L.$($MyInvocation.ScriptLineNumber)]".PadRight(6)
      $LineInfo = "[$Timestamp] $LineNumber $PaddedType "
      
      if ($SubText.IsPresent) {
         $Line = $Line.PadLeft($Line.Length + 5, ' ')
      }
      
      Write-Host ($LineInfo + '| ') -NoNewline
      Write-Host $Line -ForegroundColor $Color
      
      # Write the same info to the log file.
      ("$LineInfo | ") | Out-File $Path -NoNewline -Append
      $Line | Out-File $Path -NoNewline -Append
   }
   '' | Out-File $Path -Append
}
function Test-Config {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory, ParameterSetName = 'FilePath')]
      [ValidateNotNullOrEmpty()]
      [ValidateScript({Test-Path -Path $_})]
      [string]$FilePath,
      
      [Parameter(Mandatory, ParameterSetName = 'InputObject')]
      [ValidateNotNullOrEmpty()]
      [object]$InputObject
   )
   
   # Iterate through the config file and verify all settings
   function Test-Plex {
      
   }
   function Test-ImageProviders {
      
   }
   function Test-Magick {
      
   }
}
function Get-PlexToken {
   <#
      .SYNOPSIS
         Retrieves an authentication token from Plex.tv using provided credentials.
      
      .DESCRIPTION
         The Get-PlexToken function is used to obtain an authentication token from Plex.tv, which can be used to authenticate API requests to
         Plex servers. It prompts the user for their Plex credentials, including username and password, and optionally accepts a one-time password (OTP)
         for users with two-factor authentication (2FA) enabled.
      
      .PARAMETER Username
         Specifies the username for the Plex account. If not provided, the function will prompt the user to enter the username.
      
      .PARAMETER Credential
         Specifies the PSCredential object containing the Plex account credentials (username and password). If not provided, the function will prompt
         the user to enter the username and password.
      
      .EXAMPLE
         Get-PlexToken -Username "example_user"
         Prompts the user for the Plex password and any 2FA code, if enabled, and retrieves the Plex authentication token for the specified username.
      
      .EXAMPLE
         Get-PlexToken -Credential $Credential
         Retrieves the Plex authentication token using the provided PSCredential object containing the Plex account credentials.
      
      .NOTES
         The function utilizes the Invoke-RestMethod cmdlet to send a POST request to the Plex.tv API endpoint for user authentication. The authentication
         token is then extracted from the response and returned to the caller.
         
         If an error occurs during the authentication process, such as invalid credentials or network issues, the function will throw an exception with an
         appropriate error message.
   #>
   [CmdletBinding()]
   param(
      [Parameter()]
      [ValidateNotNullOrEmpty()]
      [string]$Username,
      
      [Parameter()]
      [ValidateNotNullOrEmpty()]
      [pscredential]$Credential
   )
   
   $URL = 'https://plex.tv/users/sign_in.json'
   $Header = @{
      'X-Plex-Client-Identifier' = 'PPM'
   }
   
   # If $Credential wasn't passed in
   if (-not $Credential) {
      if (-not $Username) {
         $Username = Read-Host 'Please enter your Plex username'
      }
      
      $Credential = Get-Credential -Message 'Please enter your Plex credentials' -UserName $Username
   }
   
   [string]$OTP = Read-Host 'Please enter your 2FA code (leave blank if not enbabled)'
   if ($OTP.Length -gt 0) {
      $SecurePassword = ($Credential.GetNetworkCredential().Password + $OTP) | ConvertTo-SecureString -AsPlainText
      $Credential = [PSCredential]::new($Credential.UserName, $SecurePassword)
   }
   
   try {
      # Get the Plex token
      $Response = Invoke-RestMethod -Method Post -Uri $URL -Headers $Header -Credential $Credential
      $PlexToken = $Response.user.authentication_token
      
      Write-Verbose "Plex token: $PlexToken"
   }
   catch {
      $ErrorMessage = $_.Exception.Message
      throw "Failed to retrieve your Plex token. $ErrorMessage"
   }
   
   return $PlexToken
}
function Get-PlexLibrary {
   <#
      .SYNOPSIS
         Retrieves information about libraries available on a Plex server.
      
      .DESCRIPTION
         The Get-PlexLibrary function queries a Plex server to retrieve information about all available libraries. It returns an array of objects containing details such as the library name, ID, and path.
      
      .PARAMETER ServerURL
         Specifies the URL of the Plex server from which to retrieve library information. This parameter is mandatory.
      
      .PARAMETER PlexToken
         Specifies the authentication token required to access the Plex server's API. This parameter is mandatory.
      
      .PARAMETER Include
         Specifies an optional array of library names to include in the results. If provided, only libraries with names matching those in the array will be returned.
      
      .EXAMPLE
         Get-PlexLibrary -ServerURL "http://plex.example.com:32400" -PlexToken "your-plex-token"
         Retrieves information about all libraries available on the Plex server located at the specified URL using the provided authentication token.
      
      .EXAMPLE
         Get-PlexLibrary -ServerURL "http://plex.example.com:32400" -PlexToken "your-plex-token" -Include "Movies", "TV Shows"
         Retrieves information about only the "Movies" and "TV Shows" libraries available on the Plex server.
      
      .NOTES
         The function uses the Plex Media Server API to retrieve information about libraries. It sends a GET request to the '/library/sections' endpoint of the Plex server and parses the response to extract library details.
         
         If an error occurs during the retrieval process, such as failure to connect to the server or invalid authentication token, the function will throw an exception with an appropriate error message.
   #>
   [CmdletBinding()]
   param(
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$ServerURL,
      
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$PlexToken,
      
      [Parameter()]
      [ValidateNotNullOrEmpty()]
      [string[]]$Include,
      
      [Parameter()]
      [ValidateSet('movie', 'show', 'artist')]
      [string[]]$Type = @('movie', 'show')
   )
   
   $Header = @{
      'X-Plex-Token' = $PlexToken
   }
   
   # Get a list of all libraries on the server
   $URL = "$ServerURL/library/sections"
   try {
      $Response = Invoke-RestMethod -Method Get -Uri $URL -Headers $Header
      $Libraries = $Response.MediaContainer.Directory | Where-Object {$_.type -in $Type} | Sort-Object -Property Title
      
      if ($Include) {
         $Libraries = $Libraries | Where-Object {$_.title -in $Include}
      }
   }
   catch {
      throw "Failed to retrieve a list libraries. $($_)"
      return
   }
   
   $PlexLibraryInfo = @()
   if ($Libraries.Count -gt 0) {
      foreach ($Library in $Libraries) {
         foreach ($LibraryPath in $Library.Location.path) {
            $objTemp = [PSCustomObject]@{
               ID   = $Library.key
               Type = $Library.type
               Name = $Library.title
               Path = $LibraryPath
            }
            
            $PlexLibraryInfo += $objTemp
         }
      }
   }
   
   Write-Verbose ("Got the following Libraries and Paths:`n" + ($PlexLibraryInfo | ForEach-Object {"`t$($_.LibraryName) ($($_.LibraryID)) - $($_.LibraryPath)`n"}))
   
   return $PlexLibraryInfo
}
function Get-PlexLibraryContent {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$ServerURL,
      
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$PlexToken,
      
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [int[]]$ID
   )
   
   $Content = $null
   foreach ($Library in $ID) {
      $Content += (Invoke-WebRequest -Method Get "$ServerURL/library/sections/$Library/all?X-Plex-Token=$PlexToken").Content
   }
   
   $Content
}
function Get-PosterFromProvider {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$Provider,
      
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$ProviderID,
      
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [ValidateSet('Poster', 'Background', 'Season', 'Episode')]
      [string]$PosterType,
      
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$FilePath
   )
}
function New-Poster {
   
}
function Out-Poster {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$ServerURL,
      
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$PlexToken,
      
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$ID,
      
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$FilePath
   )
   
   [xml]$Metadata = (Invoke-WebRequest -Method Get -Uri "$ServerURL/library/metadata/$($ID)?X-Plex-Token=$PlexToken").Content
   
   if ($Metadata.MediaContainer.Directory) {
      $URL = $ServerURL + $Metadata.MediaContainer.Directory.art + "?X-Plex-Token=$PlexToken"
   }
   else {
      $URL = $ServerURL + $Metadata.MediaContainer.Video.art + "?X-Plex-Token=$PlexToken"
   }
   
   $Bytes = (Invoke-WebRequest -Method Get -Uri $URL).Content
   [System.IO.File]::WriteAllBytes($FilePath, $Bytes)
}

[int]$TotalMemoryGB = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB

$Header = @"
================================================================================
  ____  _             ____           _              __  __       _              
 |  _ \| | _____  __ |  _ \ ___  ___| |_ ___ _ __  |  \/  | __ _| | _____ _ __  
 | |_) | |/ _ \ \/ / | |_) / _ \/ __| __/ _ \ '__| | |\/| |/ _``` | |/ / _ \ '__|
 |  __/| |  __/>  <  |  __/ (_) \__ \ ||  __/ |    | |  | | (_| |   <  __/ |    
 |_|   |_|\___/_/\_\ |_|   \___/|___/\__\___|_|    |_|  |_|\__,_|_|\_\___|_|    
 
 Version: 1.0
 Platform: $env:OS
 Memory: $TotalMemoryGB GB
================================================================================
"@

Clear-Host

Write-Log -Message $Header -Section -Type 'Info' -Path 'logs\script.log'
Write-Log -Message 'This is a message' -Type 'Info' -Path 'logs\script.log'
Write-Log -Message 'This subtext' -Type 'Trace' -Path 'logs\script.log' -SubText
Write-Log -Message 'This subtext' -Type 'Debug' -Path 'logs\script.log' -SubText
Write-Log -Message 'This subtext' -Type 'Info' -Path 'logs\script.log' -SubText
Write-Log -Message 'This subtext' -Type 'Warning' -Path 'logs\script.log' -SubText
Write-Log -Message 'This subtext' -Type 'Error' -Path 'logs\script.log' -SubText
Write-Log -Message 'This subtext' -Type 'Optional' -Path 'logs\script.log' -SubText
Write-Log -Message 'This subtext' -Type 'Success' -Path 'logs\script.log' -SubText

$config = Get-Content -Raw -Path $(Join-Path $PSScriptRoot 'config.json') | ConvertFrom-Json
$Include = $config.Plex.IncludedLibraries

# Test-Config -FilePath './config.json2' -InputObject $config