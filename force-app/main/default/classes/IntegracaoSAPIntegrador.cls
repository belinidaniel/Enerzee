public with sharing class IntegracaoSAPIntegrador {
    @future(callout=true)
    public static void sendIntegrador(Set<Id> triggerIds){
        List<Integradores__c> IntegradorList = [
            SELECT  Id, CPF__c, CNPJ__c, SeCPFouCNPJ__c, Name, Email__c,
                    Telefone__c,  CEP__c, Cidade__c,
                    Estado__c, Bairro__c,RazaoSocial__c,
                    Logradouro__c,Complemento__c, Conta__c, Agencia__c, Banco__c
            FROM    Integradores__c
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


        for(Integradores__c integrador : IntegradorList){
            String formattedEstadoCobranca = integrador.Estado__c;
            if(integrador.Estado__c != null && integrador.Estado__c?.length() != 2){
                formattedEstadoCobranca = stateNameToAbbreviation.get(integrador.Estado__c);
            }

            String formattedEstadoEntrega = integrador.Estado__c;
            if(integrador.Estado__c != null && integrador.Estado__c?.length() != 2){
                formattedEstadoEntrega = stateNameToAbbreviation.get(integrador.Estado__c);
            }

            String formattedBillingCountry;
            //if(integrador.BillingCountry != null && integrador.BillingCountry.equalsIgnoreCase('Brasil')){
            formattedBillingCountry = 'BR';
            //}

            String formattedShippingCountry;
            //if(integrador.ShippingCountry != null && integrador.ShippingCountry.equalsIgnoreCase('Brasil')){
            formattedShippingCountry = 'BR';
            //}
            
            IntegradorRequest corpoRequisicao = new IntegradorRequest();
            corpoRequisicao.CardCode       = integrador.SeCPFouCNPJ__c;
            corpoRequisicao.CardName       = integrador.RazaoSocial__c;
            corpoRequisicao.CardType       = 'cSupplier';
            corpoRequisicao.EmailAddress   = integrador.Email__c;
            corpoRequisicao.Phone1         = Utils.removeNonNumericCharacters(integrador.Telefone__c);
            corpoRequisicao.FederalTaxID   = integrador.SeCPFouCNPJ__c;
            corpoRequisicao.BPAddresses    = new BPAddress[]{};
            corpoRequisicao.BPFiscalTaxIDCollection  = new BPFiscalTaxID[]{};

            if( integrador.Conta__c != null && integrador.Agencia__c != null && integrador.Banco__c != null){
                corpoRequisicao.DefaultAccount      = integrador.Conta__c;
                corpoRequisicao.DefaultBranch      = integrador.Agencia__c;
                corpoRequisicao.DefaultBankCode      = integrador.Banco__c;
            }

            if(integrador.Logradouro__c != Null){
                BPAddress bpAddress         = new BPAddress();
                bpAddress.AddressName       = 'Endereço cobrança';
                bpAddress.Street            = integrador.Logradouro__c;
                bpAddress.Block             = integrador.Bairro__c;
                bpAddress.ZipCode           = integrador.CEP__c;
                bpAddress.City              = integrador.Cidade__c;
                bpAddress.County            = integrador.Cidade__c;
                bpAddress.Country           = formattedBillingCountry;
                bpAddress.State             = formattedEstadoCobranca;
                bpAddress.BuildingFloorRoom = integrador.Complemento__c != null ? integrador.Complemento__c : '';
                bpAddress.AddressType       = 'bo_BillTo';
                bpAddress.StreetNo          = 'S/N';
                bpAddress.BPCode            = integrador.SeCPFouCNPJ__c;
                bpAddress.RowNum            = 0;


                corpoRequisicao.BPAddresses.add(bpAddress);
            }

            if(integrador.Logradouro__c != null){
                BPAddress shippingAddress         = new BPAddress();
                shippingAddress.AddressName       = 'Endereço entrega';
                shippingAddress.Street            = integrador.Logradouro__c;
                shippingAddress.Block             = integrador.Bairro__c;
                shippingAddress.ZipCode           = integrador.CEP__c;
                shippingAddress.City              = integrador.Cidade__c;
                shippingAddress.County            = integrador.Cidade__c;
                shippingAddress.Country           = formattedShippingCountry;
                shippingAddress.State             = formattedEstadoEntrega;
                shippingAddress.BuildingFloorRoom = integrador.Complemento__c != null ? integrador.Complemento__c : '';
                shippingAddress.AddressType       = 'bo_ShipTo';
                shippingAddress.StreetNo          = 'S/N';
                shippingAddress.BPCode            = integrador.SeCPFouCNPJ__c;
                shippingAddress.RowNum            = 1;

                corpoRequisicao.BPAddresses.add(shippingAddress);
            }

            BPFiscalTaxID BPTaxID = new BPFiscalTaxID();
            if(integrador.CPF__c != null){
                BPTaxID.TaxID0 = integrador.SeCPFouCNPJ__c;
            } else if(integrador.CNPJ__c != null){
                BPTaxID.TaxID4 = integrador.SeCPFouCNPJ__c;
            }
            corpoRequisicao.BPFiscalTaxIDCollection.add(BPTaxID);

            try{
                HttpResponse response = chamadaIntegracao(JSON.serialize(corpoRequisicao), 'FornecedorSAP');
                Utils.createLog('IntegracaoSAPIntegrador', 'sendIntegrador ' + integrador.Id, response);

                if(response.getBody() != null && response.getBody() != ''){
                    Integer[] successSAPResponseCodes = new Integer[]{200, 201, 204};

                    Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                    Integer statusCode = Integer.valueOf(responseBody.get('codigoHttp'));

                    //Sucesso
                    if(successSAPResponseCodes.contains(statusCode)){
                        
                        System.debug('SUCCESS');
                        integrador.SucessoIntegracaoSAP__c = true;
                    }
                    //Erro
                    else{
                    System.debug('ERROR');
                    integrador.SucessoIntegracaoSAP__c = false;
                    
                    }
                    integrador.StatusBodyIntegracaoSAP__c = statusCode + ' ' + response.getBody() + ' ' + response.getStatus();
                }
            } catch (Exception e){
                Utils.createLog('IntegracaoSAPIntegrador', 'sendIntegrador ' + integrador.Id, e);
                
                integrador.SucessoIntegracaoSAP__c = false;
                integrador.StatusBodyIntegracaoSAP__c = e.getMessage() + ' ' + e.getStackTraceString();
            }
        }

        IntegradorTriggerHandler.disableTrigger();
        update IntegradorList;
        IntegradorTriggerHandler.isTriggerEnabled();
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

    public class IntegradorRequest{
        public String      CardCode;     // ID externo (CPF) - "1234"
        public String      CardName;     // Nome - "Integrador atualizado pela API"
        public String      CardType;     // Tipo de pessoa, deve ser cCustomer para Integradors - "cCustomer"
        public String      EmailAddress; // Email - "email@teste.com"
        public String      Phone1;       // Telefone do Integrador - "11111111"
        public String      FederalTaxID; // Documento do Integrador - "453125241"
        public String      DefaultAccount; 
        public String      DefaultBranch; 
        public String      DefaultBankCode; 
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
        public String  BPCode;            // Chave externa do Integrador - "1234",
        public Integer RowNum;            // Sequencial gerado automaticamente, começa em zero - 0
    }

    public class BPFiscalTaxID{
        public String TaxID0;             // CNPJ do Integrador, se houver  
        public String TaxID4;             // CPF do Integrador, se houver  
    }
}