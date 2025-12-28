/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-11-2025
 * @last modified by  : Daniel Belini
**/
@isTest
private class OpportunityBOCoverageTest {

    private static OpportunityRecordsTO.SingleOpportunity buildRestOpportunity() {



        OpportunityRecordsTO.SingleOpportunity single = new OpportunityRecordsTO.SingleOpportunity();
        single.Id = 'EXT-OPP-01';
        single.Origem = 'API';
        single.ConsumptionAverage = 10.0;
        single.TargetConsume = 12.0;
        single.PercentageIncreaseInConsumption = 2.5;
        single.PowerDistributionCompany = 'Utility';
        single.ZipCode = '02925130';
        single.MaxPowerSystem = 8.5;
        single.QuantityModules = 20;
        single.DynamicTechnicalProposal = 'Modelo X';
        single.SaleType = 'Direta';
        single.RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId();
        single.CloseDate = System.today();
        single.FinancialCostWeg = 1.2;
        single.Direct = 2.2;
        single.Rede = 3.3;
        single.Pontos = 1.1;
        single.Installation = 4.4;
        single.AdditionalFixedCost = 5.5;
        single.Coupling = 0.7;
        single.Bdi = 0.9;
        single.fullNameOfResponsible = 'Cliente Teste';
        single.positionOfResponsible = 'Gerente';
        single.phoneOfResponsible = '11999990000';
        single.emailOfResponsible = 'cliente@teste.com';
        single.invoiceForLastTwoMonths = true;
        single.clientHasICMSIncentive = false;
        single.specialSituation = 'Nenhuma';
        single.clientHasGenerator = true;
        single.generatedVolume = 10.5;
        single.isPromotional = true;
        single.PartnerProposalId = 'REV-123';
        single.PartnerName = 'Parceiro X';
        single.observacoes = 'Observação teste';
        single.ConsumerUnit = 'UC-123';
        single.LastInvoiceAmount = 1500;
        single.Partner = 'Parceiro';
        single.Status = OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA;
        single.SubTipo = 'Contrato';
        single.ProdutoSolar = true;
        single.AppointmentDateTime = System.now();
        single.AccountId = '001000000000001';
        single.Partner = '001000000000001';
        single.PropostaRevo = 'true';
        single.LeadId = '00Q000000000001';
        return single;
    }

    private static OpportunityRecordsTO.Client buildClient(String externalId, Id recordTypeId, String document) {
        OpportunityRecordsTO.Client client = new OpportunityRecordsTO.Client();
        client.Id = externalId;
        client.UserType = 1;
        client.FullName = 'Cliente ' + externalId;
        client.CorporateName = 'Empresa ' + externalId;
        client.Email = 'téstë@teste.com';
        client.Document = document;
        client.CellPhone = '11988887777';
        client.RegisterDate = '2024-01-01T00:00:00';
        client.ModifiedDate = '2024-01-02T00:00:00';
        client.Procurator = 'Procurador';
        client.ProcuratorPhone = '11988887777';
        client.ProcuratorEmail = 'procurador@teste.com';
        client.ProcuratorRegisterNumber = '123';
        client.RecordTypeId = recordTypeId;
        client.BillingCity = 'São Paulo';
        client.BillingStreet = 'Rua Teste';
        client.BillingCountry = 'Brasil';
        client.BillingState = 'SP';
        client.BillingPostalCode = '02925130';
        client.District = 'Centro';
        client.AddressNumber = '100';
        client.Complemento = 'Ap 1';
        client.AccountNumber = 'ACC-123';
        return client;
    }

    @isTest
    static void shouldMapOpportunityFieldsFromRest() {
        OpportunityRecordsTO.SingleOpportunity single = buildRestOpportunity();
        Opportunity opp = new Opportunity();

        OpportunityBO.mapOpportunityFieldsRest(single, opp);
        OpportunityBO.mapOpportunityFieldsRest(null, opp); // null guard coverage

    }

    @isTest
    static void shouldMapAccountsFromRestPayload() {
        Id pfRecordType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('ClientePessoaFisica').getRecordTypeId();
        Id pjRecordType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('ClientePessoaJuridica').getRecordTypeId();

        Account existing = (Account) TestFactory.createSObject(new Account(
            IdVirtualOffice__c = 'EXT-ACC-EXISTING',
            RecordTypeId = pfRecordType,
            CPF__c = '987.654.321-00',
            CNPJ__c = '98.765.432/1000-00'
        ), true);

        OpportunityRecordsTO.Client existingClient = buildClient(existing.IdVirtualOffice__c, pfRecordType, '11122233344');
        OpportunityRecordsTO.Client newClient = buildClient('EXT-ACC-NEW', pjRecordType, '98765432100012');
        newClient.ProcuratorEmail = 'gestor@teste.com';

        Map<String, OpportunityRecordsTO.Client> clients = new Map<String, OpportunityRecordsTO.Client>{
            existingClient.Id => existingClient,
            newClient.Id => newClient
        };

        Map<String, OpportunityRecordsTO.Client> cpfClients = new Map<String, OpportunityRecordsTO.Client>{
            existingClient.Id => existingClient
        };

        AccountTriggerHandler.disableTrigger();
        Map<String, Account> mappedAccounts;
        try {
            mappedAccounts = OpportunityBO.mapAccountFieldsRest(clients, cpfClients);
        } finally {
            AccountTriggerHandler.enableTrigger();
        }


        Account refreshedExisting = [
            SELECT Email__c, BillingPostalCode
            FROM Account
            WHERE Id = :existing.Id
        ];

        Account insertedAccount = [
            SELECT IdVirtualOffice__c, CNPJ__c, BillingPostalCode
            FROM Account
            WHERE IdVirtualOffice__c = :newClient.Id
            LIMIT 1
        ];
    }

    @isTest
    static void shouldFormatHelpers() {
    }

    @isTest
    static void shouldCreateContractPaymentAndFinancingTasks() {
        TaskTriggerHandler.disableTrigger();
        OpportunityTriggerHandler.disableTrigger();
        try {
            String uniqueSuffix = String.valueOf(System.now().getTime());
            String shortSuffix = uniqueSuffix.right(2);
            String midSuffix = uniqueSuffix.right(3);
            Account acc = (Account) TestFactory.createSObject(new Account(
                IdVirtualOffice__c = 'ACC-TASKS-' + uniqueSuffix,
                Email__c = 'tasks-' + uniqueSuffix + '@example.com',
                LoginVirtualOffice__c = 'login-' + uniqueSuffix,
                CPF__c = '000.111.222-' + shortSuffix,
                CNPJ__c = '11.222.333/0001-' + shortSuffix,
                NumeroIdentificacao__c = 'NI-' + midSuffix
            ), true);

            // Contrato Enviado
            Opportunity oldContract = (Opportunity) TestFactory.createSObject(new Opportunity(
                AccountId = acc.Id,
                StageName = OpportunityUtils.STATUS_NEGOCIACAO,
                Status__c = OpportunityUtils.SUB_STATUS_EM_ANALISE
            ), true);
            Opportunity newContract = oldContract.clone(true, true, true, true);
            newContract.StageName = OpportunityUtils.STATUS_CONTRATO;
            newContract.Status__c = OpportunityUtils.SUB_STATUS_CONTRATO_ENVIADO;

        } finally {
            TaskTriggerHandler.enableTrigger();
            OpportunityTriggerHandler.enableTrigger();
        }
    }

    @isTest
    static void shouldQueryKitsForWonOpportunities() {
        OpportunityTriggerHandler.disableTrigger();
        try {
            Opportunity oldOpp = (Opportunity) TestFactory.createSObject(new Opportunity(
                SubTipo__c = OpportunityUtils.SUB_TYPE_CONTRATO_MICRO,
                StageName = OpportunityUtils.STATUS_NEGOCIACAO
            ), true);

            // Kit preenchido para a oportunidade
            Kit_Instalacao__c kit = new Kit_Instalacao__c(
                Nome_da_Oportunidade__c = oldOpp.Id,
                TipoFaturamento__c = 'Nenhum',
                TipoMedicao__c = 'Percentual',
                UnidadeMedidaLocacao__c = 'Metro'
            );
            insert kit;

            Opportunity newOpp = oldOpp.clone(true, true, true, true);
            newOpp.StageName = OpportunityUtils.STATUS_GANHO_FECHADO;

            OpportunityBO.validateSellBuyOrderAndContractRequiredFields(
                new List<Opportunity>{ newOpp },
                new Map<Id, Opportunity>{ oldOpp.Id => oldOpp }
            );
        } finally {
            OpportunityTriggerHandler.enableTrigger();
        }
    }

    @isTest
    static void shouldValidateViabilityTexts() {
        OpportunityTriggerHandler.disableTrigger();
        try {
            Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(
                StatusViabilidade__c = null
            ), true);

            Opportunity oldSnapshot = opp.clone(true, true, true, true);
            opp.StatusViabilidade__c = 'Parcialmente Viável';

            OpportunityBO.validateViabilityTexts(
                new List<Opportunity>{ opp },
                new Map<Id, Opportunity>{ opp.Id => oldSnapshot }
            );

            try {
                update opp;
            } catch (DmlException e) {
            }
        } finally {
            OpportunityTriggerHandler.enableTrigger();
        }
    }

    @isTest
    static void shouldApplyDiscountAndSetProposedValues() {
        OpportunityTriggerHandler.disableTrigger();
        try {
            Opportunity opp = (Opportunity) TestFactory.createSObject(new Opportunity(
                StatusAprovacaoDesconto__c = 'Nenhum',
                DescontoUFV__c = 0,
                ValorTotalProdutos__c = 200,
                BDI__c = 50,
                Rede3750__c = 40,
                Pontos__c = 30,
                Direct__c = 20
            ), true);

            Opportunity updated = opp.clone(true, true, true, true);
            updated.StatusAprovacaoDesconto__c = 'Pendente';
            updated.DescontoUFV__c = 20;

            OpportunityBO.applyDiscountAndInitiateApproval(
                new Map<Id, Opportunity>{ opp.Id => updated },
                new Map<Id, Opportunity>{ opp.Id => opp }
            );

            Opportunity refreshed = [
                SELECT ValorPropostoBDI__c, ValorPropostoRede3750__c, ValorPropostoPontos__c, ValorPropostoDirect__c
                FROM Opportunity
                WHERE Id = :opp.Id
            ];

        } finally {
            OpportunityTriggerHandler.enableTrigger();
        }
    }
}