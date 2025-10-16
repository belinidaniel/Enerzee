public with sharing class IntegracaoSAPConsultor {
    @future(callout=true)
    public static void sendConsultor(Set<Id> triggerIds){
        List<Consultor__c> consultorList = [
            SELECT  Id, IdVirtualOffice__c, CPF__c, CNPJ__c, SeCPFouCNPJ__c, Name, Email__c,
                    Telefone__c, RuaCobranca__c, CodigoPostalCobranca__c, CidadeCobranca__c,
                    EstadoCobranca__c, BairroCobranca__c, MunicipioCobranca__c, 
                    ComplementoCobranca__c, NumeroRuaCobranca__c, 
                    RuaEntrega__c, CodigoPostalEntrega__c, CidadeEntrega__c,
                    EstadoEntrega__c, BairroEntrega__c, 
                    MunicipioEntrega__c, ComplementoEntrega__c, NumeroRuaEntrega__c,
                    SucessoIntegracaoSAP__c, StatusBodyIntegracaoSAP__c
            FROM    Consultor__c
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


        for(Consultor__c acc : consultorList){
            String formattedEstadoCobranca = acc.EstadoCobranca__c;
            if(acc.EstadoCobranca__c != null && acc.EstadoCobranca__c?.length() != 2){
                formattedEstadoCobranca = stateNameToAbbreviation.get(acc.EstadoCobranca__c);
            }

            String formattedEstadoEntrega = acc.EstadoEntrega__c;
            if(acc.EstadoEntrega__c != null && acc.EstadoEntrega__c?.length() != 2){
                formattedEstadoEntrega = stateNameToAbbreviation.get(acc.EstadoEntrega__c);
            }

            String formattedBillingCountry;
            //if(acc.BillingCountry != null && acc.BillingCountry.equalsIgnoreCase('Brasil')){
            formattedBillingCountry = 'BR';
            //}

            String formattedShippingCountry;
            //if(acc.ShippingCountry != null && acc.ShippingCountry.equalsIgnoreCase('Brasil')){
            formattedShippingCountry = 'BR';
            //}
            
            ConsultorRequest corpoRequisicao = new ConsultorRequest();
            corpoRequisicao.CardCode       = acc.SeCPFouCNPJ__c;
            corpoRequisicao.CardName       = acc.Name;
            corpoRequisicao.CardType       = 'cCustomer';
            corpoRequisicao.EmailAddress   = acc.Email__c;
            corpoRequisicao.Phone1         = Utils.removeNonNumericCharacters(acc.Telefone__c);
            corpoRequisicao.FederalTaxID   = acc.SeCPFouCNPJ__c;
            corpoRequisicao.BPAddresses    = new BPAddress[]{};
            corpoRequisicao.BPFiscalTaxIDCollection  = new BPFiscalTaxID[]{};


            if(acc.RuaCobranca__c != Null){
                BPAddress bpAddress         = new BPAddress();
                bpAddress.AddressName       = 'Endereço cobrança';
                bpAddress.Street            = acc.RuaCobranca__c;
                bpAddress.Block             = acc.BairroCobranca__c;
                bpAddress.ZipCode           = acc.CodigoPostalCobranca__c;
                bpAddress.City              = acc.CidadeCobranca__c;
                bpAddress.County            = acc.MunicipioCobranca__c;
                bpAddress.Country           = formattedBillingCountry;
                bpAddress.State             = formattedEstadoCobranca;
                bpAddress.BuildingFloorRoom = acc.ComplementoCobranca__c != null ? acc.ComplementoCobranca__c : '';
                bpAddress.AddressType       = 'bo_BillTo';
                bpAddress.StreetNo          = acc.NumeroRuaCobranca__c;
                bpAddress.BPCode            = acc.SeCPFouCNPJ__c;
                bpAddress.RowNum            = 0;


                corpoRequisicao.BPAddresses.add(bpAddress);
            }

            if(acc.RuaEntrega__c != null){
                BPAddress shippingAddress         = new BPAddress();
                shippingAddress.AddressName       = 'Endereço entrega';
                shippingAddress.Street            = acc.RuaEntrega__c;
                shippingAddress.Block             = acc.BairroEntrega__c;
                shippingAddress.ZipCode           = acc.CodigoPostalEntrega__c;
                shippingAddress.City              = acc.CidadeEntrega__c;
                shippingAddress.County            = acc.MunicipioEntrega__c;
                shippingAddress.Country           = formattedShippingCountry;
                shippingAddress.State             = formattedEstadoEntrega;
                shippingAddress.BuildingFloorRoom = acc.ComplementoEntrega__c != null ? acc.ComplementoEntrega__c : '';
                shippingAddress.AddressType       = 'bo_ShipTo';
                shippingAddress.StreetNo          = acc.NumeroRuaEntrega__c;
                shippingAddress.BPCode            = acc.SeCPFouCNPJ__c;
                shippingAddress.RowNum            = 1;

                corpoRequisicao.BPAddresses.add(shippingAddress);
            }

            BPFiscalTaxID BPTaxID = new BPFiscalTaxID();
            if(acc.CPF__c != null){
                BPTaxID.TaxID0 = acc.SeCPFouCNPJ__c;
            } else if(acc.CNPJ__c != null){
                BPTaxID.TaxID4 = acc.SeCPFouCNPJ__c;
            }
            corpoRequisicao.BPFiscalTaxIDCollection.add(BPTaxID);

            try{
                HttpResponse response = chamadaIntegracao(JSON.serialize(corpoRequisicao), 'ClienteSAP');
                Utils.createLog('IntegracaoSAPConsultor', 'sendConsultor ' + acc.Id, response);

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
                Utils.createLog('IntegracaoSAPConsultor', 'sendConsultor ' + acc.Id, e);
                
                acc.SucessoIntegracaoSAP__c = false;
                acc.StatusBodyIntegracaoSAP__c = e.getMessage() + ' ' + e.getStackTraceString();
            }
        }

        ConsultorTriggerHandler.disableTrigger();
        update consultorList;
        ConsultorTriggerHandler.enableTrigger();
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

    public class ConsultorRequest{
        public String      CardCode;     // ID externo (CPF) - "1234"
        public String      CardName;     // Nome - "Consultor atualizado pela API"
        public String      CardType;     // Tipo de pessoa, deve ser cCustomer para Consultors - "cCustomer"
        public String      EmailAddress; // Email - "email@teste.com"
        public String      Phone1;       // Telefone do Consultor - "11111111"
        public String      FederalTaxID; // Documento do Consultor - "453125241"
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
        public String  BPCode;            // Chave externa do Consultor - "1234",
        public Integer RowNum;            // Sequencial gerado automaticamente, começa em zero - 0
    }

    public class BPFiscalTaxID{
        public String TaxID0;             // CNPJ do Consultor, se houver  
        public String TaxID4;             // CPF do Consultor, se houver  
    }
}