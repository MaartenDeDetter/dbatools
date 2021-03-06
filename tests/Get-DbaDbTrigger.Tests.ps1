$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        $paramCount = 6
        $defaultParamCount = 11
        [object[]]$params = (Get-ChildItem function:\Get-DbaDbTrigger).Parameters.Keys
        $knownParameters = 'SqlInstance', 'SqlCredential', 'Database', 'ExcludeDatabase', 'InputObject', 'EnableException'
        It "Should contain our specific parameters" {
            ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $paramCount
        }
        It "Should only contain $paramCount parameters" {
            $params.Count - $defaultParamCount | Should Be $paramCount
        }
    }
}

Describe "$commandname Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        #trigger adapted from https://docs.microsoft.com/en-us/sql/t-sql/statements/create-trigger-transact-sql?view=sql-server-2017
        $trigger = @"
CREATE TRIGGER dbatoolsci_safety
    ON DATABASE
    FOR DROP_SYNONYM
    AS
    IF (@@ROWCOUNT = 0)
    RETURN;
    RAISERROR ('You must disable Trigger "dbatoolsci_safety" to drop synonyms!',10, 1)
    ROLLBACK
"@
        $server = Connect-DbaInstance -SqlInstance $script:instance2
        $server.Query("$trigger")
    }
    AfterAll {
        $server = Connect-DbaInstance -SqlInstance $script:instance2
        $trigger = "DROP TRIGGER dbatoolsci_safety ON DATABASE;"
        $server.Query("$trigger")
    }

    Context "Gets Database Trigger" {
        $results = Get-DbaDbTrigger -SqlInstance $script:instance2 | Where-Object {$_.name -eq "dbatoolsci_safety"}
        It "Gets results" {
            $results | Should Not Be $null
        }
        It "Should be enabled" {
            $results.isenabled | Should Be $true
        }
        It "Should have text of Trigger" {
            $results.text | Should BeLike '*FOR DROP_SYNONYM*'
        }
    }
    Context "Gets Database Trigger when using -Database" {
        $results = Get-DbaDbTrigger -SqlInstance $script:instance2 -Database Master
        It "Gets results" {
            $results | Should Not Be $null
        }
        It "Should be enabled" {
            $results.isenabled | Should Be $true
        }
        It "Should have text of Trigger" {
            $results.text | Should BeLike '*FOR DROP_SYNONYM*'
        }
    }
    Context "Gets no Database Trigger when using -ExcludeDatabase" {
        $results = Get-DbaDbTrigger -SqlInstance $script:instance2 -ExcludeDatabase Master
        It "Gets no results" {
            $results | Should Be $null
        }
    }
}