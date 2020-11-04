<#
    .SYNOPSIS
        Script qui permet de faire un mapping des group/user dans une liste de domaines
    
    .DESCRIPTION
        A partir de la liste des domaines le script fait
            Listing de tous les groups
                Listing de chaque user du groupe
        Output total dans un fichier text
    
    .INPUTS
         [BOOL] BypassConfirm = $false
            Ce parametre permet de rouler le script de facon a valider les configurations avant de le lancer
            En mettant a $true, le script ne demande pas de valider et est lancer automatiquement.

    .OUTPUTS
        Outputs the general flow of the application
        outputs to file the complete content of the data collected

    .NOTES
        Version:        1.0
        Author:         Ugo Deschamps
        Creation Date:  2019/12/16
        Purpose/Change: Initial function devellopement
#>
<#
##################################################################################################################
################################################  CLASS CREATION  ################################################
##################################################################################################################
#>

Param (
    [bool]$BypassConfirm = $false
)


class ADMember
{
<#  [DATA SAMPLE        : Get-ADGroupMember -Identity S-1-5-21-****** -Server domain_name -recursive]
    [FIELDNAME          : DB_DATATYPE  ] [VALUE]

    [DISTINGUISHEDNAME  : VARCHAR(255) ] 
    [NAME               : VARCHAR(255) ] 
    [OBJECTCLASS		    : VARCHAR(255) ] 
    [SAMACCOUNTNAME     : VARCHAR(255) ] 
    [SID        		    : VARCHAR(255) ]
#>
    [string]$DistinguishedName  = ""
    [string]$Name               = ""
    [string]$ObjectClass        = ""
    [string]$samAccountName     = ""
    [string]$SID                = ""

    #CLASS CREATOR
    ADMember([string]$DistinguishedName, [string]$Name, [string]$ObjectClass, [string]$samAccountName, [string]$SID){
        $this.DistinguishedName = $DistinguishedName
        $this.Name              = $Name
        $this.ObjectClass       = $ObjectClass
        $this.samAccountName    = $samAccountName
        $this.SID               = $SID
    }
}
class ADGroup
{
<#  [DATA SAMPLE        : Get-ADGroup -server domain_name -filter *]
    [FIELDNAME          : DB_DATATYPE  ] [VALUE]

    [SID				        : VARCHAR(255) ] 
	  [NAME				        : VARCHAR(255) ] 
	  [SAMACCOUNTNAME     : VARCHAR(255) ]
	  [GROUPSCOPE			    : VARCHAR(255) ] 
	  [OBJECTCLASS		    : VARCHAR(255) ]
	  [DISTINGUISEDNAME	  : VARCHAR(255) ]
#>  
    [string]$DistinguishedName  = ""
    [string]$GroupScope         = ""
    [string]$Name               = ""
    [string]$ObjectClass        = ""
    [string]$samAccountName     = ""
    [string]$SID                = ""
    [System.Collections.ArrayList]$Member = @()

    #CLASS CREATOR
    ADGroup([string]$DistinguishedName, [string]$GroupScope, [string]$Name, [string]$ObjectClass, [string]$SamAccountName, [string]$SID){
        $this.DistinguishedName = $DistinguishedName
        $this.GroupScope        = $GroupScope
        $this.Name              = $Name
        $this.ObjectClass       = $ObjectClass
        $this.samAccountName    = $SamAccountName
        $this.SID               = $SID
   }

   #CLASS METHOD (CREATES NEW MEMBER)
   [void]AddMember([string]$DistinguishedName, [string]$Name, [string]$ObjectClass, [string]$samAccountName, [string]$SID)
   {
       $newMember = [ADMember]::new($DistinguishedName, $Name, $ObjectClass, $samAccountName, $SID)
       $this.Member.Add($newMember)
   }
}
class ADDomain
{
<#  [DATA SAMPLE        : Get-ADGroup -server domain_name -filter *]
    [FIELDNAME          : DB_DATATYPE  ] [VALUE]

    [DISTINGUISHEDNAME  : VARCHAR(255) ] 
    [DNSROOT            : VARCHAR(255) ] 
    [DOMAINMODE         : VARCHAR(255) ] 
    [DOMAINSID          : VARCHAR(255) ] 
    [FOREST             : VARCHAR(255) ] 
    [NAME               : VARCHAR(255) ] 
    [NETBIOSNAME        : VARCHAR(255) ] 
    [OBJECTCLASS        : VARCHAR(255) ] 
    [PARENTDOMAIN       : VARCHAR(255) ]
#>  
    [string]$DistinguishedName  = ""
    [string]$DNSRoot            = ""
    [string]$DomainMode         = ""
    [string]$DomainSID          = ""
    [string]$Forest             = ""
    [string]$Name               = ""
    [string]$NetBIOSName        = ""
    [string]$ObjectClass        = ""
    [string]$ParentDomain       = ""
    [System.Collections.ArrayList]$Groups = @()

    #CLASS CREATOR
    ADDomain([string]$DistinguishedName, [string]$DNSRoot, [string]$DomainMode, [string]$DomainSID, [string]$Forest, 
                [string]$Name, [string]$NetBIOSName, [string]$ObjectClass,[string]$ParentDomain){
        $this.DistinguishedName  = $DistinguishedName
        $this.DNSRoot            = $DNSRoot
        $this.DomainMode         = $DomainMode
        $this.DomainSID          = $DomainSID
        $this.Forest             = $Forest
        $this.Name               = $Name
        $this.NetBIOSName        = $NetBIOSName
        $this.ObjectClass        = $ObjectClass
        $this.ParentDomain       = $ParentDomain
   }
   #CLASS CREATOR FOR DOMAIN THAT WE CANNOT GET DATA FROM
   ADDomain([string]$DNSRoot){
       $this.DNSRoot = $DNSRoot
   }

   #CLASS METHOD (CREATES NEW MEMBER)
   [void]AddGroup([string]$DistinguishedName, [string]$GroupScope, [string]$Name, [string]$ObjectClass, [string]$SamAccountName, [string]$SID)
   {
       $newGroup = [ADGroup]::new($DistinguishedName, $GroupScope, $Name, $ObjectClass, $SamAccountName, $SID)
       $this.Groups.Add($newGroup)
    }
    [void]AddGroup([ADGroup]$group)
    {
        $this.Groups.Add($group)
    }
}

<#
##################################################################################################################
##############################################  CONST INITIALIZING  ##############################################
##################################################################################################################
#>
$ADForest = (Get-ADForest)
$ADDomains = Get-ADForest | ForEach-Object {$_.Domains}
$dumpfile = "c:/temp/AllData.json" # MODIFY THIS FOR THE JSON FILE

$tmp = $ADDomains | ForEach-Object {$_+"`n"}

$initialMSG = @"
------------------------------------------------------------------
 _   _ _       _     _      _____                    _           
| \ | (_)     | |   | |    / ____|                  | |          
|  \| |_  __ _| |__ | |_  | |     _ __ __ ___      _| | ___ _ __ 
| . ' | |/ _' | '_ \| __| | |    | '__/ _' \ \ /\ / / |/ _ \ '__|
| |\  | | (_| | | | | |_  | |____| | | (_| |\ V  V /| |  __/ |   
|_| \_|_|\__, |_| |_|\__|  \_____|_|  \__,_| \_/\_/ |_|\___|_|   
          __/ |                                                  
         |___/                                                  

------------------------------------------------------------------
[Written by : Ugo Deschamps]
------------------------------------------------------------------
                      [Configurations]
------------------------------------------------------------------
[Forest]
$ADForest

[Domain list]
$tmp

[DUMP]
$dumpfile
------------------------------------------------------------------
"@
<#
##################################################################################################################
############################################  END OF INITIALISATION  #############################################
##################################################################################################################
#>
function get_members{
    <#
        .DESCRIPTION
            Retourne un arraylist des group member dun groupe
            NO VALIDATION

        .INPUTS
            GroupSID    : S-1-5-21-*******
            DNSRoot     : Domaine Root, sert pour la recherche sur un serveur specific
            GroupName   : Administrateurs, sert au visuel seulement
        
        .OUTPUTS
            Retourne un object $null ou un arraylist de la recherche

    #>
    Param ( 
        [Parameter(Mandatory=$true)] 
        [string]$GroupSID,
        [Parameter(Mandatory=$true)] 
        [string]$DNSRoot,
        [string]$GroupName
    )

    $ret = @()
    Write-Host -ForegroundColor DarkGray "LOADING USER FROM GROUP :"$GroupName
    $ret = Get-ADGroupMember -Identity $GroupSID -Server $DNSRoot -Recursive
    
    $Count = $ret.Count
    if(!$Count){$Count = 0}
    Write-Host -ForegroundColor cyan "[LOADED"$Count" USERS]"

    return $ret
}
function get_groups{
    <#
        .DESCRIPTION
            Retourne un arraylist des group sur un serveur donner
            NO VALIDATION

        .INPUTS
            DNSRoot     : Domaine Root
        .OUTPUTS
            Retourne $Null 

    #>
    Param( [Parameter(Mandatory=$true)] [string]$DNSRoot )

    $ret = @()
    Write-Host -ForegroundColor DarkGray "[LOADING GROUPS FROM :"$DNSRoot"]"    
    $ret = Get-ADGroup -filter {(GroupCategory -eq "Security")} -Server $DNSRoot
    Write-Host -ForegroundColor DarkGray "[LOADED"$ret.count"GROUPS]"

    return $ret
}
function get_domain{
    Param( [string]$domainName )

    $dom = @()
    #MAKES IT EASIER TO FIND DOMAINS IN LOG FILE
    Write-Host -ForegroundColor DarkGray "----------------------------------------------------------------------------------"
    Write-Host -ForegroundColor DarkGray "----------------------------------------------------------------------------------"
    Write-Host -ForegroundColor cyan "Checking $domainname"
    Write-Host -ForegroundColor DarkGray "----------------------------------------------------------------------------------"
    Write-Host -ForegroundColor DarkGray "----------------------------------------------------------------------------------"

    #MAKES SURE DOMAIN IS REACHABLE
    if(Test-Connection $domainName -Quiet -Count 1 ) {
        Write-Host -ForegroundColor cyan "Connected and getting data..."

        #TRY NEEDED FOR DOMAIN THAT ARE CONNECTED BUT CANNOT GET DATA FROM
        try{
            $dom = get-addomain $domainName -ErrorAction SilentlyContinue
            $newDomain = [ADDomain]::new($dom.DistinguishedName, $dom.DNSRoot, $dom.DomainMode, $dom.DomainSID,
            $dom.Forest, $dom.Name, $dom.NetBIOSName, $dom.ObjectClass, $dom.ParentDomain)

            Write-Host -ForegroundColor cyan "Information gathering completed"
        }
        catch{ 
            $msg = "ERROR GETTING INFORMATION FROM : $domainName" 
            Write-Debug $Error.tostring()
        }
    }
    else{ $msg = "$domainName is OFFLINE" }
    
    if(!$dom) { 
        $newDomain = [ADDomain]::new($domainName) 
        Write-Warning -Message $msg
    }
    return $newDomain
}
function Main(){
    <#
    #>
    Param ( [System.Collections.ArrayList]$ADDATA )
    
    ForEach($domain in $ADDomains){  
        $newDomain = @((get_domain $domain))

        #CHECKS TO SEE IF DOMAIN HAS INFO LOADED 
        #THIS MAKES SURE THAT DOMAIN THAT WERENT CONNECTED ARE STILL IN THE COLLECTIONBUT WITHOUT ANY INFO ADDED
        if( $newDomain.Name -ne "" ){

            ForEach($group in (get_groups $newDomain.DNSRoot)){
                $newGroup = [ADGroup]::new($group.DistinguishedName, $group.GroupScope, $group.Name, $group.ObjectClass, $group.SamAccountName, $group.SID)

                ForEach($member in get_members $newgroup.SID $newdomain.DNSRoot $newGroup.Name){
                    $newGroup.AddMember($member.DistinguishedName, $member.Name, $member.ObjectClass, $member.samAccountName, $member.SID)
                }
                $newDomain.AddGroup($newGroup)
            }
        }
        [void]$ADDATA.Add($newDomain)
    }
}

#STARTUP ROUTINE
#SETS UP LOGGING
$logfile = $MyInvocation.MyCommand.path -replace '\.ps1$', '.log'
Start-Transcript -path $logfile
Clear-Host

Write-Host -ForegroundColor Cyan $initialMSG
#
if (!$BypassConfirm) {
    $ans = Read-Host "Continue?"
    if ($ans -ne "y") { 
        stop-transcript
        exit 
    }
}

#PROGRAM STARTING
[System.Collections.ArrayList]$ADDATA = @()
Main $ADDATA
$ADDATA | ConvertTo-Json -Depth 10 > $dumpfile
#END

Stop-Transcript
