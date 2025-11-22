/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 11-21-2025
 * @last modified by  : Daniel Belini
**/
public class OpportunityBO {
    public static Boolean skipAsyncProposalGeneration = false;

    //Realizar chamada de integraçãom para criação de pedidos de compra e de venda no SAP
    public static void createSellBuyOrder(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecordsMap){

        Set<Id> newWonOpportunitiesIds = new Set<Id>();
        
        for(Opportunity opportunity : newRecords){

            //Pegar Ids das Oportunidades que estão sendo ganhas
            if(OpportunityUtils.isStatusClosedWon(opportunity) && !OpportunityUtils.isStatusClosedWon(oldRecordsMap.get(opportunity.Id))){
                newWonOpportunitiesIds.add(opportunity.Id);
            }
        }

        if(!newWonOpportunitiesIds.isEmpty()){
            IntegracaoSAPPedidoVenda.sendPedidoVenda(newWonOpportunitiesIds);
        }
        
        if(!newWonOpportunitiesIds.isEmpty()){
            IntegracaoSAPPedidoCompra.sendPedidoCompra(newWonOpportunitiesIds);
        }
    }

    public static void assignOpportunitySellerToAccount(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecordsMap){
        Map<Id, Consultor__c> sellerMap = new Map<Id, Consultor__c>([
            SELECT  Id, IdVirtualOffice__c
            FROM    Consultor__c
            WHERE   Id IN :Collection.of(newRecords).pluckNotNullStrings(Opportunity.ConsultorOportunidade__c)
        ]);

        if(!sellerMap.isEmpty()){
            Map<Id, String> opportunityIdToSellerExternalId = new Map<Id, String>();
            List<Opportunity> contextOpps = new List<Opportunity>();
            for(Opportunity opp : newRecords){
                if(
                    Trigger.isInsert ||
                    (Trigger.isUpdate && opp.ConsultorOportunidade__c != oldRecordsMap.get(opp.Id).ConsultorOportunidade__c)
                ){
                    opportunityIdToSellerExternalId.put(opp.Id, sellerMap.get(opp.ConsultorOportunidade__c)?.IdVirtualOffice__c);
                    contextOpps.add(opp);
                }
            }

            Map<Id, Account> accountMap = new Map<Id, Account>([
                SELECT  Id, IdExternoConsultor__c
                FROM    Account
                WHERE   Id IN :Collection.of(newRecords).pluckNotNullStrings(Opportunity.AccountId)
            ]);
                
            if(!accountMap.isEmpty()){
                List<Account> accountsToUpdate = new List<Account>();
                for(Opportunity opp : contextOpps){
                    Account acc = accountMap.get(opp.AccountId);
                    acc.IdExternoConsultor__c = opportunityIdToSellerExternalId.get(opp.Id);
                    
                    accountsToUpdate.add(acc);
                }
                update accountsToUpdate;
            }
        }
    }
    
    //Realizar chamada de integração para envio de dados de geração do contrato para SAP 
    public static void sendContractDataSAP(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecordsMap){
        Set<Id> contextIds = new Set<Id>();
        for(Opportunity opportunity : newRecords){
            if(OpportunityUtils.isChangingContractGenerating(opportunity, oldRecordsMap.get(opportunity.Id))){
                contextIds.add(opportunity.Id);
            }
        }

        if(!contextIds.isEmpty()){
            IntegracaoSAPContrato.sendContract(contextIds);
        }
    }
    
    public static void mapOpportunityFieldsRest(
        OpportunityRecordsTO.SingleOpportunity singleOpportunity, 
        Opportunity opportunity
    ){
        if (singleOpportunity == null) {
            // Trate a situação em que singleOpportunity é null, se necessário
            return;
        }

        if (singleOpportunity.Id != null) {
            opportunity.IdVirtualOffice__c = singleOpportunity.Id;
        }
        if (singleOpportunity.Origem != null) {
            opportunity.Origem__c = singleOpportunity.Origem;
        }
        if (singleOpportunity.ConsumptionAverage != null) {
            opportunity.ConsumptionAverage__c = singleOpportunity.ConsumptionAverage;
            opportunity.MediaConsumo__c = singleOpportunity.ConsumptionAverage;
        }
        if (singleOpportunity.TargetConsume != null) {
            opportunity.ConsumoAlvo__c = singleOpportunity.TargetConsume;
        }
        if (singleOpportunity.PercentageIncreaseInConsumption != null) {
            opportunity.PorcentagemAumentoConsumo__c = singleOpportunity.PercentageIncreaseInConsumption;
        }
        if (singleOpportunity.PowerDistributionCompany != null) {
            opportunity.EmpresaDistribuicaoEnergia__c = singleOpportunity.PowerDistributionCompany;
        }
        if (singleOpportunity.ZipCode != null) {
            opportunity.CEP__c = singleOpportunity.ZipCode;
        }
        if (singleOpportunity.MaxPowerSystem != null) {
            opportunity.ForcaMaximaSistema__c = singleOpportunity.MaxPowerSystem;
        }
        if (singleOpportunity.QuantityModules != null) {
            opportunity.NumeroModulos__c = singleOpportunity.QuantityModules;
        }
        if (singleOpportunity.DynamicTechnicalProposal != null) {
            opportunity.PropostaTecnicaDinamica__c = singleOpportunity.DynamicTechnicalProposal; //trocar para Modelo__c
        }
        if (singleOpportunity.SaleType != null) {
            opportunity.TipoVenda__c = singleOpportunity.SaleType;
        }
        if (singleOpportunity.RecordTypeId != null) {
            opportunity.RecordTypeId = singleOpportunity.RecordTypeId;
        }
        if (singleOpportunity.CloseDate != null) {
            opportunity.CloseDate = singleOpportunity.CloseDate;
        }
        if (singleOpportunity.FinancialCostWeg != null) {
            opportunity.CustoFinanceiroWeg__c = singleOpportunity.FinancialCostWeg;
        }
        if (singleOpportunity.Direct != null) {
            opportunity.Direct__c = singleOpportunity.Direct;
        }
        if (singleOpportunity.Rede != null) {
            opportunity.Rede3750__c = singleOpportunity.Rede;
        }
        if (singleOpportunity.Pontos != null) {
            opportunity.Pontos__c = singleOpportunity.Pontos;
        }
        if (singleOpportunity.Installation != null) {
            opportunity.ValorInstalacao__c = singleOpportunity.Installation;
        }
        if (singleOpportunity.AdditionalFixedCost != null) {
            opportunity.CustoAdicionalFixo__c = singleOpportunity.AdditionalFixedCost;
        }
        if (singleOpportunity.Coupling != null) {
            opportunity.Acoplamento__c = singleOpportunity.Coupling;
        }
        if (singleOpportunity.Bdi != null) {
            opportunity.BDI__c = singleOpportunity.Bdi;
        }

        if (singleOpportunity.fullNameOfResponsible != null) {
            opportunity.NomeDoResponsavel__c = singleOpportunity.fullNameOfResponsible;
        }
        if (singleOpportunity.positionOfResponsible != null) {
            opportunity.CargoDoResponsavel__c = singleOpportunity.positionOfResponsible;
        }
        if (singleOpportunity.phoneOfResponsible != null) {
            opportunity.TelefoneDoResponsavel__c = singleOpportunity.phoneOfResponsible;
        }
        if (singleOpportunity.emailOfResponsible != null) {
            opportunity.EmailDoResponsavel__c = singleOpportunity.emailOfResponsible;
        }
        if (singleOpportunity.invoiceForLastTwoMonths != null) {
            opportunity.FaturaUltimosDoisMeses__c = singleOpportunity.invoiceForLastTwoMonths;
        }
        if (singleOpportunity.clientHasICMSIncentive != null) {
            opportunity.ClientePossuiCreditoIncentivoICMS__c = singleOpportunity.clientHasICMSIncentive;
        }
        if (singleOpportunity.specialSituation != null) {
            opportunity.SituacaoEspecial__c = singleOpportunity.specialSituation;
        }
        if (singleOpportunity.clientHasGenerator != null) {
            opportunity.ClienteTemGerador__c = singleOpportunity.clientHasGenerator;
        }
        if (singleOpportunity.generatedVolume != null) {
            opportunity.VolumeGerado__c = singleOpportunity.generatedVolume;
        }
        if (singleOpportunity.isPromotional != null) {
            opportunity.IsPromotional__c = singleOpportunity.isPromotional;
        }
        if (singleOpportunity.PartnerProposalId != null) {
            opportunity.ReferenceIdRevo__c = singleOpportunity.PartnerProposalId;
        }
        if (singleOpportunity.PartnerName != null) {
            opportunity.PartnerName__c = singleOpportunity.PartnerName;
        }
        if (singleOpportunity.observacoes != null) {
            opportunity.Observacoes__c = singleOpportunity.observacoes;
        }
        if (singleOpportunity.ConsumerUnit != null) {
            opportunity.UnidadeConsumidora__c = singleOpportunity.ConsumerUnit;
        }
        if (singleOpportunity.LastInvoiceAmount != null) {
            opportunity.LastInvoiceAmount__c = singleOpportunity.LastInvoiceAmount;
        }
        if (singleOpportunity.Partner != null) {
            opportunity.Parceiro__c = singleOpportunity.Partner;
        }
        if (singleOpportunity.Status != null) {
            opportunity.Status__c = singleOpportunity.Status;
        }
        if (singleOpportunity.SubTipo != null) {
            opportunity.SubTipo__c = singleOpportunity.SubTipo;
        }
        if (singleOpportunity.ProdutoSolar != null) {
            opportunity.ProdutoSolar__c = singleOpportunity.ProdutoSolar;
        }
        if (singleOpportunity.AppointmentDateTime != null) {
            opportunity.DataHoraAgendamento__c = singleOpportunity.AppointmentDateTime;
        }
        if(singleOpportunity.AccountId != null){
            opportunity.AccountId = singleOpportunity.AccountId;
        }
        if(singleOpportunity.PropostaRevo != null){
            opportunity.PropostaRevo__c = singleOpportunity.PropostaRevo;
        }
        if(singleOpportunity.LeadId != null){
            opportunity.Lead__c = singleOpportunity.LeadId;
        }
    }

    public static void mapOpportunityLineItemFieldsRest(
        Map<OpportunityRecordsTO.SingleOpportunity, Opportunity> restObjectsToInsertedOpportunity,
        Map<String, Id> externalIdToProductId
    ){
        List<OpportunityLineItem> itemsToInsert = new List<OpportunityLineItem>();

        // IDs das Oportunidades inseridas/atualizadas
        Set<Id> opportunityIds = new Set<Id>();

        // IDs Externos dos Clientes que já existem
        List<OpportunityRecordsTO.Product> newProducts = new List<OpportunityRecordsTO.Product>();

        // Iterar sobre produtos da Integração para capturar os que ainda não existem no Salesforce
        for(OpportunityRecordsTO.SingleOpportunity singleOpportunity : restObjectsToInsertedOpportunity.keySet()){
            for(OpportunityRecordsTO.Product product : singleOpportunity.Products){
                if(!externalIdToProductId.keySet().contains(String.valueOf(product.Id))){
                    newProducts.add(product);
                }
            }

            // Coletar os IDs para deletar os itens de Oportunidades já existentes e fazer nova inserção
            opportunityIds.add(restObjectsToInsertedOpportunity.get(singleOpportunity).Id);
        }

        if(!newProducts.isEmpty()){
            // Criar produtos novos
            List<Product2> productsToInsert = new List<Product2>();

            // ID externo do Produto -> Valor unitário
            Map<String, Double> productExternalIdToPrice = new Map<String, Double>();

            for(OpportunityRecordsTO.Product product : newProducts){
                productExternalIdToPrice.put(String.valueOf(product.Id), product.UnitaryValue);

                productsToInsert.add(new Product2(
                    Id_Externo__c     = product.Id,
                    ProductCode       = product.Id,
                    Preco_Unitario__c = product.UnitaryValue,
                    Name              = product.Name,
                    ExternalId__c     = product.Id
                ));
            }
            upsert productsToInsert Id_Externo__c;

            for(Product2 product : productsToInsert){
                externalIdToProductId.put(product.ProductCode, product.Id);
            }
        }

        // Deletar itens e kits existentes para fazer inserção dos valores atualizados
        List<OpportunityLineItem> itemsToDelete = [
            SELECT  Id
            FROM    OpportunityLineItem
            WHERE   OpportunityId IN :opportunityIds
        ];

        delete itemsToDelete;

        // ID da Oportunidade -> Lista de Kits de Instalação
        Map<Id, Kit_Instalacao__c> opportunityIdToKit = new Map<Id, Kit_Instalacao__c>();

        for(Kit_Instalacao__c existingKit : [
            SELECT  Id, Nome_da_Oportunidade__c
            FROM    Kit_Instalacao__c
            WHERE   Nome_da_Oportunidade__c IN :opportunityIds
        ]){
            opportunityIdToKit.put(existingKit.Nome_da_Oportunidade__c, existingKit);
        }

        // ID da Oportunidade -> Lista de Items
        Map<Id, List<OpportunityLineItem>> opportunityIdToItems = new Map<Id, List<OpportunityLineItem>>();

        // Iterar sobre todos os IDs das Oportunidades inseridas
        for(OpportunityRecordsTO.SingleOpportunity singleOpportunity : restObjectsToInsertedOpportunity.keySet()){

            // Pegar sobre todas as Oportunidades da integração para a Oportunidade inserida
            Id opportunityId = restObjectsToInsertedOpportunity.get(singleOpportunity).Id;
            opportunityIdToItems.put(opportunityId, new List<OpportunityLineItem>());

            // Iterar sobre os Produtos da Oportunidades recebidas da integração
            for(OpportunityRecordsTO.Product product : singleOpportunity.Products){
                String productExternalId = String.valueOf(product.Id);
                
                //Cria item
                OpportunityLineItem item = new OpportunityLineItem(
                    OpportunityId    = opportunityId,
                    Product2Id       = externalIdToProductId.get(productExternalId),
                    UnitPrice        = product.UnitaryValue,
                    Quantity         = product.Quantity,
                    Description		 = product.Description
                );
                    
                itemsToInsert.add(item);

                // Cria Kit
                if(!opportunityIdToKit.containsKey(opportunityId)){
                    opportunityIdToKit.put(opportunityId, new Kit_Instalacao__c(
                        Nome_da_Oportunidade__c = opportunityId
                    ));
                }

                // Popula Map de Oportunidade e Itens
                opportunityIdToItems.get(opportunityId).add(item);
            }
        }

        upsert opportunityIdToKit.values();
        
        // Associar Kits aos Itens
        for(Id opportunityId : opportunityIdToItems.keySet()){
            List<OpportunityLineItem> itemList = opportunityIdToItems.get(opportunityId);
            Kit_Instalacao__c kit = opportunityIdToKit.get(opportunityId);

            for(OpportunityLineItem item : itemList){
                item.Kit_Instalacao__c = kit.Id;
            }
        }

        insert itemsToInsert;
    }

    public static Map<String, Account> mapAccountFieldsRest(
        Map<String, OpportunityRecordsTO.Client> externalCustomerIdsToCustomersRest,
        Map<String, OpportunityRecordsTO.Client> externalCustomerIdsCPFToCustomersRest){
        // IDs dos tipos de registro de Conta
        Id physicalPersonId =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('ClientePessoaFisica').getRecordTypeId();

        Id legalPersonId =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('ClientePessoaJuridica').getRecordTypeId();

        // ID Externo -> Contas Novas e Antigas
        Map<String, Account> accountsByExternalId = new Map<String, Account>();

        // IDs Externos dos Clientes
        Set<String> customerExternalIds = new Set<String>();

        // IDs Externos dos Clientes que já existem
        Set<String> existingCustomerExternalIds = new Set<String>();

        // ID Externo do Cliente -> ID do Cliente
        Map<String, Id> externalIdToCustomerId = new Map<String, Id>();
        
        // Lista de Contatos para inserir de client no caso de PJ
        List<Contact> contatosList = new List<Contact>();
        
        //Emails dos contatos sendo inseridos
        Set<String> customerEmail = new Set<String>();
        
        // Map de Contato por Email
        Map<String, Contact> ContactsByExternalId = new Map<String, Contact>();
        
        // Contas que já existem
        for(Account account : [
            SELECT  Id, IdVirtualOffice__c
            FROM    Account
            WHERE   IdVirtualOffice__c IN :externalCustomerIdsToCustomersRest.keySet()
        ]){
            OpportunityRecordsTO.Client client = externalCustomerIdsToCustomersRest.get(account.IdVirtualOffice__c);

            existingCustomerExternalIds.add(account.IdVirtualOffice__c);
            String cleanedEmail = removeAccents(client.Email);

            account.TipoUsuario__c              = client.UserType;
            account.RazaoSocial__c              = client.CorporateName;
            account.Email__c                    = cleanedEmail;
            account.Phone                       = client.CellPhone;
            account.DataRegistro__c             = DateTime.valueOf(client.RegisterDate.replace('T', ' '));
            account.DataModificacao__c          = DateTime.valueOf(client.ModifiedDate.replace('T', ' '));
            account.Procurador__c               = client.Procurator;
            account.TelefoneProcurador__c       = client.ProcuratorPhone;
            account.EmailProcurador__c          = client.ProcuratorEmail;
            account.NumeroRegistroProcurador__c = client.ProcuratorRegisterNumber;
            account.RecordTypeId                = client.RecordTypeId;
            account.BillingCity                 = client.BillingCity;
            account.BillingStreet               = client.BillingStreet;
            account.BillingCountry              = client.BillingCountry;
            account.BillingState                = client.BillingState;
            account.BillingPostalCode           = returnFormattedPostalCode(client.BillingPostalCode);
            account.ShippingCity                = client.BillingCity;
            account.ShippingStreet              = client.BillingStreet;
            account.ShippingCountry             = client.BillingCountry;
            account.AccountSource 				= 'Nivello';
            account.AccountNumber				= client.AccountNumber;
            account.ShippingState               = client.BillingState;
            account.ShippingPostalCode          = returnFormattedPostalCode(client.BillingPostalCode);
            account.Complemento__c              = client.Complemento;

            if(account.RecordTypeId == physicalPersonId){
                    account.Name = client.FullName;
                    account.CPF__c = returnFormattedDocument(true, client.Document);
                } else if(account.RecordTypeId == legalPersonId) {
                    customerEmail.add(client.ProcuratorEmail);
                    account.Name = client.CorporateName;
                    account.CNPJ__c = returnFormattedDocument(false, client.Document);
            }

            accountsByExternalId.put(account.IdVirtualOffice__c, account);
        }

        // Contas a criar
        for(OpportunityRecordsTO.Client client : externalCustomerIdsToCustomersRest.values()){
            if(!existingCustomerExternalIds.contains(client.Id)){
                String cleanedEmail = removeAccents(client.Email);

                Account account = new Account(
                    IdVirtualOffice__c          = client.Id,
                    TipoUsuario__c              = client.UserType,
                   // Name                        = client.CorporateName,    // nome será sempre o da empresa para PJ então será preenchido com a validação do tipo do cliente abaixo,
                    RazaoSocial__c              = client.CorporateName,
                    Email__c                    = cleanedEmail,
                    Phone                       = client.CellPhone,
                    DataRegistro__c             = Date.valueOf(client.RegisterDate),
                    DataModificacao__c          = Date.valueOf(client.ModifiedDate),
                    Procurador__c               = client.Procurator,
                    TelefoneProcurador__c       = client.ProcuratorPhone,
                    EmailProcurador__c          = client.ProcuratorEmail,
                    NumeroRegistroProcurador__c = client.ProcuratorRegisterNumber,
                    RecordTypeId                = client.RecordTypeId,
                    BillingCity                 = client.BillingCity,
                    BillingStreet               = client.BillingStreet,
                    BillingCountry              = client.BillingCountry,
                    BillingState                = client.BillingState,
                    ShippingCity                = client.BillingCity,
                    ShippingStreet              = client.BillingStreet,
                    NumeroRuaEntrega__c         = client.AddressNumber,
                    NumeroRuaCobranca__c        = client.AddressNumber,
                    BairroCobranca__c           = client.District,
                    BairroEntrega__c            = client.District,
                    ShippingCountry             = client.BillingCountry,
                    AccountSource 		 		= 'Nivello',
            		AccountNumber				= client.AccountNumber,
                    ShippingState               = client.BillingState,
                    ShippingPostalCode          = returnFormattedPostalCode(client.BillingPostalCode),
                    BillingPostalCode           = returnFormattedPostalCode(client.BillingPostalCode),
                    Complemento__c              = client.Complemento
                );

                if(account.RecordTypeId == physicalPersonId){
                    account.Name = client.FullName != null ? client.FullName : client.Name ;
                    account.CPF__c = returnFormattedDocument(true, client.Document);
                } else {
                    account.Name = client.CorporateName;
                    account.CNPJ__c = returnFormattedDocument(false, client.Document);
                    
                    customerEmail.add(client.ProcuratorEmail);
                    
                }

                accountsByExternalId.put(account.IdVirtualOffice__c, account);
            }
        }
        
		
        upsert accountsByExternalId.values();
        
        //Criacao do contato
        for(Contact ct: [SELECT Id, Email FROM Contact WHERE Email IN :customerEmail]){
             ContactsByExternalId.put(ct.Email, ct);
        }
        /* 
        //varre lista da api pra criação de contato
        for(OpportunityRecordsTO.Client client : externalCustomerIdsToCustomersRest.values()){
            String email = client.ProcuratorEmail;
            
            if(client.RecordTypeId <> physicalPersonId ){

                if(client.Procurator != null){
                   Contact ctt = new Contact(
                            FirstName = client.Procurator.Substring(0,client.Procurator.indexOf(' ')),
                            LastName = client.Procurator.Substring(client.Procurator.indexOf(' '),client.Procurator.length()),
                            Email = client.ProcuratorEmail,
                            Phone = client.ProcuratorPhone,
                            AccountId = accountsByExternalId.get(client.Id).Id
                        );
                       if(ContactsByExternalId.containsKey(email)){
                           ctt.Id = ContactsByExternalId.get(email).Id;
                       }
                    contatosList.add(ctt); 
                }else{
                   Contact ctt = new Contact(
                            FirstName = client.CorporateName,
                            LastName = '.',
                            Email = client.Email,
                            Phone = client.CellPhone,
                            AccountId = accountsByExternalId.get(client.Id).Id
                        );
                       if(ContactsByExternalId.containsKey(email)){
                           ctt.Id = ContactsByExternalId.get(email).Id;
                       }
                    contatosList.add(ctt);  
                }
                     
                
            }
        }*/
        
        if(contatosList != null){
            Database.upsert(contatosList);
        }
        
        
        return accountsByExternalId;
    }

    public static String returnFormattedDocument(Boolean isPhysicalPerson, String document){
        
        // Map Ascii Code -> Caracter
        Map<Integer, String> asciiValuesMap = new Map<Integer, String>{
            48 => '0',
            49 => '1',
            50 => '2',
            51 => '3',
            52 => '4',
            53 => '5',
            54 => '6',
            55 => '7',
            56 => '8',
            57 => '9'
        };

        if(isPhysicalPerson){
            return
                asciiValuesMap.get(document.charAt(0)) + asciiValuesMap.get(document.charAt(1)) + asciiValuesMap.get(document.charAt(2)) + '.' +
                asciiValuesMap.get(document.charAt(3)) + asciiValuesMap.get(document.charAt(4)) + asciiValuesMap.get(document.charAt(5)) + '.' +
                asciiValuesMap.get(document.charAt(6)) + asciiValuesMap.get(document.charAt(7)) + asciiValuesMap.get(document.charAt(8)) + '-' +
                asciiValuesMap.get(document.charAt(9)) + asciiValuesMap.get(document.charAt(10));}

        return
            asciiValuesMap.get(document.charAt(0)) + asciiValuesMap.get(document.charAt(1)) + '.' +
            asciiValuesMap.get(document.charAt(2)) + asciiValuesMap.get(document.charAt(3)) + asciiValuesMap.get(document.charAt(4)) + '.' +
            asciiValuesMap.get(document.charAt(5)) + asciiValuesMap.get(document.charAt(6)) + asciiValuesMap.get(document.charAt(7)) + '/' +
            asciiValuesMap.get(document.charAt(8)) + asciiValuesMap.get(document.charAt(9)) + asciiValuesMap.get(document.charAt(10)) + asciiValuesMap.get(document.charAt(11)) + '-' +
            asciiValuesMap.get(document.charAt(12)) + asciiValuesMap.get(document.charAt(13));
    }

    public static String returnFormattedPostalCode(String postalCode){
        
        // Map Ascii Code -> Caracter
        Map<Integer, String> asciiValuesMap = new Map<Integer, String>{
            48 => '0',
            49 => '1',
            50 => '2',
            51 => '3',
            52 => '4',
            53 => '5',
            54 => '6',
            55 => '7',
            56 => '8',
            57 => '9'
        };

        return
            asciiValuesMap.get(postalCode.charAt(0)) + asciiValuesMap.get(postalCode.charAt(1)) + asciiValuesMap.get(postalCode.charAt(2)) + 
            asciiValuesMap.get(postalCode.charAt(3)) + asciiValuesMap.get(postalCode.charAt(4)) + '-' +
            asciiValuesMap.get(postalCode.charAt(5)) + asciiValuesMap.get(postalCode.charAt(6)) + asciiValuesMap.get(postalCode.charAt(7));
    }

    public static void resetReadjustmentFieldsOnStatusChanging(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecordsMap){
        for(Opportunity opp : newRecords){
            Opportunity oldOpp = oldRecordsMap.get(opp.id);
            if(
                OpportunityUtils.isStatusChanging(opp, oldOpp) &&
                (OpportunityUtils.isStatusProposalElaboration(oldOpp) ||
                OpportunityUtils.isStatusProposalSimulation(oldOpp) ) &&
                opp.ReadequacaoSolicitada__c
            ){
                opp.ReadequacaoSolicitada__c = false;
            }
        }
    }   

    public static void createReadjustmentTask(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecordsMap){
        
        List<User> integration = [
            SELECT Id FROM User WHERE Username = 'integracao@lab065.com' AND IsActive = true
            LIMIT 1
        ];

        Id integrationUserId = integration.isEmpty() ? null : integration[0].Id;

        List<Task> tasksToInsert = new List<Task>();
        for(Opportunity opp : newRecords){
            Opportunity oldOpp = oldRecordsMap.get(opp.id);
            
            if(opp.OwnerId == integrationUserId) { continue; }

            if(OpportunityUtils.isOpportunityBeingRequiredReadjustment(opp, oldOpp)){
                tasksToInsert.add(TaskBO.createTask(
                    opp.Id, 
                    'Verificar a readequação solicitada para a proposta',
                    'Foi solicitada uma readequação para esta proposta. Favor verificar e validar.',
                    opp.OwnerId,
                    TaskBO.getActivityDateBasedOnWorkingDays(System.today(), 3),
                    '3'
                ));
            }
        }
        insert tasksToInsert;
    }

    public static void validateContractStatusChanging(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecordsMap){
        User runningUser = [
            SELECT  Id, Name, Profile.Name
            FROM    User
            WHERE   Id =: UserInfo.getUserId()
        ];
        String[] allowedProfiles = new String[]{
            'Administrador',
            'Administrador API',
            'Administrador do sistema', 
            'System Administrator'
        };
        for(Opportunity opp : newRecords){
            Opportunity oldOpp = oldRecordsMap.get(opp.Id);
            if(
                OpportunityUtils.isStatusChanging(opp, oldOpp) && 
                (
                    OpportunityUtils.isSubStatusContractSent(opp) ||
                    OpportunityUtils.isSubStatusContractFirmedSigned(opp)
                ) &&
                !allowedProfiles.contains(runningUser.Profile.Name)
            ){
                opp.addError('Essa alteração de status não pode ser feita de forma manual!');
            }
        }
    }
    
    public static Map<String, Id> getOpportunitiesSellers(Set<String> sellerIds){
        Map<String, Id> sellerIdsByExternalIds = new Map<String, Id>();
        for(Consultor__c seller : [
            SELECT  Id, IdVirtualOffice__c
            FROM    Consultor__c
            WHERE   IdVirtualOffice__c IN :sellerIds
        ]){
            sellerIdsByExternalIds.put(seller.IdVirtualOffice__c, seller.Id);
        }
        return sellerIdsByExternalIds;
    }

    public static void assignDefaultOwner(List<Opportunity> newRecords){
        Id nivelloUserId = [
            SELECT  Id
            FROM    User
            WHERE   UserName like 'integracao@lab065.com%'
            LIMIT   1
        ].Id;

        Boolean isThereNivelloOpportunity = false;
        for(Opportunity opportunity : newRecords){
            if(opportunity.OwnerId == nivelloUserId){
                isThereNivelloOpportunity = true;
                break;
            }
        }

        if(isThereNivelloOpportunity){
            Id defaultUserId = [
                SELECT  Id
                FROM    User
                WHERE   UserName LIKE 'integracao@lab065.com%'
                LIMIT   1
            ].Id;

            for(Opportunity opportunity : newRecords){
                if(opportunity.OwnerId == nivelloUserId){
                    opportunity.OwnerId = defaultUserId;
                    opportunity.Origem__c = 'Nivello';
                }
            }
        }
    }


    public static void assignOwnerByPartner(List<Opportunity> newRecords){
        // Coleta os Ids dos Parceiros das oportunidades
        Set<Id> parceiroIds = new Set<Id>();
        for(Opportunity opportunity : newRecords){
            if(opportunity.Parceiro__c != null){
            parceiroIds.add(opportunity.Parceiro__c);
            }
        }

        // Busca os Parceiros e seus OwnerOpportunity__c
        Map<Id, Parceiro__c> parceirosMap = new Map<Id, Parceiro__c>();
        if(!parceiroIds.isEmpty()){
            for(Parceiro__c parceiro : [
            SELECT Id, OwnerOpportunity__c
            FROM Parceiro__c
            WHERE Id IN :parceiroIds
            ]){
            parceirosMap.put(parceiro.Id, parceiro);
            }
        }

        // Atualiza o OwnerId das oportunidades conforme o OwnerOpportunity__c do Parceiro
        for(Opportunity opportunity : newRecords){
            if(opportunity.Parceiro__c != null && parceirosMap.containsKey(opportunity.Parceiro__c)){
            Id ownerId = parceirosMap.get(opportunity.Parceiro__c).OwnerOpportunity__c;
            if(ownerId != null){
                opportunity.OwnerId = ownerId;
            }
            }
        }
    }

    public static void sendEmailToOwnerNivello(List<Opportunity> newRecords){
        Set<Id> ownerIds = new Set<Id>();
        for(Opportunity opportunity : newRecords){
            if(opportunity.Origem__c == 'Nivello'){
                ownerIds.add(opportunity.OwnerId);
            }
        }
        // Only send email in Production (not in sandbox or test)
        Boolean orgType = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        if(!ownerIds.isEmpty() && !Test.isRunningTest() && !orgType){

            List<Messaging.SingleEmailMessage> messageList = new List<Messaging.SingleEmailMessage>();
            for(Opportunity opportunity : newRecords){
            Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
            message.setHtmlBody(
                'Olá! Uma nova oportunidade foi gerada no Salesforce a partir do gerenciador ' +
                'de oportunidades. Favor realizar a atribuição de um novo proprietário assim que possível. ' + 
                'Clique no link abaixo para conferir.<br><br>' +
                (URL.getSalesforceBaseUrl().toExternalForm() + '/' + opportunity.Id)
            );
            message.setToAddresses(new String[]{'comercial@enerzee.com.br'});
            message.setSubject('Uma nova oportunidade foi criada');

            messageList.add(message);
            }

            Messaging.SendEmailResult[] results = Messaging.sendEmail(messageList);
        }
    }


    public static void makeVirtualOfficeCalloutByStatusChange(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecordsMap){
        System.debug('newRecords ' + newRecords);
        /*
            1 -> Gerando Proposta
            2 -> Etapa Viabilidade
            3 -> Enviar Data de Visita Técnica
            4 -> Enviar Análise da Visita Técnica
            5 -> Conclusão Viabilidade
            6 -> Pagamento
            7 -> Finalização Proposta
        */
        Map<Integer, Set<Id>> endpointIdToContextIds = new Map<Integer, Set<Id>>();
        Set<Id> opportunityIds = new Set<Id>();
        
        for(Opportunity opportunity : newRecords){
            Opportunity oldOpportunity = oldRecordsMap.get(opportunity.Id);

            if(
                OpportunityUtils.isStatusChanging(opportunity, oldOpportunity)
            )
            // {
            //     if(
            //         (
            //              OpportunityUtils.isStatusProposalGenerated(opportunity) ||
            //              OpportunityUtils.isStatusProposalSent(opportunity)
            //          )
            //          ||
            //          (
            //              OpportunityUtils.isStatusAwaitingAcceptance(opportunity)
            //              && OpportunityUtils.hasProposalReadjustment(opportunity)
            //          )
            //      ){
            //          createAddContextIdToEndpointMap(endpointIdToContextIds, 1, opportunity.Id);
            //      }
            // }
            if(
                OpportunityUtils.isRecordTypeSolar(opportunity)
            ) {
                
                /*
                    1 - GERANDO PROPOSTA
                    Enviar PDF da Proposta após geração no Salesforce
                */

                /*
                    2 - ETAPA VIABILIDADE
                    Enviar atualização da etapa de viabilidade a cada mudança
                */
                if(OpportunityUtils.isViabilityStepChanging(opportunity, oldOpportunity) || OpportunityUtils.isChangingToViabilityAnalysis(opportunity, oldOpportunity)){
                    createAddContextIdToEndpointMap(endpointIdToContextIds, 2, opportunity.Id);
                }


                /*  
                    3 - ENVIAR DATA DA VISITA TÉCNICA
                    Enviar valor do prazo de aprovação da viabilidade quando for preenchido
                */
                if(OpportunityUtils.isViabilityDeadlineBeingAssigned(opportunity, oldOpportunity)){
                    createAddContextIdToEndpointMap(endpointIdToContextIds, 3, opportunity.Id);
                    //continue;
                }


                /*  
                    4 - ENVIAR ANÁLISE DA VISITA TÉCNICA
                Enviar status da análise da visita vécnica quando for preenchido
                */
                if(OpportunityUtils.isViabilityStatusBeingAssigned(opportunity, oldOpportunity)){
                    createAddContextIdToEndpointMap(endpointIdToContextIds, 4, opportunity.Id);
                    //continue;
                }


                /*
                    5 - CONCLUSÃO VIABILIDADE
                    Enviar atualização de fim da viabilidade ao chegar no último status
                */
                if(OpportunityUtils.isViabilityAnalysisOver(opportunity, oldOpportunity)){
                    createAddContextIdToEndpointMap(endpointIdToContextIds, 5, opportunity.Id);

                    //continue;
                }

                /*
                    6 - PAGAMENTO
                    Enviar atualização quando status for modificado para o de pagamento
                */
                /*
                if(OpportunityUtils.isChangingToPaymentWay(opportunity, oldOpportunity)){
                    createAddContextIdToEndpointMap(endpointIdToContextIds, 6, opportunity.Id);
                    continue;
                }
                */

                /* 
                    7 - CONTRATO
                    Enviar atualização quando contrato for fechado
                */

                if(OpportunityUtils.isSubStatusContractGenerating(opportunity)){
                    opportunityIds.add(opportunity.Id);
                    //continue;
                }
                
                if(OpportunityUtils.isSubStatusContractSent(opportunity)){
                    opportunityIds.add(opportunity.Id);
                    //continue;
                }

                if(OpportunityUtils.isSubStatusContractFirmedSigned(opportunity)){
                    createAddContextIdToEndpointMap(endpointIdToContextIds, 7, opportunity.Id);
                    //continue;
                }

                /* 
                    8 - FINALIZAÇÃO PROPOSTA
                    Enviar atualização quando oportunidade for fechada como ganha
                */

                if(OpportunityUtils.isChangingToClosedWon(opportunity, oldOpportunity)){
                    createAddContextIdToEndpointMap(endpointIdToContextIds, 8, opportunity.Id);
                    //continue;
                }

                if(
                    (OpportunityUtils.isStatusProposalElaboration(opportunity) ||
                    OpportunityUtils.isStatusProposalSimulation(opportunity) ) &&
                    (
                        (
                            (
                                OpportunityUtils.isSubTypeMiniContract(opportunity) ||
                                OpportunityUtils.isRecordTypeOtherOpportunities(opportunity)
                            )
                        ) || 
                            !OpportunityUtils.isSubTypeMiniContract(opportunity)
                    )
                ){
                    opportunityIds.add(opportunity.Id);
                    //continue;
                }

                if(OpportunityUtils.isStatusAwaitingAcceptance(opportunity)){
                    opportunityIds.add(opportunity.Id);
                    //continue;
                }

                if(OpportunityUtils.isSubStatusTechnicalVisitScheduling(opportunity)){
                    opportunityIds.add(opportunity.Id);
                    //continue;
                }
            }

            if(
                OpportunityUtils.isStatusProposalElaboration(opportunity)
                || OpportunityUtils.isStatusProposalSimulation(opportunity)
                || (oldOpportunity.StageName != opportunity.StageName)
                || (oldOpportunity.Status__c != opportunity.Status__c && opportunity.Status__c != null)
                || (oldOpportunity.DataHoraAgendamento__c != opportunity.DataHoraAgendamento__c && opportunity.DataHoraAgendamento__c != null)
            ){
                opportunityIds.add(opportunity.Id);
            }
            System.debug('opportunityIds ' + opportunity.RecordTypeId);
        }
        // Chamar ProposalService para as oportunidades que não são Contrato Mini, Micro e Outras Oportunidades
        if (!opportunityIds.isEmpty()) {
            ProposalService.updateOpportunityPhase(opportunityIds);
        }

        for(Integer endpointId : endpointIdToContextIds.keySet()){
            if(endpointId == 1 && endpointIdToContextIds.get(1) != null){
                
                for(Id oppId : endpointIdToContextIds.get(1)){
                    IntegracaoNivelloProposta.gerandoProposta(oppId);
                }
                
                continue;
            }

            // if(endpointId == 9 && endpointIdToContextIds.get(9) != null){
            //     IntegracaoNivelloAprovacaoDesconto.enviarStatusAprovacaoDesconto(endpointIdToContextIds.get(9));
            //     continue;
            // }

            if(endpointId == 2 && endpointIdToContextIds.get(2) != null){
                IntegracaoNivelloViabilidade.etapaViabilidade(endpointIdToContextIds.get(2));
                continue;
            }
            
            if(endpointId == 3 && endpointIdToContextIds.get(3) != null){
                IntegracaoNivelloDataVisitaTecnica.sendTechnicalVisitDate(endpointIdToContextIds.get(3), false);
                continue;
            }

            if(endpointId == 4 && endpointIdToContextIds.get(4) != null){
                IntegracaoNivelloAnaliseVisitaTecnica.sendTechnicalVisitAnalysis(endpointIdToContextIds.get(4));
                continue;
            }

            if(endpointId == 5 && endpointIdToContextIds.get(5) != null){
                IntegracaoNivelloViabilidade.conclusaoViabilidade(endpointIdToContextIds.get(5));
                continue;
            }

            // if(endpointId == 6 && endpointIdToContextIds.get(6) != null){
            //     IntegracaoNivelloPagamento.pagamento(endpointIdToContextIds.get(6));
            //     continue;
            // }

            if(endpointId == 7 && endpointIdToContextIds.get(7) != null){
                IntegracaoNivelloContrato.enviarContrato(endpointIdToContextIds.get(7));
                continue;
            }

            if(endpointId == 8 && endpointIdToContextIds.get(8) != null){
                IntegracaoNivelloProposta.finalizacaoProposta(endpointIdToContextIds.get(8));
                continue;
            }

        }
    }

    public static void createAddContextIdToEndpointMap(Map<Integer, Set<Id>> endpointIdToContextIds, Integer key, Id opportunityId){
        if(!endpointIdToContextIds.containsKey(key)){
            endpointIdToContextIds.put(key, new Set<Id>());
        }
        endpointIdToContextIds.get(key).add(opportunityId);
    }

    //Envia contratos (PDF) vinculados à Oportunidades se (e somente se) eles foram aprovados
    public static void sendContractToExternalSystem(List<Opportunity> triggerlist, Map<Id, Opportunity> oldMap){

        Set<Id> oppIds = new Set<Id>();
        
        for(Opportunity opp : triggerList){

            if(opp.Contrato_aprovado__c && opp.Contrato_aprovado__c != oldMap.get(opp.Id).Contrato_aprovado__c){
                oppIds.add(opp.Id);
            }
        }

        if(!oppIds.isEmpty()){
            IntegracaoNivelloContrato.enviarContrato(oppIds);
        }
    }

    public static void updateFinancingProcessSimulationInExternalSystem(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecordsMap){
        
        Set<Id> oppIds = new Set<Id>();

        for (Opportunity newOpp : newRecords) {
            Opportunity oldOpportunity = oldRecordsMap.get(newOpp.Id);
            
            // Condição simplificada para verificar se o registro deve ser processado
            if (shouldProcess(newOpp, oldOpportunity)) {
                oppIds.add(newOpp.Id);
            }
        }

        if(!oppIds.isEmpty()){
            IntegracaoNivelloSimulacaoFinanciamento.updateFinancingSimulation(oppIds);
        }
    }

    private static Boolean shouldProcess(Opportunity newOpp, Opportunity oldOpp) {
        return newOpp.financingProcessDetails__c != oldOpp.financingProcessDetails__c
               && !String.isBlank(newOpp.financingProcessDetails__c);
    }

    public static void setContractSendingDate(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecordsMap){
        for(Opportunity opportunity : newRecords){
            if(
                OpportunityUtils.isSubStatusContractSent(opportunity) &&
                !OpportunityUtils.isSubStatusContractSent(oldRecordsMap.get(opportunity.Id))
            ){
                opportunity.DataEnvioContrato__c = System.today();
            }
        }
    }

    public static void createProjectRecords(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecordsMap){
        List<Projeto__c> projectsToInsert = new List<Projeto__c>();

        set<id> OpportunitySetIds = new set<id>();
        for(Opportunity opp :newRecords){
            OpportunitySetIds.add(opp.Id);
        }

        // Evitar criar projetos duplicados via trigger; se já existe projeto para a oportunidade, não cria outro
        // Exceção: se Categoria = Fast Track, permitimos criar um projeto (e instalação) sempre que o fluxo for acionado
        Set<Id> opportunitiesWithProject = new Set<Id>();
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>(newRecords);
        for (Projeto__c existingProject : [
            SELECT Oportunidade__c
            FROM   Projeto__c
            WHERE  Oportunidade__c IN :OpportunitySetIds
        ]) {
            Opportunity opp = oppMap.get(existingProject.Oportunidade__c);
            if (opp != null && 'Fast Track'.equalsIgnoreCase(opp.Categoria__c)) {
                continue;
            }
            if (existingProject.Oportunidade__c != null) {
                opportunitiesWithProject.add(existingProject.Oportunidade__c);
            }
        }

        Map<String, String> statusByRecordType = new Map<String, String>{
            'Bombeamento'               => 'STATUS_PLANEJAMENTO',
            'Estação de Recarga'        => 'STATUS_PLANEJAMENTO',
            'Subestação'                => 'STATUS_PLANEJAMENTO_DE_PROJETO',
            'Padrão de Entradao'        => 'STATUS_PLANEJAMENTO',
            'UFV Mini acima de 300'     => 'STATUS_PLANEJAMENTO_DE_PROJETO',
            'UFV Mini até 300'          => 'STATUS_PLANEJAMENTO_DE_PROJETO',
            'UFV Micro'                 => 'STATUS_PLANEJAMENTO_DE_PROJETO'
        };


        Map<String,ViabilityStudy__c> viabilityMap = new Map<String,ViabilityStudy__c>();
        for(ViabilityStudy__c viability : [SELECT ID,Opportunity__c,TypeWorkProjectFeasibility__c FROM viabilityStudy__c where Opportunity__c in :OpportunitySetIds]){
            viabilityMap.put(viability.Opportunity__c,viability);
        }
        for(Opportunity opportunity : newRecords){
            Opportunity oldOpportunity = oldRecordsMap.get(opportunity.Id);
            if(viabilityMap.get(opportunity.Id) == null){
                return;
            }
            if (opportunitiesWithProject.contains(opportunity.Id)) {
                continue;
            }
            if(
                (
                    OpportunityUtils.isRecordTypeEzeeSolar(opportunity) ||
                    OpportunityUtils.isRecordTypeSolar(opportunity) ||
                    (OpportunityUtils.isRecordTypeProdutos(opportunity) && OpportunityUtils.isWithSolarProduct(opportunity))
                ) &&
                (
                    OpportunityUtils.isStatusChanging(opportunity, oldOpportunity) &&
                    OpportunityUtils.isStatusAccessOpinion(opportunity)
                ) &&
                (
                    viabilityMap.get(opportunity.Id).TypeWorkProjectFeasibility__c != null
                )
            ){
                for(String workProjectType : viabilityMap?.get(opportunity.Id).TypeWorkProjectFeasibility__c.split(';')){
                    RecordTypeInfo projectRecordTypeInfo = Schema.SObjectType.Projeto__c.getRecordTypeInfosByName().get(workProjectType);

                    if(workProjectType.contains('Financiamento')){
                        projectRecordTypeInfo = Schema.SObjectType.Projeto__c.getRecordTypeInfosByName().get('Financiamento');
                    }

                    if(projectRecordTypeInfo != null){
                        String projectNameConcatenate =
                            workProjectType.contains('Financiamento') ?
                            'Financiamento' : workProjectType;

                        projectsToInsert.add(new Projeto__c(
                            Name                = opportunity.Name + ' - ' + projectNameConcatenate,
                            Status__c           = statusByRecordType.get(workProjectType) == 'STATUS_PLANEJAMENTO_DE_PROJETO' ? ProjetoUtils.STATUS_PLANEJAMENTO_DE_PROJETO : ProjetoUtils.STATUS_PLANEJAMENTO,
                            Oportunidade__c     = opportunity.Id,
                            Concessionaria__c   = opportunity.ConcessionariaEnergia__c,
                            UFConcessionaria__c = opportunity.UF_Concessionaria__c,
                            Consultor__c        = opportunity.ConsultorOportunidade__c,
                            Conta__c            = opportunity.AccountId,
                            Categoria__c        = opportunity.Categoria__c,
                            PotenciaSistema__c  = String.valueOf(opportunity.PotenciaPicoSistema__c),
                            recordTypeId        = projectRecordTypeInfo.getRecordTypeId()
                        ));
                    }
                }
            }
        }
        insert projectsToInsert;
        if(!projectsToInsert.isEmpty()){
            Map<Id, Opportunity> opportunityById = new Map<Id, Opportunity>();
            for(Opportunity opp : newRecords){
                opportunityById.put(opp.Id, opp);
            }
            InstalacaoBO.createInstallationsForFastTrackProjects(projectsToInsert, opportunityById);
        }
    }

    public static void changeOpportunityStageOnViabilityChanging(List<Opportunity> newList, Map<Id, Opportunity> oldMap){
        for(Opportunity opportunity : newList){
           //if(OpportunityUtils.isViabilityStatusChanging(opportunity, oldMap.get(opportunity.Id))){
            //    opportunity.StageName = OpportunityUtils.STATUS_FECHADO_PERDIDO;
            //    continue;
            //}
            
            if( OpportunityUtils.isViabilityStatusChanging(opportunity, oldMap.get(opportunity.Id)) &&
                OpportunityUtils.isStatusViabilityAnalysis(opportunity)){
                //if(OpportunityUtils.isOpportunityPartiallyViable(opportunity) ){
                    //if(OpportunityUtils.isOpportunityBeingRequiredReadjustment(opportunity,oldMap.get(opportunity.Id))){
                    //    opportunity.StageName = OpportunityUtils.STATUS_READEQUACAO_DE_PROPOSTA;
                    //    continue;
                    //}
                //}

                if(OpportunityUtils.isOpportunityViable(opportunity)){
                    opportunity.Status__c = OpportunityUtils.SUB_STATUS_GERACAO_CONTRATO;
                    continue;
                }

                if(OpportunityUtils.isOpportunityNotViable(opportunity)){
                    opportunity.Status__c = OpportunityUtils.SUB_STATUS_PERDIDO;
                    continue;
                }
            }
            
        }
    }
    
    public static void createRequiredFieldsReminderTasks(List<Opportunity> newList, Map<Id, Opportunity> oldMap){
        Map<Integer, User> taskNumberToOwnerUser = new Map<Integer, User>{
            1 => null, 2 => null, 3 => null, 4 => null, 5 => null, 6 => null, 7 => null
        };
        
        List<User> integration = [
            SELECT Id FROM User WHERE Username = 'integracao@lab065.com' AND isActive = true
            LIMIT 1
        ];

        Id integrationUserId = integration.isEmpty() ? null : integration[0].Id;

        Id financeiroQueue = [SELECT Id FROM User WHERE Email LIKE 'dayane.silva@enerzee.com.br%' LIMIT 1].Id;

        Map<Id, String> opportunityIdToAccountName = new Map<Id, String>();
        Map<Id, Account> accountSet = new Map<Id, Account>([
            SELECT  Id, Name
            FROM    Account
            WHERE   Id IN :Collection.of(newList).pluckNotNullStrings(Opportunity.AccountId)
        ]);

        for(Opportunity opportunity : newList){
            if(opportunity.AccountId != null){
                opportunityIdToAccountName.put(opportunity.Id, accountSet.get(opportunity.AccountId).Name);
            }
        }

        List<Task> taskstoInsert = new List<Task>();
        for(Opportunity opportunity : newList){
            
            if(opportunity.OwnerId == integrationUserId) { continue; }
            
            String accountName = opportunityIdToAccountName.get(opportunity.Id);
            if(OpportunityUtils.isStatusChanging(opportunity, oldMap.get(opportunity.Id))){

                Boolean isOwnerUserActive = [SELECT IsActive FROM User WHERE Id = :opportunity.OwnerId LIMIT 1].IsActive;
                
                //  ELABORAÇÃO DA PROPOSTA
                if((OpportunityUtils.isStatusProposalElaboration(opportunity) || OpportunityUtils.isStatusProposalSimulation(opportunity)) && opportunity.GrupoTarifario__c != null){

                    //  GRUPO A
                    if(opportunity.GrupoTarifario__c.equalsIgnoreCase('Grupo A')){
                        // if(taskNumberToOwnerUser.get(1) == null){
                        //     taskNumberToOwnerUser.put(1, [
                        //         SELECT Id FROM User WHERE Email LIKE 'amanda@enerzee.com.br%' LIMIT 1
                        //     ]);
                        // }
                        taskstoInsert.add(TaskBO.createTask(
                            opportunity.Id,

                            'Informe os dados da proposta - Grupo A - ' + accountName,

                            'PREENCHER OS CAMPOS:\n\n Modalidade de Venda\n Tipo da venda\n ' +
                            'Enquadramento da GD\n Grupo Tarifário\n Sub-Grupo Tarifário\n ' +
                            'Tipo do telhado - Estrutura de fixação\n Logradouro\n ' +
                            'Município Instalação\n Consumo Anual\n ' +
                            'Custo Médio Mensal de Energia\n Prazo de Entrega (Dias)\n ' +
                            'Validade da proposta (dias)\n Demanda Contratada - Fora Ponta\n ' +
                            'Tarifa Demanda - Fora Ponta\n Consumo Médio - Fora Ponta\n ' +
                            'Tarifa - Fora Ponta\n Consumo Médio - Ponta\n Tarifa - Ponta\n ' +
                            'Tensão de Alimentação\n Potência Pico do Sistema (kWp)\n ' +
                            'Geração mensal estimada\n Geração anual estimada\n ' +
                            'Número de Módulos\n Potência Nominal do Módulo\n Fabricante Módulos\n ' +
                            'Modelo Módulos\n Número de Inversores\n Fabricante Inversor\n ' +
                            'Potência Nominal do Sistema (kW)\n' +
                            'Acréscimo\n Ajuste Anual Tarifa\n Rendimento Médio\n',

                            (isOwnerUserActive == true ? opportunity.OwnerId : UserInfo.getUserId()),

                            TaskBO.getActivityDateBasedOnWorkingDays(System.today(), 1),
                            
                            '1'
                        ));
                        continue;
                    }

                    //  GRUPO B
                    if(opportunity.GrupoTarifario__c.equalsIgnoreCase('Grupo B')){
                        // if(taskNumberToOwnerUser.get(2) == null){
                        //     taskNumberToOwnerUser.put(2, [
                        //         SELECT Id FROM User WHERE Email LIKE 'amanda@enerzee.com.br%' LIMIT 1
                        //     ]);
                        // }
                        taskstoInsert.add(TaskBO.createTask(
                            opportunity.Id,

                            'Informe os dados da proposta - Grupo B - ' + accountName,

                            'PREENCHER OS CAMPOS: \n\nModalidade de Venda\n Tipo da venda\n ' +
                            'Enquadramento da GD\n Grupo Tarifário\n Sub-Grupo Tarifário\n ' +
                            'Tipo do telhado - Estrutura de fixação\n ' +
                            'Logradouro\n Município Instalação\n Consumo Anual\n ' +
                            'Custo Médio Mensal de Energia\n Prazo de Entrega (Dias)\n ' +
                            'Validade da proposta (dias)\n' +
                            'Tarifa com tributos - B\n Tensão de Alimentação\n ' +
                            'Potência Pico do Sistema (kWp)\n Geração mensal estimada\n ' +
                            'Geração anual estimada\n Número de Módulos\n Potência Nominal do Módulo\n ' +
                            'Fabricante Módulos\n Modelo Módulos\n Número de Inversores\n Fabricante Inversor\n ' +
                            'Potência Nominal do Sistema (kW)\n' +
                            'Acréscimo\n Ajuste Anual Tarifa\n Rendimento Médio\n',

                            (isOwnerUserActive == true ? opportunity.OwnerId : UserInfo.getUserId()),
                            
                            TaskBO.getActivityDateBasedOnWorkingDays(System.today(), 1),

                            '1'
                        ));
                        continue;
                    }
                }

                //  AGENDAMENTO DA VISITA TÉCNICA
                if(OpportunityUtils.isSubStatusTechnicalVisitScheduling(opportunity)){
                    /*if(taskNumberToOwnerUser.get(3) == null){
                        taskNumberToOwnerUser.put(3, [
                            SELECT Id FROM User WHERE Email LIKE 'felipe.ramos@enerzee.com.br%' LIMIT 1
                        ]);
                    }*/
                    Id groupId = [SELECT Id FROM Group WHERE DEVELOPERNAME =: 'AnalistaViabilidadeCompromisso' LIMIT 1].id;
                    taskstoInsert.add(TaskBO.createTask(
                        opportunity.Id,

                        'Defina no compromisso de serviço os campos necessários - ' + accountName,

                        'PREENCHER OS CAMPOS:\n\n Equipe própria ou Terceira?\n Início agendado\n Duração',

                        //(taskNumberToOwnerUser.get(3) != null ? taskNumberToOwnerUser.get(3).Id : opportunity.OwnerId),
                        (groupId != null ? groupId : (isOwnerUserActive == true ? opportunity.OwnerId : UserInfo.getUserId())),

                        TaskBO.getActivityDateBasedOnWorkingDays(System.today(), 1),

                        '1'
                    ));
                    continue;
                }

                //  AGUARDANDO DADOS DA VISITA
                /*if(OpportunityUtils.isStatusAwaitingVisitData(opportunity)){
                    if(taskNumberToOwnerUser.get(4) == null){
                        taskNumberToOwnerUser.put(4, [
                            SELECT Id FROM User WHERE Email LIKE 'wellington.santos@enerzee.com.br%' LIMIT 1
                        ]);
                    }
                    taskstoInsert.add(TaskBO.createTask(
                        opportunity.Id,

                        'Acusar recebimento dos dados da visita - ' + accountName,

                        null,

                        (taskNumberToOwnerUser.get(4) != null ? taskNumberToOwnerUser.get(4).Id : (isOwnerUserActive == true ? opportunity.OwnerId : UserInfo.getUserId())),

                        opportunity.PrazoAprovacaoViabilidade__c != null ? 
                        Date.valueOf(opportunity.PrazoAprovacaoViabilidade__c) : 
                        TaskBO.getActivityDateBasedOnWorkingDays(System.today(), 2),

                        null
                    ));
                    continue;
                }*/
                
                //  ANALISE DE VIABILIDADE
                // if(OpportunityUtils.isStatusViabilityAnalysis(opportunity)){
                //     /*if(taskNumberToOwnerUser.get(5) == null){
                //         taskNumberToOwnerUser.put(5, [
                //             SELECT Id FROM Group WHERE DEVELOPERNAME =: 'UsuariosDadosViabilidade' LIMIT 1
                //         ]);
                //     }*/
                //     Id groupId = [SELECT Id FROM Group WHERE DEVELOPERNAME =: 'AnalistaViabilidade' LIMIT 1].id;
                //     taskstoInsert.add(TaskBO.createTask(
                //         opportunity.Id,

                //         'Inserir dados da viabilidade - ' + accountName,

                //         'PREENCHER OS CAMPOS:\N\NCategoria (Fase):\n ' +
                //         'Corrente nominal do disjuntor de entrada:\n Seção Nominal(Bitola do cabo):\n ' +
                //         'O padrão será readequado?\n ' +
                //         'Haverá aumento de carga?\n ' +
                //         'Estrutura de fixação (verificado in loco):\n Geração anual estimada:\n ' +
                //         'Reforço na estrutura necessário?\n ' +
                //         'Posto de transformação ou disponibilidade de acesso?\n ' +
                //         'Estudo de estrutura\n ' +
                //         'Observações pós-sombreamento:\n Observações pós-visita:\n ' +
                //         'Custos adicionais levantados:\n Tipo de Obra/projeto:\n ' +
                //         'Haverá aumento da potência nominal do sistema atual?\n ' +
                //         'Status da Viabilidade\n ' +
                //         'Tensão de Alimentação:\n O.S da Visita Técnica)\n ' +
                //         'Relatório de Sombreamento\n ' +
                //         'Arquivo do Solergo\n ' +
                //         'Roteiro de VT\n Relatório de VT\n ' +
                //         'Imagens da VT\n Layout de Instalação',

                //         //(taskNumberToOwnerUser.get(5) != null ? taskNumberToOwnerUser.get(5).Id : opportunity.OwnerId),
                //         (groupId != null ? groupId : opportunity.OwnerId),

                //         opportunity.PrazoAprovacaoViabilidade__c != null ? 
                //         TaskBO.getActivityDateBasedOnWorkingDays(Date.valueOf(opportunity.PrazoAprovacaoViabilidade__c), 2).addDays(-1) : 
                //         TaskBO.getActivityDateBasedOnWorkingDays(System.today(), 2),

                //         '2'
                //     ));
                //     continue;
                // }

                //  CONTRATO ENVIADO
                if(OpportunityUtils.isSubStatusContractSent(opportunity)){
                    if(taskNumberToOwnerUser.get(6) == null){
                        taskNumberToOwnerUser.put(6, [
                            SELECT Id FROM User WHERE Email LIKE 'contrato@enerzee.com.br%' AND IsActive = TRUE LIMIT 1
                        ]);
                    }
                    taskstoInsert.add(TaskBO.createTask(
                        opportunity.Id,
                        'É necessário anexar o contrato Assinado referente a oportunidade ' + Opportunity.Name,
                        'PREENCHER OS CAMPOS:\n\n Fase com Valor Contrato Assinado \n\n',
                        (taskNumberToOwnerUser.get(6) != null ? taskNumberToOwnerUser.get(6).Id : (isOwnerUserActive == true ? opportunity.OwnerId : UserInfo.getUserId())),

                        TaskBO.getActivityDateBasedOnWorkingDays(System.today(), 3),

                        '3'
                    ));
                    continue;
                }

                //  AGUARDANDO CONFIRMAÇÃO DO PAGAMENTO
                if(OpportunityUtils.isSubStatusAwaitingPayment(opportunity)){
                    if(taskNumberToOwnerUser.get(7) == null){
                        taskNumberToOwnerUser.put(7, [
                            SELECT Id FROM User WHERE Email LIKE 'financeiro@enerzee.com.br%' AND IsActive = TRUE LIMIT 1
                        ]);
                    }
                    taskstoInsert.add(TaskBO.createTask(
                        opportunity.Id,
                        'É necessário  confirmar o pagamento da oportunidade ' + Opportunity.Name,
                        'PREENCHER OS CAMPOS:\n\n Fase com Valor Pagamento Confirmado \n\n',
                        (taskNumberToOwnerUser.get(6) != null ? taskNumberToOwnerUser.get(6).Id : (isOwnerUserActive == true ? opportunity.OwnerId : UserInfo.getUserId())),

                        TaskBO.getActivityDateBasedOnWorkingDays(System.today(), 3),

                        '3'
                    ));
                    continue;
                }
            }

            if(OpportunityUtils.isFinancingSimulation(opportunity,oldMap.get(opportunity.Id))){
                taskstoInsert.add(TaskBO.createTask(
                            opportunity.Id,
                            'Anexar Simulações de Financiamento - ' + accountName,
                            'PREENCHER OS CAMPOS: \n\nDetalhes do Processo de Financiamento\n',
                            financeiroQueue,
                            TaskBO.getActivityDateBasedOnWorkingDays(System.today(), 1),
                            '1'
                        ));
                        continue;
            }
        }

        insert tasksToInsert;
    }

    public static void validateSellBuyOrderAndContractRequiredFields(List<Opportunity> newList, Map<Id, Opportunity> oldMap){
        /* -- Removido Ticket-ES-148
        List<SObjectField> opportunityRequiredFields = new List<SObjectField>{
            Opportunity.Classificacao__c,
            Opportunity.NumeroOrigemContrato__c
        };
        */

        List<SObjectField> kitRequiredFields = new List<SObjectField>{
            Kit_Instalacao__c.AniversarioLinha__c,
            Kit_Instalacao__c.Recorrencia__c,
            Kit_Instalacao__c.TipoFaturamento__c,
            Kit_Instalacao__c.TipoMedicao__c,
            Kit_Instalacao__c.UnidadeMedidaLocacao__c,
            Kit_Instalacao__c.VencimentoBase__c,
            Kit_Instalacao__c.CodigoImposto__c
        };

        List<Opportunity> wonOpportunities = new List<Opportunity>();
        List<Opportunity> contractOpportunities = new List<Opportunity>();
        List<Opportunity> allContextOpportunities = new List<Opportunity>();
        for(Opportunity opportunity : newList){
            if( OpportunityUtils.isSubTypeMicroContract(opportunity) || 
                OpportunityUtils.isSubTypeMiniContract(opportunity) ||
                OpportunityUtils.isRecordTypeOtherOpportunities(opportunity) ){
                if(OpportunityUtils.isChangingToClosedWon(opportunity, oldMap.get(opportunity.Id))){
                    wonOpportunities.add(opportunity);
                    allContextOpportunities.add(opportunity);
                    continue;
                }

                if(OpportunityUtils.isChangingContractGenerating(opportunity, oldMap.get(opportunity.Id))){
                    contractOpportunities.add(opportunity);
                    allContextOpportunities.add(opportunity);
                    continue;
                }
            }
        }

        if(!contractOpportunities.isEmpty() || !wonOpportunities.isEmpty()){
            //  Validar campos do Kit para ambas APIs de Contrato e Pedido de Compra/Venda
            Map<Id, List<Kit_Instalacao__c>> opportunityIdToKitList = new Map<Id, List<Kit_Instalacao__c>>();
            for(Kit_Instalacao__c kit : [
                SELECT  AniversarioLinha__c, Recorrencia__c, TipoFaturamento__c,
                        TipoMedicao__c, UnidadeMedidaLocacao__c, VencimentoBase__c,
                        CodigoImposto__c, Nome_da_Oportunidade__c
                FROM    Kit_Instalacao__c
                WHERE   Nome_da_Oportunidade__c IN :Collection.of(allContextOpportunities).pluckNotNullStrings(Opportunity.Id)
            ]){
                if(!opportunityIdToKitList.containsKey(kit.Nome_da_Oportunidade__c)){
                    opportunityIdToKitList.put(kit.Nome_da_Oportunidade__c, new List<Kit_Instalacao__c>());
                }
                opportunityIdToKitList.get(kit.Nome_da_Oportunidade__c).add(kit);
            }

            for(Opportunity opportunity : contractOpportunities){
                if(!opportunityIdToKitList.isEmpty()){
                    if(opportunity.DataEntrega__c == null){
                        opportunity.addError('Favor preencher o campo Data de Entrega antes de alterar para este status!');
                        continue;
                    }

                    for(Kit_Instalacao__c kit : opportunityIdToKitList.get(opportunity.Id)){
                        for(SObjectField field : kitRequiredFields){
                            if(
                                kit.get(field.getDescribe().getName()) == null || 
                                kit.get(field.getDescribe().getName()) == ''
                            ){
                                opportunity.addError('Favor preencher todos os campos da seção de Dados para Envio de Contrato nos Kits antes de alterar para este status!');
                                continue;
                            }
                        }
                    }
                }
            }

            //  Validar campos da Oportunidade apenas para API de Pedido de Compra/Venda
            if(!wonOpportunities.isEmpty()){
                opportunityIdToKitList = new Map<Id, List<Kit_Instalacao__c>>();
                for(Kit_Instalacao__c kit : [
                    SELECT  AniversarioLinha__c, Recorrencia__c, TipoFaturamento__c,
                            TipoMedicao__c, UnidadeMedidaLocacao__c, VencimentoBase__c,
                            CodigoImposto__c, Nome_da_Oportunidade__c
                    FROM    Kit_Instalacao__c
                    WHERE   Nome_da_Oportunidade__c IN :Collection.of(wonOpportunities).pluckNotNullStrings(Opportunity.Id)
                ]){
                    if(!opportunityIdToKitList.containsKey(kit.Nome_da_Oportunidade__c)){
                        opportunityIdToKitList.put(kit.Nome_da_Oportunidade__c, new List<Kit_Instalacao__c>());
                    }
                    opportunityIdToKitList.get(kit.Nome_da_Oportunidade__c).add(kit);
                }
                
                /*  -- Removido Ticket-ES-148
                for(Opportunity opportunity : wonOpportunities){
                    for(SObjectField field : opportunityRequiredFields){
                        if(
                            opportunity.get(field.getDescribe().getName()) == null || 
                            opportunity.get(field.getDescribe().getName()) == ''
                        ){
                            opportunity.addError('Favor preencher os campos "Classificação" e "Número de Origem do Contrato" antes de concluir a Oportunidade!');
                            continue;
                        }
                    }
                }*/
            }
        }
    }

    public static void validateViabilityTexts(List<Opportunity> newList, Map<Id, Opportunity> oldMap){
        for(Opportunity opp : newList){
            Opportunity oldOpp = oldMap.get(opp.Id);
            
            if(OpportunityUtils.isViabilityStatusBeingAssigned(opp, oldOpp)){

                if(OpportunityUtils.isOpportunityPartiallyViable(opp) && opp.TextoEstudo__c == null){
                    opp.addError('Para uma análise Parcialmente Viável, o campo "Texto de Estudo" precisa ser preenchido');
                    continue;
                }

                if(OpportunityUtils.isOpportunityNotViable(opp) && opp.TextoMotivo__c == null){
                    opp.addError('Para uma análise Inviável, o campo "Texto de Motivo" precisa ser preenchido');
                    continue;
                }
            }
        }
    }

    public static void calculateDataToProposalGraphic25Years(List<Opportunity> opportunityList){
        // PROPOSTA A
        PriceGenerationTable priceTableA = getPriceTableFromStaticResource('A');
        
        // PROPOSTA B
        PriceGenerationTable priceTableB = getPriceTableFromStaticResource('B');
        
        for(Opportunity opportunity : opportunityList){
            try{
                if(opportunity.GrupoTarifario__c == 'Grupo A'){
                    List<YearData> anos = new List<YearData>();
                    Map<Integer, YearData> yearByIndex = new Map<Integer, YearData>();

                    String[] degradacaoProducaoArray = 
                        new String[]{'2', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45'};
                    
                    for(Integer i = 1; i <= 25; i++){
                        YearData year = new YearData();
                        year.index = i;
                        year.degradacaoProducao = Double.valueOf(degradacaoProducaoArray[i - 1]);

                        anos.add(year);
                        yearByIndex.put(i, year);
                    }

                    Double precoSistemaSemDesconto = 0;
                    Double kWp = 0;

                    for(PriceGenerationTableLine line : priceTableA.tableLines){
                        if(line.numeroModulos == opportunity.NumeroModulos__c){
                            precoSistemaSemDesconto = line.valorVenda;
                            kWp =  opportunity.NumeroModulos__c * (Double.valueOf(opportunity.PotenciaNominalWp__c) / 1000);
                            break;
                        }
                    }

                    Double acrescimo = opportunity.Acrescimo__c;
                    Double precoAdotado = acrescimo > 0 ? 
                                        (precoSistemaSemDesconto + (precoSistemaSemDesconto * acrescimo)) : 
                                        precoSistemaSemDesconto;
                    Double investimentoInicial = precoAdotado;

                    Double tarifaForaPonta = opportunity.TarifaForaPonta__c;
                    Double demandaContratadaForaPonta = opportunity.DemandaContratadaForaPonta__c;
                    Double tarifaDemandaForaPonta = opportunity.TarifaDemandaForaPonta__c;
                    Double ajusteAnualTarifa = opportunity.AjusteAnualTarifa__c;

                    Double rendimentoMedio = opportunity.RendimentoMedio__c;
                    Double anualAdotado = kWp * rendimentoMedio * 720 * 12;
                    for(YearData year : anos){
                        Double tarifaFPAnoProposto = year.index != 1 ? 
                            yearByIndex.get(year.index - 1).tarifa : 0;

                        year.tarifa = year.index == 1 ? 
                                    tarifaForaPonta :
                                    tarifaFPAnoProposto + (tarifaFPAnoProposto * ajusteAnualTarifa);

                        year.producao = year.index == 1 ? 
                                        anualAdotado :
                                        yearByIndex.get(1).producao - (year.degradacaoProducao * yearByIndex.get(1).producao);

                        year.valorEconomizado = (year.producao * year.tarifa) - 
                                                (12 * demandaContratadaForaPonta * tarifaDemandaForaPonta);

                        year.payback = year.index == 1 ? 
                                    (investimentoInicial - (2 * investimentoInicial)) + ((year.valorEconomizado / 12) * 8):
                                    yearByIndex.get(year.index - 1).payback + year.valorEconomizado; 
                    }

                    opportunity.PaybackAno25__c = String.valueOf(yearByIndex.get(25).payback.setScale(2));

                } else if(opportunity.GrupoTarifario__c == 'Grupo B'){
                    List<YearData> anos = new List<YearData>();
                    Map<Integer, YearData> yearByIndex = new Map<Integer, YearData>();

                    String[] degradacaoProducaoArray = 
                        new String[]{'2', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45', '0.45'};
                    
                    for(Integer i = 1; i <= 25; i++){
                        YearData year = new YearData();
                        year.index = i;
                        year.degradacaoProducao = Double.valueOf(degradacaoProducaoArray[i - 1]);

                        anos.add(year);
                        yearByIndex.put(i, year);
                    }

                    Double precoSistemaSemDesconto = 0;
                    Double kWp = 0;

                    for(PriceGenerationTableLine line : priceTableB.tableLines){
                        if(line.numeroModulos == opportunity.NumeroModulos__c){
                            precoSistemaSemDesconto = line.valorVenda;
                                kWp =  opportunity.NumeroModulos__c * (Double.valueOf(opportunity.PotenciaNominalWp__c) / 1000);
                            break;
                        }
                    }

                    Double acrescimo = opportunity.Acrescimo__c;
                    Double precoAdotado = acrescimo > 0 ? 
                                        (precoSistemaSemDesconto + (precoSistemaSemDesconto * acrescimo)) : 
                                        precoSistemaSemDesconto;
                    Double investimentoInicial = precoAdotado;

                    Double tarifaEnergiaAnoZero = opportunity.TarifaComTributosB__c;
                    Double ajusteAnualTarifa = opportunity.AjusteAnualTarifa__c;

                    Double anualSolergo = opportunity.GeracaoAnualEstimada__c;
                    Double rendimentoMedio = opportunity.RendimentoMedio__c;
                    Double anualAdotado = anualSolergo > 0 ? anualSolergo : kWp * rendimentoMedio * 720 * 12;
                    for(YearData year : anos){
                        Double tarifaAnoProposto = year.index != 1 ? 
                            yearByIndex.get(year.index - 1).tarifa : 0;

                        year.tarifa = year.index == 1 ? 
                                    tarifaEnergiaAnoZero :
                                    tarifaAnoProposto + (tarifaAnoProposto * ajusteAnualTarifa);

                        year.producao = year.index == 1 ? 
                                        anualAdotado :
                                        yearByIndex.get(1).producao - (year.degradacaoProducao * yearByIndex.get(1).producao);

                        year.valorEconomizado = year.producao * year.tarifa;

                        year.payback = year.index == 1 ? 
                                    (investimentoInicial - (2 * investimentoInicial)) :
                                    yearByIndex.get(year.index - 1).payback + year.valorEconomizado; 
                    }

                    opportunity.PaybackAno25__c = String.valueOf(yearByIndex.get(25).payback.setScale(2));

                }
            }catch(Exception e){
                Utils.createLog('OpportunityBO', 'calculateDataToProposalGraphic25Years ' + (Trigger.isInsert ? '' : opportunity.Id), e);
            }
        }
    }

    public static PriceGenerationTable getPriceTableFromStaticResource(String proposalType){
        proposalType = 'TabelaGeracaoPrecos' + proposalType;
        StaticResource pricesTable = [
            SELECT  Id, Body 
            FROM    StaticResource 
            WHERE   Name = :proposalType
            LIMIT   1
        ];
        String tableBody = pricesTable.Body.toString();

        CSVReader tableBodyCSVReader = new CSVReader(tableBody, '|');

        tableBodyCSVReader.readLine();

        String[] tableBodyLine = tableBodyCSVReader.readLine();

        PriceGenerationTable table = new PriceGenerationTable();
        table.tableLines = new List<PriceGenerationTableLine>();

        while (tableBodyLine != null)
        {
            PriceGenerationTableLine line = new PriceGenerationTableLine();
            line.numeroModulos = Integer.valueOf(tableBodyLine[0]);
            line.valorVenda = Double.valueOf(tableBodyLine[1]);

            table.tableLines.add(line);

            tableBodyLine = tableBodyCSVReader.readLine();
        }
        
        if (tableBodyLine != null) {
            PriceGenerationTableLine line = new PriceGenerationTableLine();

            line.numeroModulos = Integer.valueOf(tableBodyLine[0]);
            line.valorVenda = Double.valueOf(tableBodyLine[1]);

            table.tableLines.add(line);
        }
        return table;
    }
        

    public static void updateKitsOnPotenciaChange(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        // Set para coletar os IDs das Oportunidades onde o campo PotenciaNominalWp__c mudou
        Set<Id> opportunityIdsWithChangedPotencia = new Set<Id>();
        
        // Iterar pela lista de oportunidades atualizadas
        for(Opportunity newOp : newList) {
            Opportunity oldOp = oldMap.get(newOp.Id);
            
            System.debug('opportunityIdsWithChangedPotencia ValorTotalProdutos__c changed: ' + oldOp.ValorTotalProdutos__c + ' -> ' + newOp.ValorTotalProdutos__c);
            // Verificando se o valor do campo PotenciaNominalWp__c mudou
            if(oldOp.PotenciaNominalWp__c != newOp.PotenciaNominalWp__c) {
                opportunityIdsWithChangedPotencia.add(newOp.Id);
            }
        }

        // Buscar OpportunityLineItems associados às Oportunidades que tiveram mudança
        List<OpportunityLineItem> changedItems = [
            SELECT Id, Kit_Instalacao__c 
            FROM OpportunityLineItem 
            WHERE OpportunityId IN :opportunityIdsWithChangedPotencia
        ];

        // Se existirem itens alterados, chamar o método para atualizar
        if(!changedItems.isEmpty()) {
            OpportunityLineItemBO.forceKitUpdateOnItemInsertUpdate(changedItems);
        }
    }

    public static void revertStageForNivelloAPIUser(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        // Pegar o ID do usuário "Nivello API Integração" através de SOQL
        User nivelloUser;
        try {
            nivelloUser = [SELECT Id FROM User WHERE UserName like 'integracao@lab065.com%' LIMIT 1];
        } catch (Exception e) {
            // Aqui você pode lidar com erros, como registrar em um log ou apenas continuar.
            // Se o usuário não existir, o método simplesmente não fará nada.
            return;
        }
        
        for(Opportunity opp : newList) {
            Opportunity oldOpp = oldMap.get(opp.Id);
            
            // Verificar se o StageName está sendo mudado e o usuário é "Nivello API Integração"
            if (opp.StageName != oldOpp.StageName && oldOpp.StageName == 'Elaboração de proposta' && opp.StageName == 'Prospecção' && UserInfo.getUserId() == nivelloUser.Id) {
                opp.StageName = oldOpp.StageName; // Reverter a mudança do StageName
            }
        }
    }

    public static void applyDiscountAndInitiateApproval(Map<Id,Opportunity> newMap, Map<Id,Opportunity> oldMap) {
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        List<Approval.ProcessSubmitRequest> approvalRequests = new List<Approval.ProcessSubmitRequest>();
        
        // Pega a informação dos metadados do campo StageName
        Schema.DescribeFieldResult fieldResult = Opportunity.StageName.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();

        // Construa uma lista ordenada com os valores do StageName
        List<String> stages = new List<String>();
        for (Schema.PicklistEntry pickVal : picklistValues) {
            stages.add(pickVal.getLabel());
        }

        // Pega IDs de Oportunidades que podem precisar de aprovação
        Set<Id> oppIdsForApprovalCheck = newMap.keySet();

        // Verifica quais Oportunidades já têm um processo de aprovação pendente
        Set<Id> oppIdsWithActiveApproval = new Set<Id>();
        for(ProcessInstance pi : [SELECT TargetObjectId FROM ProcessInstance WHERE TargetObjectId IN :oppIdsForApprovalCheck AND Status = 'Pending']){
            oppIdsWithActiveApproval.add(pi.TargetObjectId);
        }

        for (Opportunity opp : newMap.values()) {
            
            Opportunity oldOpp = oldMap.get(opp.Id);
            Opportunity updateOpp = new Opportunity(Id = opp.Id);
            
            // Verifique se o desconto foi alterado
            if (opp.StatusAprovacaoDesconto__c != oldOpp.StatusAprovacaoDesconto__c && opp.StatusAprovacaoDesconto__c == 'Pendente') {
                // Calculando a porcentagem de desconto em relação ao valor total da proposta
                Decimal discountPercentage = (opp.DescontoUFV__c / opp.ValorTotalProposta__c) * 100;

                // Calcular a porcentagem de BDI em relação à soma de BDI e campos de Rede
                Decimal totalValue = opp.BDI__c + opp.Rede3750__c + opp.Pontos__c + opp.Direct__c;
                Decimal BDI_Percentage = 0;
                Decimal Rede_Percentage = 0;
                if(totalValue > 0){
                    // Calcular a porcentagem de BDI em relação à soma de BDI e campos de Rede
                    BDI_Percentage = (opp.BDI__c / totalValue);
                    Rede_Percentage = 1 - BDI_Percentage;
                }
                Decimal BDI_Discount = opp.DescontoUFV__c * BDI_Percentage;
                Decimal Rede_Discount = opp.DescontoUFV__c * Rede_Percentage;

                // Aplicar o desconto aos campos propostos
                updateOpp.ValorPropostoBDI__c = opp.BDI__c - BDI_Discount;
                //updateOpp.ValorPropostoRede3750__c = opp.Rede3750__c - (Rede_Discount * (opp.Rede3750__c / totalValue));
                //updateOpp.ValorPropostoPontos__c = opp.Pontos__c - (Rede_Discount * (opp.Pontos__c / totalValue));
                //updateOpp.ValorPropostoDirect__c = opp.Direct__c - (Rede_Discount * (opp.Direct__c / totalValue));
                // updateOpp.ValorPropostoRede3750__c = opp.Rede3750__c - (Rede_Discount * (opp.Rede3750__c / opp.rede__c));
                // updateOpp.ValorPropostoPontos__c = opp.Pontos__c - (Rede_Discount * (opp.Pontos__c / opp.rede__c));
                // updateOpp.ValorPropostoDirect__c = opp.Direct__c - (Rede_Discount * (opp.Direct__c / opp.rede__c));

                if(opp.rede__c > 0 && opp.Rede3750__c > 0 ){
                    updateOpp.ValorPropostoRede3750__c = opp.Rede3750__c - (Rede_Discount * (opp.Rede3750__c / opp.rede__c));
                }
                if(opp.Pontos__c > 0 && opp.rede__c > 0 ){
                    updateOpp.ValorPropostoPontos__c = opp.Pontos__c - (Rede_Discount * (opp.Pontos__c / opp.rede__c));
                }
                if(opp.Direct__c > 0 && opp.rede__c > 0 ){
                    updateOpp.ValorPropostoDirect__c = opp.Direct__c - (Rede_Discount * (opp.Direct__c / opp.rede__c));
                }

                //fields original to approve

                updateOpp.BDIOriginal__c = opp.BDI__c;
                updateOpp.DirectOriginal__c = opp.Direct__c;
                updateOpp.PontosOriginal__c = opp.Pontos__c;
                updateOpp.TotalRedeOriginal__c = opp.Rede3750__c + opp.Pontos__c + opp.Direct__c;
                updateOpp.RedeOriginal3750__c = opp.Rede3750__c;
                updateOpp.ValorTotalPropostaOriginal__c = opp.ValorTotalProposta__c;

                // Agora você pode usar a lógica anterior de verificação de índice
                Integer currentIndex = stages.indexOf(opp.StageName);

                // Se encontrou o estágio atual na lista
                /*
                if (currentIndex != -1) { 
                    if (currentIndex < stages.indexOf('Análise de viabilidade')) {
                        updateOpp.StageName = 'Elaboração de proposta';
                    } else {
                        updateOpp.StageName = 'Readequação de proposta';
                    }
                }*/

                oppsToUpdate.add(updateOpp);

                // Se já possui uma aprovação pendente, pule a Oportunidade
                if (oppIdsWithActiveApproval.contains(opp.Id)) {
                    continue;
                }

                // Iniciando o processo de aprovação
                Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
                req.setComments('Submissão automática para aprovação de desconto.');
                req.setObjectId(opp.Id);
                req.setSubmitterId(UserInfo.getUserId());
                req.setProcessDefinitionNameOrId('Processo_de_Aprova_o_de_Desconto');
                approvalRequests.add(req);
                
            }
        }

        // Atualize as oportunidades modificadas após sair do loop
        if (!oppsToUpdate.isEmpty()) {
            OpportunityTriggerHandler.disableTrigger();
            update oppsToUpdate;
            OpportunityTriggerHandler.enableTrigger();
        }

        // Submeter os registros para aprovação
        if (!approvalRequests.isEmpty() && !Test.isRunningTest()) {
            OpportunityTriggerHandler.disableTrigger();
            Approval.process(approvalRequests);
            OpportunityTriggerHandler.enableTrigger();
        }
    }

    public static void applyApprovedDiscounts(Map<Id,Opportunity> newMap, Map<Id,Opportunity> oldMap) {
        // Lista de Opportunities que foram aprovados
        List<Opportunity> approvedOpportunities = new List<Opportunity>();

        for (Opportunity opp : newMap.values() ) {
            Opportunity oldOpp = oldMap.get(opp.Id);
            
            // Verifica se o StatusAprovacaoDesconto foi alterado e é igual a "Approved"
            if (opp.StatusAprovacaoDesconto__c == 'Aprovado' && opp.StatusAprovacaoDesconto__c != oldOpp.StatusAprovacaoDesconto__c) {
                
                Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
                
                // Guardando os valores anteriores
                oppToUpdate.ValorAnteriorBDI__c = opp.BDI__c;
                oppToUpdate.ValorAnteriorRede3750__c = opp.Rede3750__c;
                oppToUpdate.ValorAnteriorPontos__c = opp.Pontos__c;
                oppToUpdate.ValorAnteriorDirect__c = opp.Direct__c;

                // Atualizando com os valores propostos após a aprovação
                oppToUpdate.BDI__c = opp.ValorPropostoBDI__c;
                oppToUpdate.Rede3750__c = opp.ValorPropostoRede3750__c;
                oppToUpdate.Pontos__c = opp.ValorPropostoPontos__c;
                oppToUpdate.Direct__c = opp.ValorPropostoDirect__c;
                approvedOpportunities.add(oppToUpdate);

                oppToUpdate.PropostaAlterada__c = true;
            }
        }

        // Se houver Opportunities aprovadas, chama o método applyApprovedDiscounts
        if (!approvedOpportunities.isEmpty()) {
            OpportunityTriggerHandler.disableTrigger();
            update approvedOpportunities;
            OpportunityTriggerHandler.enableTrigger();
            
            for (Opportunity opp : approvedOpportunities){
            }
            
        }
    }
    
    public static void generateProposalAsync(Map<Id,Opportunity> newMap, Map<Id,Opportunity> oldMap) {
        if(skipAsyncProposalGeneration == true){
            return;
        }
        for(Opportunity opp :  newMap.values() ){
            Opportunity oldOpp = oldMap.get(opp.Id);
            if(((opp.RecordTypeId == Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('EzeeConnect').getRecordTypeId() && areRequiredFieldsFilledConnect(opp)) ||
                (opp.RecordTypeId == Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId() && areRequiredFieldsFilled(opp))) &&                    
                 opp.GrupoTarifario__c != 'Grupo A'
                ){
                System.debug('if 1 - generateProposalAsync - ');
                if( (OpportunityUtils.isStatusProposalElaboration(opp) || OpportunityUtils.isStatusProposalSimulation(opp)) && 
                    (
                        opp.StageName != oldOpp.StageName  && 
                        opp.PropostaGerada__c == false) 
                        ||
                    (
                        opp.StageName == oldOpp.StageName  && 
                        opp.ReadequacaoSolicitada__c != oldOpp.ReadequacaoSolicitada__c &&
                        opp.ReadequacaoSolicitada__c == true
                    ) ||
                    (
                        oldOpp.PropostaGerada__c != opp.PropostaGerada__c &&
                        opp.PropostaGerada__c == true &&
                        opp.StatusAprovacaoDesconto__c != oldOpp.StatusAprovacaoDesconto__c &&
                        opp.StatusAprovacaoDesconto__c == 'Aprovado'
                    ) ||
                    (
                        opp.PropostaGerada__c == false
                    )
                ){
                    System.debug('if 2 - generateProposalAsync - ');
                    // PDFControllerExtension.savePdfFileAsync(opp.Id);
                }
            }
        }
    }

    public static void processPaymentMethodApproval(Map<Id,Opportunity> newMap, Map<Id, Opportunity> oldOpportunityMap) {
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        List<Approval.ProcessSubmitRequest> approvalRequests = new List<Approval.ProcessSubmitRequest>();

        for (Opportunity opp : newMap.values()) {
            Opportunity oldOpp = oldOpportunityMap.get(opp.Id);
            Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
            if (
                OpportunityUtils.isStatusAwaitingAcceptance(opp) && 
                opp.CondicoesPagamento__c == 'Negociação' 
                && (    
                    oldOpp == null || 
                    oldOpp.StageName != opp.StageName || 
                    oldOpp.CondicoesPagamento__c != opp.CondicoesPagamento__c
                )
            ) {
                //oppToUpdate.StageName = OpportunityUtils.STATUS_VALIDACAO_DO_METODO_DE_PAGAMENTO; //'Validação de Método de pagamento';
                // Inicia o processo de aprovação aqui, se necessário
                //opportunitiesToUpdate.add(oppToUpdate);

                // Criando a solicitação de envio para o processo de aprovação
                Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
                req.setComments('Iniciando processo de aprovação automaticamente para condição de pagamento negociável.');
                req.setObjectId(opp.Id);
                req.setSubmitterId(UserInfo.getUserId());
                req.setProcessDefinitionNameOrId('Validacao_de_pagamento');
                approvalRequests.add(req);
                
            }
        }
    
        //if (!opportunitiesToUpdate.isEmpty()) {
        //    update opportunitiesToUpdate;
        //}

        // Enviando solicitações de aprovação
        if (!approvalRequests.isEmpty()) {
            for (Approval.ProcessSubmitRequest req : approvalRequests) {
                try {
                    Approval.ProcessResult result = Approval.process(req);
                    // Trate o resultado aqui, se necessário
                } catch(Exception e) {
                    // Tratamento de exceção adequado
                }
            }
        }

    }

    public static void scheduleTechnicalVisit( Map<Id,Opportunity> newMap , Map<Id, Opportunity> oldOpportunityMap) {
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
    
        for (Opportunity opp : newMap.values()) {
            Opportunity oldOpp = oldOpportunityMap.get(opp.Id);
            Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
            if (
                OpportunityUtils.isStatusAwaitingAcceptance(opp) && 
                opp.CondicoesPagamento__c != 'Negociação' &&
                String.isNotBlank(opp.CondicoesPagamento__c)
                && (
                    oldOpp == null || 
                    oldOpp.StageName != opp.StageName || 
                    oldOpp.CondicoesPagamento__c != opp.CondicoesPagamento__c
                )
            ) {
                oppToUpdate.Status__c = OpportunityUtils.SUB_STATUS_AGENDAMENTO_VISITA; //'Agendamento da Visita Técnica';
                opportunitiesToUpdate.add(oppToUpdate);
            }
        }
    
        if (!opportunitiesToUpdate.isEmpty()) {
            update opportunitiesToUpdate;
        }
    }

    public static void updateOpportunityTotalValueIfNeeded(List<Opportunity> newOpps, Map<Id, Opportunity> oldOppMap) {
        Set<Id> oppIds = new Set<Id>();
        for (Opportunity newOpp : newOpps) {
            Opportunity oldOpp = oldOppMap.get(newOpp.Id);
            if (newOpp.CustoAdicional__c != oldOpp.CustoAdicional__c) {
                oppIds.add(newOpp.Id);
            }
        }
        if(!oppIds.isEmpty())
            IntegracaoNivelloValorTotalProposta.updateOpportunityTotalValue(oppIds);
    }

    public static void processUpdatedOpportunitiesForSimulation(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        Set<Id> idsToSend = new Set<Id>();

        for (Opportunity opp : newList) {
            Opportunity oldOpp = oldMap.get(opp.Id);

            if (    
                opp.RecordTypeId == Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('EzeeSolarB').getRecordTypeId()
                || opp.RecordTypeId == Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('EzeeSolarA').getRecordTypeId() 
                || opp.RecordTypeId == Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('EzeeConnect').getRecordTypeId() 
            ){ 
                idsToSend.add(opp.Id);
            }
        }
        if (!idsToSend.isEmpty()) {
            IntegracaoNivelloProposta.sendUrlSimulation(idsToSend);
        }
    }

    // Método para atualizar o Owner da Oportunidade
    public static void updateOwnerOnFirstModification(List<Opportunity> oppList) {
        // Obter o ID do Usuário de Integração
        Id integrationUserId = [
            SELECT  Id
            FROM    User
            WHERE   UserName like '%integracao@lab065.com%'
            LIMIT   1
        ].Id; 

        // Lista para oportunidades a serem atualizadas
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

        for (Opportunity opp : oppList) {
            // Verificar se o Owner ainda é o usuário de integração
            if (opp.OwnerId == integrationUserId && integrationUserId != UserInfo.getUserId()) {
                // Verificar se o último modificador NÃO é administrador ou integração
                User lastModifier = [SELECT Profile.Name 
                                        FROM User 
                                        WHERE Id = :UserInfo.getUserId()
                                        LIMIT 1];

                if ( lastModifier.Profile.Name != 'System Administrator' 
                    || lastModifier.Profile.Name != 'Administrador do sistema') {
                    // Atualizar o Owner para o último modificador
                    opp.OwnerId = UserInfo.getUserId();
                    //opportunitiesToUpdate.add(opp);
                }
            }
        }

        // Atualizar as oportunidades na base de dados
        //if (!opportunitiesToUpdate.isEmpty()) {
        //    update opportunitiesToUpdate;
        //}
    }
    

    public class PriceGenerationTableLine{
        public Integer numeroModulos;
        public Double  valorVenda;
    }

    public class PriceGenerationTable{
        public PriceGenerationTableLine[] tableLines;
    }

    public class YearData{
        public Integer index;
        public Double  valorEconomizado;
        public Double  producao;
        public Double  tarifa;
        public Double  degradacaoProducao;
        public Decimal payback;
    }

    public static String removeAccents(String input) {
        if (input == null) {
            return null;
        }
        String normalized = input;
        // Replace accented characters with their non-accented counterparts
        normalized = normalized.replaceAll('[áàäâãå]', 'a');
        normalized = normalized.replaceAll('[ÁÀÄÂÃÅ]', 'A');
        normalized = normalized.replaceAll('[éèëê]', 'e');
        normalized = normalized.replaceAll('[ÉÈËÊ]', 'E');
        normalized = normalized.replaceAll('[íìïî]', 'i');
        normalized = normalized.replaceAll('[ÍÌÏÎ]', 'I');
        normalized = normalized.replaceAll('[óòöôõ]', 'o');
        normalized = normalized.replaceAll('[ÓÒÖÔÕ]', 'O');
        normalized = normalized.replaceAll('[úùüû]', 'u');
        normalized = normalized.replaceAll('[ÚÙÜÛ]', 'U');
        normalized = normalized.replaceAll('[ç]', 'c');
        normalized = normalized.replaceAll('[Ç]', 'C');
        normalized = normalized.replaceAll('[ñ]', 'n');
        normalized = normalized.replaceAll('[Ñ]', 'N');
        return normalized;
    }

    public static void checksAndClosesTaskFollowUpCall(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecordsMap){
        for(Opportunity opp : newRecords){
            Opportunity oldOpp = oldRecordsMap.get(opp.id);
            if(
                OpportunityUtils.isStatusChanging(opp, oldOpp) &&
                (
                 OpportunityUtils.isStatusProposalSent(oldOpp) ||
                 OpportunityUtils.isStatusProposalGenerated(oldOpp) ||
                 OpportunityUtils.isStatusAwaitingAcceptance(oldOpp) ||
                 OpportunityUtils.isStatusProposalReadjustment(oldOpp) ||
                 OpportunityUtils.isSubStatusContractSent(oldOpp))
            ){
                Id closerId = [
                    SELECT Id 
                    FROM User 
                    WHERE Email LIKE 'wagner.sampaio@enerzee.com.br%' LIMIT 1
                ].Id;
                
                List<Task> tasksToClose = [
                    SELECT Id, Status 
                    FROM Task 
                    WHERE WhatId = :opp.Id AND Status = 'Open' AND OwnerId =: closerId AND Subject LIKE '%Ligação de follow-up%'
                ];
                
                for(Task task : tasksToClose){
                    task.Status = 'Completed';
                    task.MetodoDeFollowup__c = 'Automático';
                    
                    ContentNote note = new ContentNote();
                	note.Title = 'Tarefa Concluída';
                	note.Content = Blob.valueOf('Tarefa concluída automaticamente via integração');
                	insert note;
                    
                    ContentDocumentLink cdl = new ContentDocumentLink();
					cdl.ContentDocumentId = [SELECT Id FROM ContentNote WHERE Id = :note.Id].Id;
					cdl.LinkedEntityId = task.Id;
					cdl.ShareType = 'I';
					cdl.Visibility = 'AllUsers';
					insert cdl;

                }
                
                update tasksToClose;
            }
        }
    }
    
    public static void checkAndSendToRevo(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecordsMap) {
        for (Opportunity opp : newRecords) {
            Opportunity oldOpp = oldRecordsMap.get(opp.Id);

            // Verifica condições para enviar a integração
            if (OpportunityUtils.isEzeeSolarGrupoBInCreditAnalysis(opp, oldOpp)) {
                RevoIntegrationService.sendToCreditAnalysis(opp.Id);
                createRevoUploadTask(opp);
            }
        }
    }

    private static void createRevoUploadTask(Opportunity opp) {
        
        String taskOwner = [    SELECT Id 
                                FROM User 
                                WHERE   IsActive = true AND 
                                        Email LIKE 'wagner.sampaio@enerzee.com.br%'
                                LIMIT 1
                            ]?.Id;
        System.debug('task' + taskOwner);
        if (taskOwner == null) {
            taskOwner = opp.OwnerId;
        }

        Task newTask = TaskBO.createTask(
            opp.Id,
            'Anexar documentos no site da REVO',
            'Favor anexar os documentos necessários na plataforma da REVO para prosseguir com a análise de crédito.',
            taskOwner,
            TaskBO.getActivityDateBasedOnWorkingDays(System.today(), 3),
            'High'
        );
        insert newTask;
    }

    public static void sendCustomerRecordToSAP(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecordsMap){

        try{
            
            User runningUser = [
                SELECT  Id, Name, Profile.Name
                FROM    User
                WHERE   Id =: UserInfo.getUserId()
            ];

            if(!runningUser.Name.equalsIgnoreCase('Integrador SAP')){

                Set<Id> accountIds = new Set<Id>();

                for(Opportunity opportunity : newRecords){

                    //Filtrar opportunities fechada ganha.
                    if(OpportunityUtils.isStatusChanging(opportunity, oldRecordsMap.get(opportunity.Id)) && OpportunityUtils.isStatusAwaitingAcceptance(opportunity)){
                        accountIds.add(opportunity.AccountId);
                    }
                }
            
                IntegracaoSAPCliente.sendCliente(accountIds);
            }

        }  catch(Exception ex){
            System.debug('##Erro ao integrar Conta com SAP: ' + ex.getMessage());
            System.debug('##Stack: ' + ex.getStackTraceString());
            System.debug('##Line: ' + ex.getLineNumber());
        }
    }

    public static void createMessagingUser(List<Opportunity> newRecordList, Map<Id, Opportunity> oldMap){

        try{

            List<MessagingEndUser> messagingUsers = new List<MessagingEndUser>();

            List<MessagingChannel> channels = [SELECT Id, masterlabel from MessagingChannel WHERE MasterLabel IN ('+55 11 4003-8344', '+55 65 3634-7877')];

            for(Opportunity opportunity : newRecordList){

                if(String.isBlank(opportunity.Telefone__c)){
                    continue;
                }

                Opportunity oldOpportunity = oldMap.get(opportunity.Id);

                if(oldOpportunity != null && (oldOpportunity.Telefone__c == opportunity.Telefone__c)) continue;
                    
                String phone = opportunity.Telefone__c.deleteWhiteSpace().replace('(', '').replace(')', '').replace('.', '').replace('-', '');

                if(phone.length() == 10){
                    phone = '55' + phone;
                }

                if(phone.length() == 11){
                    phone = '55' + phone.substring(0, 2) + phone.substring(3, 11);
                }

                if(phone.startsWith('55') && phone.length() == 13){
                    phone = phone.substring(0, 4) + phone.substring(5, 13);
                }

                if(channels != null){
                    for(MessagingChannel channel : channels){
                        messagingUsers.add(
                            new MessagingEndUser(
                                MessageType = 'WhatsApp',
                                MessagingConsentStatus = 'ImplicitlyOptedIn',
                                MessagingPlatformKey = phone,
                                Name = opportunity.Name,
                                MessagingChannelId = Test.isRunningTest() ? '0MjU50000011EhtKAE' : channel.Id
                            )
                        );
                    }
                }
                
            }

            Database.insert(messagingUsers, false);

        }catch(Exception ex){
            System.debug('##Erro ao messaging end user: ' + ex.getMessage());
            System.debug('##Stack: ' + ex.getStackTraceString());
            System.debug('##Line: ' + ex.getLineNumber());
        }
        
    }

    public static void createCaseCustomerJourney(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecordsMap){

        try{

            List<Case> casesCustomerJourney = new List<Case>();

            Map<Id, Opportunity> filteredOpportunities = new Map<Id, Opportunity>();
            Map<Id, Projeto__c> projectByOpportunityId = new Map<Id, Projeto__c>();
            Map<Id, Instalacao__c> installationByProjectId = new Map<Id, Instalacao__c>();
            Map<Id, Instalacao__c> installationByOpportunityId = new Map<Id, Instalacao__c>();
            Map<Id, Contact> contactByAccountId = new Map<Id, Contact>();
            Set<Id> accountIds = new Set<Id>();
            Set<Id> projectIds = new Set<Id>();
            
            for(Opportunity opportunity : newRecords){

                //Filtrar opportunities fechada ganha.
                if(
                    (
                        OpportunityUtils.isChangingToClosedWon(opportunity, oldRecordsMap.get(opportunity.Id)) 
                        && (opportunity.PotenciaNominalSistema__c == null  || opportunity.PotenciaNominalSistema__c < 300)
                        && OpportunityUtils.isRecordTypeSolar(opportunity) 
                    )
                    ||
                    (
                        OpportunityUtils.isChangingToAccessOpinion(opportunity, oldRecordsMap.get(opportunity.Id)) 
                        && (opportunity.PotenciaNominalSistema__c == null  || opportunity.PotenciaNominalSistema__c < 300)
                        && OpportunityUtils.isRecordTypeEzeeSolar(opportunity)
                    )
                ){
                    filteredOpportunities.put(opportunity.Id, opportunity);
                    accountIds.add(opportunity.AccountId);
                }
            }

            if(filteredOpportunities.keySet().isEmpty()) return;

            List<Contact> contacts = [SELECT Id, AccountId FROM Contact WHERE AccountId IN :accountIds ORDER BY CreatedDate DESC];

            if(contacts != null){
                for(Contact contact : contacts){
                    contactByAccountId.put(contact.AccountId, contact);
                }
            }

            List<Projeto__c> projects = [SELECT Id, Consultor__c, GestorObra__c, Oportunidade__c, ApprovalDate__c, InstallDate__c, DateInspection__c FROM Projeto__c WHERE Oportunidade__c IN :filteredOpportunities.keySet() ORDER BY CreatedDate ASC];

            //Considerando apenas um projeto por Oportunidade
            if(projects != null){
                for(Projeto__c project : projects){
                    projectByOpportunityId.put(project.Oportunidade__c, project);
                    projectIds.add(project.Id);
                }
            }

            if(!projectIds.isEmpty() || !filteredOpportunities.isEmpty()){
                for(Instalacao__c installation : [
                    SELECT  Id, Projeto__c, Oportunidade__c, GestorObra__c, InstallDate__c, DateInspection__c
                    FROM    Instalacao__c
                    WHERE   Projeto__c IN :projectIds
                        OR  Oportunidade__c IN :filteredOpportunities.keySet()
                ]){
                    if(installation.Projeto__c != null && !installationByProjectId.containsKey(installation.Projeto__c)){
                        installationByProjectId.put(installation.Projeto__c, installation);
                    }
                    if(installation.Oportunidade__c != null && !installationByOpportunityId.containsKey(installation.Oportunidade__c)){
                        installationByOpportunityId.put(installation.Oportunidade__c, installation);
                    }
                }
            }

            for(Opportunity opportunity : filteredOpportunities.values()){

                Contact contact = contactByAccountId.get(opportunity.AccountId);

                Projeto__c project = projectByOpportunityId.get(opportunity.Id);

                Instalacao__c installation = installationByProjectId.get(project?.Id);
                if(installation == null){
                    installation = installationByOpportunityId.get(opportunity.Id);
                }

                casesCustomerJourney.add(
                    buildCase(opportunity, project, installation, contact)
                );
            }

            if(!casesCustomerJourney.isEmpty())
                insert casesCustomerJourney;

        }catch(Exception ex){
            System.debug('##Erro ao criar Caso de Jornada do Cliente: ' + ex.getMessage());
            System.debug('##Stack: ' + ex.getStackTraceString());
            System.debug('##Line: ' + ex.getLineNumber());
        }
        
    }
    
    public static Case buildCase(Opportunity opportunity, Projeto__c project, Instalacao__c installation, Contact contact){

        List<Group> queueSupport = [
            SELECT Id 
            FROM Group 
            WHERE Type = 'Queue' AND DeveloperName = 'Suporte_Pos_Vendas'
            LIMIT 1
        ];

        Case caseRecord = new Case();
        caseRecord.Nome_da_Oportunidade__c = opportunity.Id;
        caseRecord.OwnerId = !queueSupport.isEmpty() ? queueSupport[0].Id : opportunity.OwnerId;
        caseRecord.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Jornada_do_Cliente').getRecordTypeId();
        caseRecord.Status = 'Novo';
        caseRecord.Subject = 'Jornada do Projeto';
        caseRecord.Description = 'Caso para acompanhamento da jornada do projeto.';
        caseRecord.AccountId = opportunity.AccountId;
        caseRecord.ContactId = contact != null ? contact.Id : null;
        if(project?.Consultor__c != null) caseRecord.Nome_do_Consultor__c = project.Consultor__c;
        if(installation?.GestorObra__c != null){
            caseRecord.ManagerName__c = installation.GestorObra__c;
        } else if(project?.GestorObra__c != null){
            caseRecord.ManagerName__c = project.GestorObra__c;
        }
        if(project?.ApprovalDate__c != null) caseRecord.ProjectApprovalDate__c = project.ApprovalDate__c;
        if(installation?.InstallDate__c != null){
            caseRecord.InstallDate__c = installation.InstallDate__c;
        } else if(project?.InstallDate__c != null){
            caseRecord.InstallDate__c = project.InstallDate__c;
        }
        if(installation?.DateInspection__c != null){
            caseRecord.DateInspection__c = installation.DateInspection__c;
        } else if(project?.DateInspection__c != null){
            caseRecord.DateInspection__c = project.DateInspection__c;
        }

        return caseRecord;
    }

    public static void sendClienteRecordToVirtualOffice(List<Opportunity> newRecordList, Map<Id, Opportunity> oldRecordsMap){
        Set<Id> accountIds = new Set<Id>();

        for(Opportunity opportunity : newRecordList){
            Opportunity oldOpportunity = oldRecordsMap.get(opportunity.Id);

            if (oldOpportunity == null) continue;

            if (opportunity.StageName == oldOpportunity.StageName) continue;

            Id opportunityId = opportunity.RecordTypeId;

            if (
                OpportunityUtils.isRecordTypeSolar(opportunity)
                || OpportunityUtils.isRecordTypeEzeeLivre(opportunity)
                || OpportunityUtils.isRecordTypeProdutos(opportunity)
                || OpportunityUtils.isRecordTypeServicos(opportunity)
                || OpportunityUtils.isRecordTypeServicosEPC(opportunity)
            ){
                if (OpportunityUtils.isStatusContract(opportunity)){
                    accountIds.add(opportunity.AccountId);
                }

            } else if (
                OpportunityUtils.isRecordTypeEzeeSolar(opportunity)
            ){
                if (OpportunityUtils.isStatusViabilityAnalysis(opportunity)){
                    accountIds.add(opportunity.AccountId);
                }

            } else if (
                OpportunityUtils.isRecordTypeEzeeConnect(opportunity)
            ){
                if (OpportunityUtils.isStatusValidation(opportunity)){
                    accountIds.add(opportunity.AccountId);
                }
            }

        }
        
        if(!accountIds.isEmpty()){
        	IntegracaoVOClientePreCadastro.sendCliente(accountIds);
        }

    }
    
    public static void addPlanToUserInVirtualOffice(List<Opportunity> newRecordList, Map<Id, Opportunity> oldRecordsMap){
        Set<Id> opportunityIds = new Set<Id>();
        
        Map<String, Id> recordTypeIds = new Map<String, Id>{
            'EzeeSolarB'    => Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('EzeeSolarB').getRecordTypeId()
        };

        for(Opportunity opportunity : newRecordList){
            Opportunity oldOpportunity = oldRecordsMap.get(opportunity.Id);

            if (oldOpportunity == null) continue;

            if (opportunity.StageName == oldOpportunity.StageName) continue;

            Id opportunityId = opportunity.RecordTypeId;

            if (OpportunityUtils.isStatusClosedWon(opportunity)){
                opportunityIds.add(opportunity.Id);

            } else if (OpportunityUtils.isStatusAccessOpinion(opportunity)){
                if (opportunityId == recordTypeIds.get('EzeeSolarB')){
                    opportunityIds.add(opportunity.Id);
                }
            }
            
        }
        
        if(!opportunityIds.isEmpty()){
        	IntegracaoVOPlano.sendPlano(opportunityIds);
        }

    }
    
    public static void controlsSubstatus(List<Opportunity> newRecordList, Map<Id, Opportunity> oldRecordsMap) {

        for (Opportunity opportunity : newRecordList) {
            Opportunity oldOpportunity = oldRecordsMap.get(opportunity.Id);

            if (oldOpportunity == null) continue;

            if (opportunity.StageName == null) continue;

            if (opportunity.StageName == oldOpportunity.StageName) continue;
            
            if (OpportunityUtils.isStatusChanging(opportunity, oldOpportunity)){
                if (OpportunityUtils.isStatusCommercialPresentation(opportunity)){
                    opportunity.Status__c = OpportunityUtils.SUB_STATUS_EM_AGENDAMENTO;

                } else if (OpportunityUtils.isStatusPaymentConfirmationSinal(opportunity)){
                    opportunity.Status__c = OpportunityUtils.SUB_STATUS_AGUARDANDO_PAGAMENTO;

                } else if (OpportunityUtils.isStatusViabilityAnalysis(opportunity)){
                    if(OpportunityUtils.isRecordTypeEzeeSolarA(opportunity)){
                        opportunity.Status__c =  OpportunityUtils.SUB_STATUS_AGUARDANDO_PAGAMENTO;
                    } else if ( ! OpportunityUtils.isRecordTypeEzeeSolarB(opportunity)){
                        opportunity.Status__c =  OpportunityUtils.SUB_STATUS_AGENDAMENTO_VISITA;
                    } else {
                        opportunity.Status__c = null;
                    }

                } else if (OpportunityUtils.isStatusAwaitingAcceptance(opportunity)){
                    opportunity.Status__c = OpportunityUtils.SUB_STATUS_EM_ANALISE;

                } else if (OpportunityUtils.isStatusContract(opportunity)){
                    opportunity.Status__c = OpportunityUtils.isRecordTypeEzeeSolarA(opportunity) ? OpportunityUtils.SUB_STATUS_AGUARDANDO_DOCUMENTOS : OpportunityUtils.SUB_STATUS_GERACAO_CONTRATO;

                } else if (OpportunityUtils.isStatusValidation(opportunity)){
                    opportunity.Status__c = OpportunityUtils.SUB_STATUS_EM_ANDAMENTO;
            
                } else if (OpportunityUtils.isStatusAccessOpinion(opportunity)){
                    opportunity.Status__c = OpportunityUtils.isRecordTypeSolar(opportunity) || OpportunityUtils.isRecordTypeProdutos(opportunity) ? OpportunityUtils.SUB_STATUS_FAST_TRACK : OpportunityUtils.SUB_STATUS_EM_ANALISE;

                } else if (OpportunityUtils.isStatusCompleted(opportunity)){
                    opportunity.Status__c = OpportunityUtils.SUB_STATUS_VALIDANDO_BONIFICACAO;

                } else if (OpportunityUtils.isStatusEquipment(opportunity)){
                    opportunity.Status__c = OpportunityUtils.SUB_STATUS_ENTREGA_DE_MATERIAIS;

                } else if (OpportunityUtils.isStatusInstallation(opportunity)){
                    opportunity.Status__c = OpportunityUtils.SUB_STATUS_EM_INSTALACAO;

                } else if (OpportunityUtils.isStatusClosedWon(opportunity)){
                    opportunity.Status__c = OpportunityUtils.SUB_STATUS_GANHO;

                } else if (OpportunityUtils.isStatusClosedLost(opportunity)){
                    opportunity.Status__c = OpportunityUtils.SUB_STATUS_PERDIDO;

                } else {
                    opportunity.Status__c = null;
                }
            } else {
                opportunity.Status__c = null;
            }

        }
    }

    public static void sendProposalValueUpdate(List<Opportunity> newRecordList, Map<Id, Opportunity> oldRecordsMap) {
        for (Opportunity opportunity : newRecordList) {
            System.debug('sendProposalValueUpdate: ' + opportunity.Id);
            Set<Id> opportunityIds = new Set<Id>();

            Opportunity oldOpportunity = oldRecordsMap.get(opportunity.Id);

            if (oldOpportunity == null) continue;
            System.debug('sendProposalValueUpdate: ' + opportunity.Id);
            System.debug('Old Value: ' + oldOpportunity.ValorTotalProposta__c);
            System.debug('New Value: ' + opportunity.ValorTotalProposta__c);
            
            if ((opportunity.ValorTotalProposta__c == oldOpportunity.ValorTotalProposta__c)){
                continue;
            } else {
                opportunityIds.add(opportunity.Id);
            }

            if (!opportunityIds.isEmpty()) {
                ProposalService.updateOpportunityPhase(opportunityIds);

                if (    
                    opportunity.RecordTypeId == Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('EzeeConnect').getRecordTypeId()
                    || opportunity.RecordTypeId == Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId()
                ){
                    opportunity.PropostaAlterada__c = true;
                    // PDFControllerExtension.savePdfFileAsync(opportunity.Id);
                }

            }
        }
    }

    public static void sendAprovalUpdate(List<Opportunity> newRecordList, Map<Id, Opportunity> oldRecordsMap) {

        for(Opportunity opportunity: newRecordList) {
            Opportunity oldOpportunity = oldRecordsMap.get(opportunity.Id);

            if(opportunity.StatusAprovacaoDesconto__c != oldOpportunity.StatusAprovacaoDesconto__c) {
                System.debug('sendAprovalUpdate: ' + opportunity.Id);
                System.debug('Old Status: ' + oldOpportunity.StatusAprovacaoDesconto__c);
                System.debug('New Status: ' + opportunity.StatusAprovacaoDesconto__c);
                if(opportunity.StatusAprovacaoDesconto__c != oldOpportunity.StatusAprovacaoDesconto__c) {
                    IntegracaoNivelloAprovacaoDesconto.enviarStatusAprovacaoDesconto(new Set<Id>{opportunity.Id});
                }
            }
        }
    }

    public static void handleOpportunityLeadConversion(List<Opportunity> opportunityList, Map<Id, Opportunity> oldRecordsMap) {
        Set<Id> leadIds = new Set<Id>();
        for (Opportunity opp : opportunityList) {
            if (!String.isBlank(opp.Lead__c)) { // adjust field name if different
                leadIds.add(opp.Lead__c);
            }
        }

        if (leadIds.isEmpty()) return;

        Map<Id, Lead> leadMap = new Map<Id, Lead>(
            [SELECT Id, Status, ConvertedAccountId, ConvertedOpportunityId
            FROM Lead
            WHERE Id IN :leadIds]
        );
        System.debug('Found ' + leadMap.size() + ' related Leads.');

        List<Lead> leadsToUpdate = new List<Lead>();
        List<Database.LeadConvert> leadConverts = new List<Database.LeadConvert>();

        for (Opportunity opp : opportunityList) {
            Opportunity oldOpp = oldRecordsMap.get(opp.Id);
            if (oldOpp == null) continue;

            String stageName = opp.StageName;
            String leadId = opp.Lead__c;
            if (String.isBlank(leadId)) continue;

            Lead relatedLead = leadMap.get(leadId);
            if (relatedLead == null) continue;
            System.debug('stageName ' + stageName + ' ');

            // ---- Stage: Ganho Fechado → Convert Lead ----
            if (stageName == 'Ganho fechado' && oldOpp.StageName != 'Ganho fechado') {
                Database.LeadConvert lc = new Database.LeadConvert();
                lc.setLeadId(leadId);
                if (!String.isBlank(opp.AccountId)) lc.setAccountId(opp.AccountId);
                lc.setDoNotCreateOpportunity(false); // allow linking to existing Opportunity
                lc.setOpportunityId(opp.Id);
                lc.setConvertedStatus('Qualified'); // <-- Must match an existing Lead Status
                leadConverts.add(lc);
            }

            // ---- Stage: Ganho Perdido → Update Lead ----
            else if (stageName == 'Ganho Perdido' && oldOpp.StageName != 'Ganho Perdido') {
                Lead l = new Lead(Id = leadId, Status = 'Não Qualificado');
                leadsToUpdate.add(l);
            }
        }

        // 5️⃣ Execute bulk operations
        if (!leadConverts.isEmpty()) {
            List<Database.LeadConvertResult> results = Database.convertLead(leadConverts, false);
            for (Database.LeadConvertResult res : results) {
                if (!res.isSuccess()) {
                    System.debug('⚠️ Lead conversion failed: ' + res.getErrors());
                }
            }
        }

        if (!leadsToUpdate.isEmpty()) {
            try {
                update leadsToUpdate;
            } catch (Exception e) {
                System.debug('⚠️ Error updating Leads: ' + e.getMessage());
            }
        }
    }


    public static void closeActivitiesAndFlowsForClosedLost(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecordsMap) {
        if (newRecords == null || newRecords.isEmpty() || oldRecordsMap == null || oldRecordsMap.isEmpty()) {
            return;
        }

        Set<Id> closedLostOpportunityIds = new Set<Id>();
        Map<Id, Opportunity> closedLostOpportunities = new Map<Id, Opportunity>();

        for (Opportunity opportunity : newRecords) {
            Opportunity oldOpportunity = oldRecordsMap.get(opportunity.Id);
            if (oldOpportunity == null) {
                continue;
            }

            if (OpportunityUtils.isStatusClosedLost(opportunity) && !OpportunityUtils.isStatusClosedLost(oldOpportunity)) {
                closedLostOpportunityIds.add(opportunity.Id);
                closedLostOpportunities.put(opportunity.Id, opportunity);
            }
        }

        if (closedLostOpportunityIds.isEmpty()) {
            return;
        }

        final String AUTOMATION_NOTE = 'Encerrado automaticamente - Oportunidade marcada como Fechado Perdido.';

        List<Task> tasksToUpdate = new List<Task>();
        List<Projeto__c> projectsToUpdate = new List<Projeto__c>();
        List<ViabilityStudy__c> viabilityToUpdate = new List<ViabilityStudy__c>();
        Set<Id> usersToNotify = new Set<Id>();
        Set<Id> recordIdsToCloseTasks = new Set<Id>(closedLostOpportunityIds);

        Map<String, Schema.SObjectField> projectFields = Schema.SObjectType.Projeto__c.fields.getMap();
        Schema.SObjectField projectDescriptionField = projectFields.containsKey('Description__c')
            ? projectFields.get('Description__c')
            : null;

        for (Opportunity opportunity : closedLostOpportunities.values()) {
            if (opportunity.OwnerId != null) {
                usersToNotify.add(opportunity.OwnerId);
            }
        }

        List<String> opportunityIdStrings = new List<String>();
        for (Id oppId : closedLostOpportunityIds) {
            opportunityIdStrings.add('\'' + String.valueOf(oppId) + '\'');
        }

        String projectQuery = 'SELECT Id, Status__c, GestorObra__c';
        if (projectDescriptionField != null) {
            projectQuery += ', Description__c';
        }
        projectQuery += ' FROM Projeto__c WHERE Oportunidade__c IN (' + String.join(opportunityIdStrings, ',') + ')';

        for (Projeto__c project : Database.query(projectQuery)) {
            if (project.Status__c == null || project.Status__c != 'Projeto cancelado') {
                project.Status__c = 'Projeto cancelado';
            }
            if (projectDescriptionField != null) {
                String currentDescription = (String) project.get(projectDescriptionField);
                project.put(
                    projectDescriptionField,
                    appendAutomationNote(currentDescription, AUTOMATION_NOTE, 255)
                );
            }
            projectsToUpdate.add(project);
            recordIdsToCloseTasks.add(project.Id);

            if (project.GestorObra__c != null) {
                usersToNotify.add(project.GestorObra__c);
            }
        }

        for (ViabilityStudy__c viability : [
            SELECT  Id, StatusFeasibility__c, ObservationsPostVisit__c, OwnerId
            FROM    ViabilityStudy__c
            WHERE   Opportunity__c IN :closedLostOpportunityIds
        ]) {
            if (viability.StatusFeasibility__c == null || viability.StatusFeasibility__c != 'Viabilidade Finalizada') {
                viability.StatusFeasibility__c = 'Viabilidade Finalizada';
            }
            viability.ObservationsPostVisit__c = appendAutomationNote(viability.ObservationsPostVisit__c, AUTOMATION_NOTE, 131072);
            viabilityToUpdate.add(viability);
            recordIdsToCloseTasks.add(viability.Id);

            if (viability.OwnerId != null) {
                usersToNotify.add(viability.OwnerId);
            }
        }

        for (Task task : [
            SELECT  Id, Status, Description, OwnerId, WhatId
            FROM    Task
            WHERE   WhatId IN :recordIdsToCloseTasks
                AND Status != :TaskUtils.STATUS_CONCLUIDO
        ]) {
            task.Status = TaskUtils.STATUS_CONCLUIDO;
            task.Description = appendAutomationNote(task.Description, AUTOMATION_NOTE, 32000);
            tasksToUpdate.add(task);

            if (task.OwnerId != null) {
                usersToNotify.add(task.OwnerId);
            }
        }

        if (!tasksToUpdate.isEmpty()) {
            update tasksToUpdate;
        }
        if (!projectsToUpdate.isEmpty()) {
            update projectsToUpdate;
        }
        if (!viabilityToUpdate.isEmpty()) {
            update viabilityToUpdate;
        }
        Boolean orgType = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;

        if(!orgType){
            sendClosedLostAutomationEmail(closedLostOpportunities.values(), usersToNotify, AUTOMATION_NOTE);
        }
    }


    //fields are != null
    public static Boolean areRequiredFieldsFilled(Opportunity opp) {
        return
            opp.PotenciaPicoSistema__c != null &&
            opp.ValidadeProposta__c != null &&
            opp.ConsumoAnual__c != null &&
            opp.GrupoTarifario__c != null &&
            opp.CustoMedioEnergia__c != null &&
            opp.NumeroModulos__c != null &&
            opp.FabricanteModulos__c != null &&
            opp.Modelo__c != null &&
            opp.PotenciaNominalWp__c != null &&
            opp.Pesokg__c != null &&
            opp.NumeroInversores__c != null &&
            opp.FabricanteInversor__c != null &&
            opp.ModeloInversor__c != null &&
            opp.PotenciaNominalSistema__c != null &&
            opp.GeracaoAnualEstimada__c != null &&
            opp.GeracaoMensalEstimada__c != null &&
            opp.PaybackAnos__c != null &&
            opp.EconomiaMensalEstimada__c != null &&
            opp.EconomiaAnualEstimada__c != null &&
            opp.EconomiaAcumulada__c != null &&
            opp.TipoTelhadoEstrutura__c != null &&
            opp.AreaM__c != null &&
            opp.PrazoEntregaDias__c != null &&
            opp.Amount != null;
    }

        //fields are != null
    public static Boolean areRequiredFieldsFilledConnect(Opportunity opp) {
        return
            opp.FaturaDescontoFixo__c != null &&
            opp.EconomiaXMesesFixa__c != null &&
            opp.PrazoContratoParceiro__c != null ;
    }
    

    public static Boolean formulaFieldsChanged(Opportunity oldOpp, Opportunity newOpp) {
        // A verificação de campos de fórmula em 'after update' deve ser feita nos campos de origem,
        // pois os campos de fórmula em Trigger.old são recalculados e refletem os novos valores.
        // Esta lista deve conter os NOMES dos campos que compõem as fórmulas.
        String[] sourceFields = new String[]{
            'CustoFinanceiroWeg__c', 'CustoAdicionalFixo__c', 'ValorInstalacao__c', 
            'Rede3750__c', 'Pontos__c', 'Acoplamento__c', 'BDI__c', 
            'ValorTotalProdutos__c', 'Direct__c', 'StatusAprovacaoDesconto__c'
        };

        for (String fieldName : sourceFields) {
            if (oldOpp.get(fieldName) != newOpp.get(fieldName)) {
                System.debug(fieldName + ' changed: ' + oldOpp.get(fieldName) + ' -> ' + newOpp.get(fieldName));
                return true; // Retorna true na primeira alteração encontrada
            }
        }

        System.debug('No formula source fields changed between oldOpp and newOpp.');
        return false;
    }

    public Static void updateApproveComment(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecordsMap) {
        for( Opportunity opportunity : newRecords) {
            Opportunity oldOpportunity = oldRecordsMap.get(opportunity.Id);
            if(OpportunityUtils.hasDiscountApprovalStatusChangedToApprovedOrRejected(opportunity, oldOpportunity)){
                opportunity.ObservacaoAprovacao__c = OpportunityUtils.getApproveComment(opportunity);
            }
        }
        
    }

    private static String appendAutomationNote(String currentValue, String note, Integer maxLength) {
        if (String.isBlank(note) || maxLength == null || maxLength <= 0) {
            return currentValue;
        }

        if (String.isBlank(currentValue)) {
            return note.length() > maxLength ? note.substring(0, maxLength) : note;
        }

        if (currentValue.contains(note)) {
            return currentValue;
        }

        String separator = currentValue.endsWith('.') ? ' ' : ' | ';
        String candidate = currentValue + separator + note;

        return candidate.length() > maxLength ? candidate.substring(0, maxLength) : candidate;
    }


    private static void sendClosedLostAutomationEmail(List<Opportunity> opportunities, Set<Id> userIds, String note) {
        if (opportunities == null || opportunities.isEmpty() || userIds == null || userIds.isEmpty()) {
            return;
        }

        List<User> users = [
            SELECT  Id, Email
            FROM    User
            WHERE   Id IN :userIds
                AND Email != null
        ];

        if (users.isEmpty()) {
            return;
        }

        List<String> recipientEmails = new List<String>();
        for (User userRecord : users) {
            if (!String.isBlank(userRecord.Email)) {
                recipientEmails.add(userRecord.Email);
            }
        }

        if (recipientEmails.isEmpty() || Test.isRunningTest()) {
            return;
        }

        if (recipientEmails.size() > 100) {
            List<String> limitedRecipients = new List<String>();
            for (Integer index = 0; index < 100; index++) {
                limitedRecipients.add(recipientEmails[index]);
            }
            recipientEmails = limitedRecipients;
        }

        String body = 'Olá,<br/><br/>' +
            'As seguintes oportunidades foram atualizadas para o estágio &quot;Fechado Perdido&quot; ' +
            'e tiveram suas atividades relacionadas encerradas automaticamente:<br/><ul>';

        for (Opportunity opportunity : opportunities) {
            String opportunityLink = URL.getSalesforceBaseUrl().toExternalForm() + '/' + opportunity.Id;
            body += '<li><a href=&quot;' + opportunityLink + '&quot;>' + opportunity.Name + '</a></li>';
        }

        body += '</ul><br/>' + note;

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(recipientEmails);
        email.setSubject('Encerramento automático de atividades - Fechado Perdido');
        email.setHtmlBody(body);

        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    }

}
