@isTest 
public class OpportunityEntryRestTest {
    @TestSetup
    public static void makeData(){
        Consultor__c seller = (Consultor__c) TestFactory.createSObject(new Consultor__c(), true);
    }
    
    @isTest
    public static void testCallout() {
        Consultor__c seller = [
            SELECT  Id, IdVirtualOffice__c
            FROM    Consultor__c
            LIMIT   1
        ];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/OpportunityEntry/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(
            '{' +
            '    "SingleOpportunity":[' +
            '        {' +
            '            "Id": "c558705a-asdsadd-41d8-b711-454545",' +
            '            "SellerId": "'+ seller.IdVirtualOffice__c +'",' +
            '            "ConsumptionAverage": 200.0,' +
            '            "TargetConsume": 180.0,' +
            '            "PercentageIncreaseInConsumption": 20.0,' +
            '            "PowerDistributionCompany": "Copel",' +
            '            "ZipCode": "82560000",' +
            '            "MaxPowerSystem": 2.07,' +
            '            "QuantityModules": 6,' +
            '            "DynamicTechnicalProposal": "<p>Olá Lionel Tudo bem?</p><p>Messi</p><p>96474032324</p><p>419999999999</p><p>24.January.2022</p><p>82560000</p><p>Paraná</p><p>20</p><p>345 Wp - TRINA</p><p>Direta</p><p>Copel</p><p>Solo</p>",' +
            '            "SaleType": "Normal",' +
            '            "CloseDate":"2023-03-27",' +
            '            "RecordTypeId": "' + 
                        Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId() + '",' +
            '            "Products": [' +
            '                    {' +
            '                            "Id": 9,' +
            '                            "Name": "Modulo - 345 Wp - TRINA",' +
            '                            "UnitaryValue": 1461.99,' +
            '                            "Quantity": 1' +
            '                    },' +
            '                    {' +
            '                            "Id": 4664,' +
            '                            "Name": "Inversor - SIW600 T020-44",' +
            '                            "UnitaryValue": 499.99,' +
            '                            "Quantity": 3' +
            '                    },' +
            '                    {' +
            '                            "Id": 8741,' +
            '                            "Name": "Cabo CC Unipolar - Flexível NH 6 mm² Preto",' +
            '                            "UnitaryValue": 50.99,' +
            '                            "Quantity": 10' +
            '                    },' +
            '                    {' +
            '                            "Id": 10,' +
            '                            "Name": "Garantia estendida - +5 anos SIW500H ST100 HV",' +
            '                            "UnitaryValue": 980.99,' +
            '                            "Quantity": 1' +
            '                    }' +
            '            ],' +
            '            "Client": {' +
            '                    "Id": "c4df3b76-0648-422a-8d43-89798797",' +
            '                    "UserType": 1,' +
            '                    "Name": "Lionel",' +
            '                    "LastName": "Messi",' +
            '                    "CorporateName": "aaaaaaaa",' +
            '                    "Email": "llionel@enerzee.com",' +
            '                    "Document": "34737518808",' +
            '                    "CellPhone": "419999999999",' +
            '                    "RegisterDate": "2022-01-01T00:00:00",' +
            '                    "ModifiedDate": "2022-06-03T13:08:29",' +
            '                    "Procurator": "Lionel Andrés Messi Cuccittini",' +
            '                    "ProcuratorPhone": "41988888888",' +
            '                    "ProcuratorEmail": "lionel@gmail.com",' +
            '                    "ProcuratorRegisterNumber": "99999999999",' +
            '                    "RecordTypeId": "' + Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('ClientePessoaFisica').getRecordTypeId() + '",' +
            '                    "BillingCity": "Sao Paulo",' +
            '                    "BillingStreet" : "R. Joao Alves",' +
            '                    "BillingCountry": "Brasil",' +
            '                    "BillingState": "SP",' +
            '                    "BillingPostalCode": "02925130",' +
            '                    "Complemento" : "186"' +
            '            }' +
            '        },' +
            '        {' +
            '            "Id": "c558705a-adasdasd-41d8-b711-656565",' +
            '            "SellerId": "'+ seller.IdVirtualOffice__c +'",' +
            '            "ConsumptionAverage": 200.0,' +
            '            "TargetConsume": 180.0,' +
            '            "PercentageIncreaseInConsumption": 20.0,' +
            '            "PowerDistributionCompany": "Copel",' +
            '            "ZipCode": "82560000",' +
            '            "MaxPowerSystem": 2.07,' +
            '            "QuantityModules": 6,' +
            '            "DynamicTechnicalProposal": "<p>Olá Lionel Tudo bem?</p><p>Messi</p><p>96474032324</p><p>419999999999</p><p>24.January.2022</p><p>82560000</p><p>Paraná</p><p>20</p><p>345 Wp - TRINA</p><p>Direta</p><p>Copel</p><p>Solo</p>",' +
            '            "SaleType": "Normal",' +
            '            "CloseDate":"2023-03-27",' +
            '            "RecordTypeId": "' + 
                        Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId() + '",' +
            '            "Products": [' +
            '                    {' +
            '                            "Id": 2,' +
            '                            "Name": "Modulo - 345 Wp - TRINA",' +
            '                            "UnitaryValue": 1461.99,' +
            '                            "Quantity": 1' +
            '                    },' +
            '                    {' +
            '                            "Id": 3,' +
            '                            "Name": "Inversor - SIW600 T020-44",' +
            '                            "UnitaryValue": 499.99,' +
            '                            "Quantity": 3' +
            '                    },' +
            '                    {' +
            '                            "Id": 4,' +
            '                            "Name": "Cabo CC Unipolar - Flexível NH 6 mm² Preto",' +
            '                            "UnitaryValue": 50.99,' +
            '                            "Quantity": 10' +
            '                    },' +
            '                    {' +
            '                            "Id": 5,' +
            '                            "Name": "Garantia estendida - +5 anos SIW500H ST100 HV",' +
            '                            "UnitaryValue": 980.99,' +
            '                            "Quantity": 1' +
            '                    }' +
            '            ],' +
            '            "Client": {' +
            '                    "Id": "c4df3b76-0648-422a-8d43-64654654",' +
            '                    "UserType": 1,' +
            '                    "Name": "Lionel",' +
            '                    "LastName": "Messi",' +
            '                    "CorporateName": "Razao Social",' +
            '                    "Email": "llionel@enerzee.com",' +
            '                    "Document": "12345678901234",' +
            '                    "CellPhone": "419999999999",' +
            '                    "RegisterDate": "2022-01-01T00:00:00",' +
            '                    "ModifiedDate": "2022-06-03T14:08:29",' +
            '                    "Procurator": "Lionel Andrés Messi Cuccittini",' +
            '                    "ProcuratorPhone": "41988888888",' +
            '                    "ProcuratorEmail": "lionel@gmail.com",' +
            '                    "ProcuratorRegisterNumber": "99999999999",' +
            '                    "RecordTypeId": "' + Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('ClientePessoaJuridica').getRecordTypeId() + '",' +
            '                    "BillingCity": "Sao Paulo",' +
            '                    "BillingStreet" : "R. Joao Alves",' +
            '                    "BillingCountry": "Brasil",' +
            '                    "BillingState": "SP",' +
            '                    "BillingPostalCode": "02925130",' +
            '                    "Complemento" : "186"' +
            '            }' +
            '        }' +
            '    ]' +
            '}'
        );
        
        RestContext.request = req;
        RestContext.response = res;

        OpportunityEntryRest.makePost();

        // Clientes (Account)
        List<Account> accounts = new List<Account>();
        Set<Id> accountIds = new Set<Id>();
        for(Account account : [
            SELECT  Id
            FROM    Account
        ]){
            accounts.add(account);
            accountIds.add(account.Id);
        }

        // Validar inserção dos clientes
        System.assert(!accounts.isEmpty());
        System.assertEquals(2, accounts.size());


        // Oportunidades (Opportunity)
        List<Opportunity> opportunities = new List<Opportunity>();
        Set<Id> opportunityIds = new Set<Id>();
        for(Opportunity opportunity : [
            SELECT  Id, ConsultorOportunidade__c, AccountId
            FROM    Opportunity
        ]){
            opportunities.add(opportunity);
            opportunityIds.add(opportunity.Id);

            // Validar clientes atribuídos
            //System.assert(accountIds.contains(opportunity.AccountId));

            // Validar consultor atribuído
            System.assertEquals(seller.Id, opportunity.ConsultorOportunidade__c);
        }

        // Validar inserção das oportunidades
        System.assert(!opportunities.isEmpty());
        System.assertEquals(2, opportunities.size());


        // Produtos (Product2)
        List<Product2> products = new List<Product2>();
        Set<Id> productIds = new Set<Id>();
        for(Product2 product : [
            SELECT  Id
            FROM    Product2
        ]){
            products.add(product);
            productIds.add(product.Id);
        }

        // Validar inserção dos produtos
        System.assert(!products.isEmpty());
        System.assertEquals(8, products.size());

        
        // Produtos da Oportunidade (OpportunityLineItem)
        List<OpportunityLineItem> items = new List<OpportunityLineItem>();
        for(OpportunityLineItem item : [
            SELECT  Id, Product2Id, OpportunityId
            FROM    OpportunityLineItem
        ]){
            items.add(item);

            // Validar oportunidades atribuídas
            System.assert(opportunityIds.contains(item.OpportunityId));
        }

        // Validar inserção dos produtos
        System.assert(!items.isEmpty());
        System.assertEquals(8, items.size());


        // Entradas do Catálogo de Preços (PricebookEntry)
        List<PricebookEntry> entries = new List<PricebookEntry>();
        for(PricebookEntry entry : [
            SELECT  Id, Product2Id, Pricebook2Id
            FROM    PricebookEntry
        ]){
            entries.add(entry);

            // Validar produtos atribuídos
            System.assert(productIds.contains(entry.Product2Id));

            // Validar catálogo de preços padrão
            System.assertEquals(Test.getStandardPricebookId(), entry.Pricebook2Id);
        }

        // Validar inserção dos produtos
        System.assert(!entries.isEmpty());
        System.assertEquals(8, entries.size());

    }
}