#----------------------------------------------------------------------
# SCRIPT DE COLETA DE DADOS DE CONTAS DE USUÁRIOS INATIVAS NO AD
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

        # Cria o modelo de coleta de dados capturando os campos usando o foreach
        foreach ($user in $users) {

            # Captura todos os campos
            $Name = $user.Name
            $OU = $user.DistinguishedName.Split(',')[1].split('=')[1]
            $domainName = ($user.DistinguishedName -split ',' -match '^DC=' -replace '^DC=', '') -join '.'
            $LastLogonTime = [datetime]::FromFileTime($user.LastLogonTimestamp)

            # Cria a estrutura para export do processo em CSV
            New-Object -TypeName PSCustomObject -Property @{
                Name = $Name
                Domain = $domainName
                LastLogonTimestamp = $LastLogonTime
                OU = $OU
            } | Export-Csv -Path C:\path\sanitizacao_coleta.csv -NoTypeInformation -Append
        }
    } else {
        Write-Host "Controlador de domínio não encontrado para $domain"
    }
}