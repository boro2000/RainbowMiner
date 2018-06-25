﻿using module ..\Include.psm1

$Path = ".\Bin\Ethash-Claymore9\monk.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v9.7-claymoredual/claymoredual_9.7.zip"
$Api = "Claymore"
$Port = "204{0:d2}"

$DevFee = 0.0
$DevFeeDual = 0.0

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = ""; SecondaryIntensity = 00; Params = ""} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "decred"; SecondaryIntensity = 40; Params = ""} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "decred"; SecondaryIntensity = 60; Params = ""} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "decred"; SecondaryIntensity = 80; Params = ""} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 30; Params = ""} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 40; Params = ""} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 50; Params = ""} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 27; Params = ""} #Ethash/Pascal
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 30; Params = ""} #Ethash/Pascal
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 33; Params = ""} #Ethash/Pascal
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = ""; SecondaryIntensity = 00; Params = ""} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "decred"; SecondaryIntensity = 40; Params = ""} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "decred"; SecondaryIntensity = 60; Params = ""} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "decred"; SecondaryIntensity = 80; Params = ""} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 30; Params = ""} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 40; Params = ""} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 50; Params = ""} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 27; Params = ""} #Ethash/Pascal
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 30; Params = ""} #Ethash/Pascal
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 33; Params = ""} #Ethash/Pascal
)
$CommonCommands = @(" -logsmaxsize 1", "") # array, first value for main algo, second value for secondary algo

#
# Internal presets, do not change from here on
#
$Coins = [PSCustomObject]@{
    "Pascal" = "pasc"
    "Lbry" = "lbc"
    "Decred" = "dcr"
    "Sia" = "sc"
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices = @($Devices.NVIDIA) + @($Devices.AMD) 
if (-not $Devices -and -not $Config.InfoOnly) {return} # No GPU present in system

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Vendor = Get-DeviceVendor $_
    $Miner_Model = $_.Model
    $Miner_Fee = $DevFee
    
    switch($Miner_Vendor) {
        "NVIDIA" {$Arguments_Platform = " -platform 2"}
        "AMD" {$Arguments_Platform = " -platform 1 -y 1"}
        Default {$Arguments_Platform = ""}
    }

    $Commands | ForEach-Object {
        $MainAlgorithm = $_.MainAlgorithm
        $MainAlgorithm_Norm = Get-Algorithm $MainAlgorithm

        Switch ($MainAlgorithm_Norm) {
            # default is all devices, ethash has a 4GB minimum memory limit
            "Ethash" {$Miner_Device = Select-Device $Device -MinMemSize 4gb}
            "Ethash3gb" {$Miner_Device = Select-Device $Device -MinMemSize 3gb}
            default {$Miner_Device = $Device}
        }

        if ($Miner_Device) {
            $DeviceIDsAll = Get-GPUIDs $Miner_Device -join '' -ToHex

            if ($Pools.$MainAlgorithm_Norm.Name -eq 'NiceHash') {$EthereumStratumMode = "3"} else {$EthereumStratumMode = "2"} #Optimize stratum compatibility

            if ($Arguments_Platform) {
                if ($_.SecondaryAlgorithm) {
                    $SecondaryAlgorithm = $_.SecondaryAlgorithm
                    $SecondaryAlgorithm_Norm = Get-Algorithm $SecondaryAlgorithm

                    $Miner_Name = (@($Name)+@("$($MainAlgorithm_Norm -replace '^ethash', '')$($SecondaryAlgorithm_Norm)") + @(if ($_.SecondaryIntensity -ge 0) {$_.SecondaryIntensity}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $Miner_HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $Stats."$($Miner_Name)_$($MainAlgorithm_Norm)_HashRate".Week; "$SecondaryAlgorithm_Norm" = $Stats."$($Miner_Name)_$($SecondaryAlgorithm_Norm)_HashRate".Week}
                    $Arguments_Secondary = " -mode 0 -dcoin $($Coins.$SecondaryAlgorithm) -dpool $($Pools.$SecondaryAlgorithm_Norm.Host):$($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass)$(if($_.SecondaryIntensity -ge 0){" -dcri $($_.SecondaryIntensity)"})"
                    $Miner_Fee = $DevFeeDual
                }
                else {
                    $Miner_Name = ((@($Name) + @("$($MainAlgorithm_Norm -replace '^ethash', '')") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-') -replace '-+','-'
                    $Miner_HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $Stats."$($Miner_Name)_$($MainAlgorithm_Norm)_HashRate".Week}
                    $Arguments_Secondary = " -mode 1"
                }

                [PSCustomObject]@{
                    Name        = $Miner_Name
                    DeviceName  = $Miner_Device.Name
                    DeviceModel = $Miner_Model
                    Path        = $Path               
                    Arguments   = ("EthDcrMiner64.exe -mport -$($Miner_Port) -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm_Norm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass) -allpools 1 -allcoins exp -esm $($EthereumStratumMode)$($Arguments_Secondary)$($_.Params)$($Arguments_Platform) -di $($DeviceIDsAll)" -replace "\s+", " ").trim()
                    HashRates   = $Miner_HashRates
                    API         = "Claymore"
                    Port        = $Miner_Port
                    URI         = $Uri
                    DevFee      = $Miner_Fee              
                    ExecName    = "EthDcrMiner64"
                }             
            }
        }
    }
}