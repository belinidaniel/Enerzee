public with sharing class IntegracaoSAPFornecedor {
    @future(callout=true)
    public static void sendFornecedor(Set<Id> triggerIds){
        List<Consultor__c> consultorList = [
            SELECT  Id, CPF__c, CNPJ__c, SeCPFouCNPJ__c, Name, Email__c, Telefone__c,
                    RuaCobranca__c, BairroCobranca__c, CodigoPostalCobranca__c,
                    CidadeCobranca__c, MunicipioCobranca__c, PaisCobranca__c,
                    EstadoCobranca__c, ComplementoCobranca__c, NumeroRuaCobranca__c,
                    RuaEntrega__c, BairroEntrega__c, CodigoPostalEntrega__c,
                    CidadeEntrega__c, MunicipioEntrega__c, PaisEntrega__c,
                    EstadoEntrega__c, ComplementoEntrega__c, NumeroRuaEntrega__c,
                    SucessoIntegracaoSAP__c, StatusBodyIntegracaoSAP__c,Banco__c,
                    Conta__c, Agencia__c
            FROM    Consultor__c
            WHERE   Id IN :triggerIds
        ];

        for(Consultor__c consultor : consultorList){

            String formattedBillingCountry = consultor.PaisCobranca__c;
            if(consultor.PaisCobranca__c != null && consultor.PaisCobranca__c.equalsIgnoreCase('Brasil')){
                formattedBillingCountry = 'BR';
            }

            String formattedShippingCountry = consultor.PaisEntrega__c;
            if(consultor.PaisEntrega__c != null && consultor.PaisEntrega__c.equalsIgnoreCase('Brasil')){
                formattedShippingCountry = 'BR';
            }

            FornecedorRequest corpoRequisicao = new FornecedorRequest();
            corpoRequisicao.CardCode          = consultor.SeCPFouCNPJ__c;
            corpoRequisicao.CardName          = consultor.Name;
            corpoRequisicao.CardType          = 'cSupplier';
            corpoRequisicao.EmailAddress      = consultor.Email__c;
            corpoRequisicao.Phone1            = consultor.Telefone__c;
            corpoRequisicao.FederalTaxID      = consultor.SeCPFouCNPJ__c;
            
            if( consultor.Conta__c != null && consultor.Agencia__c != null && consultor.Banco__c != null){
                corpoRequisicao.DefaultAccount      = consultor.Conta__c;
                corpoRequisicao.DefaultBranch      = consultor.Agencia__c;
                corpoRequisicao.DefaultBankCode      = consultor.Banco__c;
            }
            
            corpoRequisicao.BPAddresses       = new BPAddress[]{};
            corpoRequisicao.BPFiscalTaxIDCollection  = new BPFiscalTaxID[]{};


            BPAddress bpAddressBilling         = new BPAddress();
            bpAddressBilling.AddressName       = 'Endereço cobrança';
            bpAddressBilling.Street            = consultor.RuaCobranca__c;
            bpAddressBilling.Block             = consultor.BairroCobranca__c;
            bpAddressBilling.ZipCode           = consultor.CodigoPostalCobranca__c;
            bpAddressBilling.City              = consultor.CidadeCobranca__c;
            bpAddressBilling.County            = consultor.MunicipioCobranca__c;
            bpAddressBilling.Country           = formattedBillingCountry;
            bpAddressBilling.State             = consultor.EstadoCobranca__c;
            bpAddressBilling.BuildingFloorRoom = consultor.ComplementoCobranca__c;
            bpAddressBilling.AddressType       = 'bo_BillTo';
            bpAddressBilling.StreetNo          = consultor.NumeroRuaCobranca__c;
            bpAddressBilling.BPCode            = consultor.SeCPFouCNPJ__c;
            bpAddressBilling.RowNum            = 0;

            corpoRequisicao.BPAddresses.add(bpAddressBilling);


            BPAddress bpAddressShipping         = new BPAddress();
            bpAddressShipping.AddressName       = 'Endereço entrega';
            bpAddressShipping.Street            = consultor.RuaEntrega__c;
            bpAddressShipping.Block             = consultor.BairroEntrega__c;
            bpAddressShipping.ZipCode           = consultor.CodigoPostalEntrega__c;
            bpAddressShipping.City              = consultor.CidadeEntrega__c;
            bpAddressShipping.County            = consultor.MunicipioEntrega__c;
            bpAddressShipping.Country           = formattedShippingCountry;
            bpAddressShipping.State             = consultor.EstadoEntrega__c;
            bpAddressShipping.BuildingFloorRoom = consultor.ComplementoEntrega__c;
            bpAddressShipping.AddressType       = 'bo_ShipTo';
            bpAddressShipping.StreetNo          = consultor.NumeroRuaEntrega__c;
            bpAddressShipping.BPCode            = consultor.SeCPFouCNPJ__c;
            bpAddressShipping.RowNum            = 1;

            corpoRequisicao.BPAddresses.add(bpAddressShipping);

            BPFiscalTaxID BPTaxID = new BPFiscalTaxID();
            if(consultor.CPF__c != null){
                BPTaxID.TaxID0 = consultor.SeCPFouCNPJ__c;
            } else if(consultor.CNPJ__c != null){
                BPTaxID.TaxID4 = consultor.SeCPFouCNPJ__c;
            }
            corpoRequisicao.BPFiscalTaxIDCollection.add(BPTaxID);

            try{
                HttpResponse response = chamadaIntegracao(JSON.serialize(corpoRequisicao), 'FornecedorSAP');
                Utils.createLog('IntegracaoSAPFornecedor', 'sendFornecedor ' + consultor.Id, response);

                if(response.getBody() != null && response.getBody() != ''){
                    Integer[] successSAPResponseCodes = new Integer[]{200, 201, 204};

                    Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                    Integer statusCode = Integer.valueOf(responseBody.get('codigoHttp'));

                    //Sucesso
                    if(successSAPResponseCodes.contains(statusCode)){

                        System.debug('SUCCESS');
                        consultor.SucessoIntegracaoSAP__c = true;
                    }
                    //Erro
                    else{
                        System.debug('ERROR');
                        consultor.SucessoIntegracaoSAP__c = false;

                    }
                    consultor.StatusBodyIntegracaoSAP__c = statusCode + ' ' + response.getBody() + ' ' + response.getStatus();
                }
            } catch (Exception e){
                Utils.createLog('IntegracaoSAPFornecedor', 'sendFornecedor ' + consultor.Id, e);

                consultor.SucessoIntegracaoSAP__c = false;
                consultor.StatusBodyIntegracaoSAP__c = e.getMessage() + ' ' + e.getStackTraceString();
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
            WHERE   DeveloperName = 'TokenSAP_HML'
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

    public class FornecedorRequest{
        public String      CardCode;     // ID externo (CPF) - "1234"
        public String      CardName;     // Nome - "Cliente atualizado pela API"
        public String      CardType;     // Tipo de pessoa, deve ser cSupplier para fornecedores - "cSupplier"
        public String      EmailAddress; // Email - "email@teste.com"
        public String      DefaultAccount; 
        public String      DefaultBranch; 
        public String      DefaultBankCode; 
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
        public String TaxID0;             // CNPJ do Fornecedor, se houver  
        public String TaxID4;             // CPF do Fornecedor, se houver  
    }
}