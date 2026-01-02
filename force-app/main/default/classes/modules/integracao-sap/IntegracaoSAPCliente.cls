/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 11-12-2025
 * @last modified by  : Daniel Belini
**/
public with sharing class IntegracaoSAPCliente {
    @future(callout=true)
    public static void sendCliente(Set<Id> triggerIds){
        List<Account> accountList = [
            SELECT  Id, IdVirtualOffice__c, CPF__c, CNPJ__c, Description, SeCPFouCNPJ__c, Name, Type, Email__c,
                    Phone, BillingStreet, BillingPostalCode, BillingCity, BillingCountry,
                    BillingState, BillingAddress, BairroCobranca__c, MunicipioCobranca__c, 
                    ComplementoCobranca__c, NumeroRuaCobranca__c, 
                    ShippingStreet, ShippingPostalCode, ShippingCity, ShippingCountry,
                    ShippingState, ShippingAddress, BairroEntrega__c, 
                    MunicipioEntrega__c, ComplementoEntrega__c, NumeroRuaEntrega__c,
                    SucessoIntegracaoSAP__c, StatusBodyIntegracaoSAP__c
            FROM    Account
            WHERE   Id IN :triggerIds
        ];

        Map<String, String> stateNameToAbbreviation = new Map<String, String>{
            'Acre'                => 'AC',
            'Alagoas'             => 'AL',
            'Amapá'               => 'AP',
            'Amazonas'            => 'AM',
            'Bahia'               => 'BA',
            'Ceará'               => 'CE',
            'Distrito Federal'    => 'DF',
            'Espírito Santo'      => 'ES',
            'Goiás'               => 'GO',
            'Maranhão'            => 'MA',
            'Mato Grosso'         => 'MT',
            'Mato Grosso do Sul'  => 'MS',
            'Minas Gerais'        => 'MG',
            'Pará'                => 'PA',
            'Paraíba'             => 'PB',
            'Paraná'              => 'PR',
            'Pernambuco'          => 'PE',
            'Piauí'               => 'PI',
            'Rio de Janeiro'      => 'RJ',
            'Rio Grande do Norte' => 'RN',
            'Rio Grande do Sul'   => 'RS',
            'Rondônia'            => 'RO',
            'Roraima'             => 'RR',
            'Santa Catarina'      => 'SC',
            'São Paulo'           => 'SP',
            'Sergipe'             => 'SE',
            'Tocantins'           => 'TO'
        };


        for(Account acc : accountList){
            String formattedBillingState = acc.BillingState;
            if(acc.BillingState != null && acc.BillingState?.length() != 2){
                formattedBillingState = stateNameToAbbreviation.get(acc.BillingState);
            }

            String formattedShippingState = acc.ShippingState;
            if(acc.ShippingState != null && acc.ShippingState?.length() != 2){
                formattedShippingState = stateNameToAbbreviation.get(acc.ShippingState);
            }

            String formattedBillingCountry = acc.BillingCountry;
            if(acc.BillingCountry != null && acc.BillingCountry.equalsIgnoreCase('Brasil')){
                formattedBillingCountry = 'BR';
            }

            String formattedShippingCountry = acc.ShippingCountry;
            if(acc.ShippingCountry != null && acc.ShippingCountry.equalsIgnoreCase('Brasil')){
                formattedShippingCountry = 'BR';
            }
            
            ClienteRequest corpoRequisicao = new ClienteRequest();
            corpoRequisicao.CardCode       = acc.SeCPFouCNPJ__c;
            corpoRequisicao.CardName       = acc.Name;
            corpoRequisicao.CardType       = 'cCustomer';
            corpoRequisicao.EmailAddress   = acc.Email__c;
            corpoRequisicao.Phone1         = acc.Phone;
            corpoRequisicao.FederalTaxID   = acc.SeCPFouCNPJ__c;
            corpoRequisicao.BPAddresses    = new BPAddress[]{};
            corpoRequisicao.BPFiscalTaxIDCollection  = new BPFiscalTaxID[]{};


            if(acc.BillingAddress != null){
                BPAddress bpAddress         = new BPAddress();
                bpAddress.AddressName       = 'Endereço cobrança';
                bpAddress.Street            = acc.BillingStreet;
                bpAddress.Block             = acc.BairroCobranca__c;
                bpAddress.ZipCode           = acc.BillingPostalCode;
                bpAddress.City              = acc.BillingCity;
                bpAddress.County            = acc.BillingCity;
                bpAddress.Country           = formattedBillingCountry;
                bpAddress.State             = formattedBillingState;
                bpAddress.BuildingFloorRoom = acc.ComplementoCobranca__c != null ? acc.ComplementoCobranca__c : '';
                bpAddress.AddressType       = 'bo_BillTo';
                bpAddress.StreetNo          = acc.NumeroRuaCobranca__c;
                bpAddress.BPCode            = acc.SeCPFouCNPJ__c;
                bpAddress.RowNum            = 0;


                corpoRequisicao.BPAddresses.add(bpAddress);
            }

            if(acc.ShippingAddress != null){
                BPAddress bpAddress         = new BPAddress();
                bpAddress.AddressName       = 'Endereço entrega';
                bpAddress.Street            = acc.ShippingStreet;
                bpAddress.Block             = acc.BairroEntrega__c;
                bpAddress.ZipCode           = acc.ShippingPostalCode;
                bpAddress.City              = acc.ShippingCity;
                bpAddress.County            = acc.BillingCity;
                bpAddress.Country           = formattedShippingCountry;
                bpAddress.State             = formattedShippingState;
                bpAddress.BuildingFloorRoom = acc.ComplementoEntrega__c != null ? acc.ComplementoEntrega__c : '';
                bpAddress.AddressType       = 'bo_ShipTo';
                bpAddress.StreetNo          = acc.NumeroRuaEntrega__c;
                bpAddress.BPCode            = acc.SeCPFouCNPJ__c;
                bpAddress.RowNum            = 1;

                corpoRequisicao.BPAddresses.add(bpAddress);
            }

            BPFiscalTaxID BPTaxID = new BPFiscalTaxID();
            if(acc.CPF__c != null){
                BPTaxID.TaxID0 = acc.SeCPFouCNPJ__c;
            } else if(acc.CNPJ__c != null){
                BPTaxID.TaxID4 = acc.SeCPFouCNPJ__c;
            }
            corpoRequisicao.BPFiscalTaxIDCollection.add(BPTaxID);

            try{
                System.debug('Corpo Requisicao: ' + JSON.serialize(corpoRequisicao));
                HttpResponse response = chamadaIntegracao(JSON.serialize(corpoRequisicao), 'ClienteSAP');
                Utils.createLog('IntegracaoSAPCliente', 'sendCliente ' + acc.Id, response);

                if(response.getBody() != null && response.getBody() != ''){
                    Integer[] successSAPResponseCodes = new Integer[]{200, 201, 204};

                    Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                    Integer statusCode = Integer.valueOf(responseBody.get('codigoHttp'));

                    //Sucesso
                    if(successSAPResponseCodes.contains(statusCode)){   
                        
                        System.debug('SUCCESS');
                        acc.SucessoIntegracaoSAP__c = true;
                    }
                    //Erro
                    else{
                    System.debug('ERROR');
                    acc.SucessoIntegracaoSAP__c = false;
                    
                    }
                    acc.StatusBodyIntegracaoSAP__c = statusCode + ' ' + response.getBody() + ' ' + response.getStatus();
                }
            } catch (Exception e){
                Utils.createLog('IntegracaoSAPCliente', 'sendCliente ' + acc.Id, e);
                
                acc.SucessoIntegracaoSAP__c = false;
                acc.StatusBodyIntegracaoSAP__c = e.getMessage() + ' ' + e.getStackTraceString();
            }
        }

        AccountTriggerHandler.disableTrigger();
        update accountList;
        AccountTriggerHandler.enableTrigger();
    }

    private static HttpResponse chamadaIntegracao(String body, String endpointName){
        Integrador__mdt parametrosIntegracao = [
            SELECT  Id, URL__c
            FROM    Integrador__mdt 
            WHERE   DeveloperName = :endpointName
        ];
        
        String tokenSAP = [
            SELECT  Id, LastToken__c
            FROM    Integrador__mdt 
            WHERE   DeveloperName = 'TokenSAP'
        ].LastToken__c;

        Http httpObj = new Http();
        HttpRequest request = new HttpRequest();
        
        request.setEndpoint(parametrosIntegracao.URL__c);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Authorization', 'Bearer ' + tokenSAP);
        request.setBody(body);
        
        return Utils.callIntegrationSAP(request);
    }

    public class ClienteRequest{
        public String      CardCode;     // ID externo (CPF) - "1234"
        public String      CardName;     // Nome - "Cliente atualizado pela API"
        public String      CardType;     // Tipo de pessoa, deve ser cCustomer para clientes - "cCustomer"
        public String      EmailAddress; // Email - "email@teste.com"
        public String      Phone1;       // Telefone do cliente - "11111111"
        public String      FederalTaxID; // Documento do cliente - "453125241"
        public BPAddress[] BPAddresses;
        public BPFiscalTaxID[] BPFiscalTaxIDCollection;
    }

    public class BPAddress{
        public String  AddressName;       // Apelido do endereço - "Endereco entrega",
        public String  Street;            // Rua - "AV. Teste N° 628",
        public String  Block;             // Bairro - "bairro teste",
        public String  ZipCode;           // CEP - "05651-901",
        public String  City;              // Cidade - "SÃO PAULO",
        public String  County;            // Município - null,
        public String  Country;           // Sigla do País - "BR",
        public String  State;             // Sigla do Estado - "SP",
        public String  BuildingFloorRoom; // Complemento - "123",
        public String  AddressType;       // Tipo do endereço, bo_BillTo para cobrança e bo_ShipTo para entrega - "bo_BillTo",
        public String  StreetNo;          // Número da casa - "628",
        public String  BPCode;            // Chave externa do cliente - "1234",
        public Integer RowNum;            // Sequencial gerado automaticamente, começa em zero - 0
    }

    public class BPFiscalTaxID{
        public String TaxID0;             // CNPJ do Cliente, se houver  
        public String TaxID4;             // CPF do Cliente, se houver  
    }
}