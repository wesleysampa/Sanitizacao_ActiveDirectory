#----------------------------------------------------------------------
# SCRIPT DE EXCLUSÃO DE CONTAS DE USUÁRIOS INATIVAS NO AD
#----------------------------------------------------------------------

# PRÉ-REQUISITOS
# Rodar os comandos abaixo para gerar a credencial de cada domínio e salvar em arquivo criptografado

$cred = Get-Credential
$cred | Export-Clixml -Path "C:\path\to\cred\domain1_cred.xml"

# Lista de domínios, caminhos para os arquivos de credenciais e controladores de domínio

$domains = @{
    "domain1.com" = @{
        "CredentialPath" = "C:\path\to\domain1_cred.xml"
        "DomainController" = "dc.domain1.com"
    }
    "domain2.com" = @{
        "CredentialPath" = "C:\path\to\domain2_cred.xml"
        "DomainController" = "dc.domain2.com"
    }
    "domain3.com" = @{
        "CredentialPath" = "C:\path\to\domain3_cred.xml"
        "DomainController" = "dc.domain3.com"
    }
}

# Define o período de inatividade em dias

$daysInactive = 60
$inactiveDate = (Get-Date).AddDays(-$daysInactive)

# Importa as credenciais do arquivo

foreach ($domain in $domains.Keys) {
    $cred = Import-Clixml -Path $domains[$domain]["CredentialPath"]
    $domainController = $domains[$domain]["DomainController"]

    # Verifica se o controlador de domínio foi obtido corretamente
    if (-not [string]::IsNullOrEmpty($domainController)) {

        # Define o contexto do domínio
        $domainContext = "DC=" + ($domain -replace '\.', ',DC=')

        # Captura os usuários inativos comparando LastLogonTimestamp e ignora os objetos duplicados
        $users = Get-ADUser -Server $domainController -Credential $cred -SearchBase $domainContext -Filter { LastLogonTimestamp -lt $inactiveDate } -Properties LastLogonTimestamp, DistinguishedName | Where-Object { $_.Name -NotLike "*CNF:*" }

        # Cria o modelo de processo de exclusão capturando os campos usando o foreach
        foreach ($user in $users) {

            # Captura todos os campos antes da exclusão
            $Name = $user.Name
            $OU = $user.DistinguishedName.Split(',')[1].split('=')[1]
            $domainName = ($user.DistinguishedName -split ',' -match '^DC=' -replace '^DC=', '') -join '.'
            $LastLogonTime = [datetime]::FromFileTime($user.LastLogonTimestamp)
            $namedel = $user.Name + "*"

            # Realiza a exclusão da conta
            Remove-ADUser -Identity $user -Server $domainController -Credential $cred -Confirm:$False

            # Captura os campos após a exclusão para confirmar se foi deletado e data da execução
            $IsDeleted = (Get-ADObject -Filter "name -like '$namedel'" -Server $domainController -Credential $cred -IncludeDeletedObjects -Properties IsDeleted).Deleted
            $WhenDeleted = (Get-ADObject -Filter "name -like '$namedel'" -Server $domainController -Credential $cred -IncludeDeletedObjects -Properties WhenChanged).WhenChanged

            # Cria a estrutura para export do processo em CSV
            New-Object -TypeName PSCustomObject -Property @{
                Name = $Name
                Domain = $domainName
                LastLogonTimestamp = $LastLogonTime
                OU = $OU
                Deleted = $IsDeleted
                DateExclude = $WhenDeleted
            } | Export-Csv -Path C:\path\sanitizacao_exclusao.csv -NoTypeInformation -Append
        }
    } else {
        Write-Host "Controlador de domínio não encontrado para $domain"
    }
}