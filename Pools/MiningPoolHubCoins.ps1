﻿using module ..\Include.psm1

param(
    [alias("UserName")]
    [String]$User, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$MiningPoolHubCoins_Request = [PSCustomObject]@{}

try {
    $MiningPoolHubCoins_Request = Invoke-RestMethod "http://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics&$(Get-Date -Format "yyyy-MM-dd_HH-mm")" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($MiningPoolHubCoins_Request.return | Measure-Object).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$MiningPoolHubCoins_Regions = "europe", "us-east", "asia"
$MiningPoolHubCoins_Fee = 0.9 + 0.2

$MiningPoolHubCoins_Request.return | Where-Object {$_.pool_hash -gt 0} | ForEach-Object {
    $MiningPoolHubCoins_Host = $_.host
    $MiningPoolHubCoins_Hosts = $_.host_list.split(";")
    $MiningPoolHubCoins_Port = $_.port
    $MiningPoolHubCoins_Algorithm = $_.algo
    $MiningPoolHubCoins_Algorithm_Norm = Get-Algorithm $MiningPoolHubCoins_Algorithm
    $MiningPoolHubCoins_Coin = (Get-Culture).TextInfo.ToTitleCase(($_.coin_name -replace "-", " " -replace "_", " ")) -replace " "

    if ($MiningPoolHubCoins_Algorithm_Norm -eq "Sia") {$MiningPoolHubCoins_Algorithm_Norm = "SiaClaymore"} #temp fix
    if ($MiningPoolHubCoins_Algorithm_Norm -eq "Equihash-BTG") { #temp fix for wrong host url in API
        $MiningPoolHubCoins_Hosts = $MiningPoolHubCoins_Hosts | Foreach-Object {if ($_ -match "(^hub|\.hub)") {$_ -replace "^hub\.","equihash-hub." -replace "\.hub\.",".equihash-hub."} else {$_}}    
    }

    $Divisor = 1000000000

    $Stat = Set-Stat -Name "$($Name)_$($MiningPoolHubCoins_Coin)_Profit" -Value ([Double]$_.profit / $Divisor) -Duration $StatSpan -ChangeDetection $true

    $MiningPoolHubCoins_Regions | ForEach-Object {
        $MiningPoolHubCoins_Region = $_
        $MiningPoolHubCoins_Region_Norm = Get-Region ($MiningPoolHubCoins_Region -replace "^us-east$", "us")

        if ($User -or $InfoOnly) {
            [PSCustomObject]@{
                Algorithm     = $MiningPoolHubCoins_Algorithm_Norm
                Info          = $MiningPoolHubCoins_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $MiningPoolHubCoins_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHubCoins_Region*"} | Select-Object -First 1
                Port          = $MiningPoolHubCoins_Port
                User          = "$User.$Worker"
                Pass          = "x"
                Region        = $MiningPoolHubCoins_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $MiningPoolHubCoins_Fee
            }

            if ($MiningPoolHubCoins_Algorithm_Norm -eq "Ethash" -and $MiningPoolHubCoins_Coin -NotLike "*ethereum*") {
                [PSCustomObject]@{
                    Algorithm     = "$($MiningPoolHubCoins_Algorithm_Norm)2gb"
                    Info          = $MiningPoolHubCoins_Coin
                    Price         = $Stat.Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = $MiningPoolHubCoins_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHubCoins_Region*"} | Select-Object -First 1
                    Port          = $MiningPoolHubCoins_Port
                    User          = "$User.$Worker"
                    Pass          = "x"
                    Region        = $MiningPoolHubCoins_Region_Norm
                    SSL           = $false
                    Updated       = $Stat.Updated
                    PoolFee       = $MiningPoolHubCoins_Fee
                }
            }

            if ($MiningPoolHubCoins_Algorithm_Norm -eq "CryptonightV7" -or $MiningPoolHubCoins_Algorithm_Norm -like "Equihash*") {
                [PSCustomObject]@{
                    Algorithm     = $MiningPoolHubCoins_Algorithm_Norm
                    Info          = $MiningPoolHubCoins_Coin
                    Price         = $Stat.Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+ssl"
                    Host          = $MiningPoolHubCoins_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHubCoins_Region*"} | Select-Object -First 1
                    Port          = $MiningPoolHubCoins_Port
                    User          = "$User.$Worker"
                    Pass          = "x"
                    Region        = $MiningPoolHubCoins_Region_Norm
                    SSL           = $true
                    Updated       = $Stat.Updated
                    PoolFee       = $MiningPoolHubCoins_Fee
                }
            }
        }
    }
}