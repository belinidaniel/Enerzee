public with sharing class IntegracaoSAPRepresentante {
    @future(callout=true)
    public static void sendRepresentante(Set<Id> triggerIds){
        List<Consultor__c> consultorList = [
            SELECT  Id, Name, Observacoes__c, Comissao__c, Ativo__c, Telefone__c,
                    Celular__c, Fax__c, Email__c, SeCPFOuCNPJ__c
            FROM    Consultor__c
            WHERE   Id IN :triggerIds
        ];

        for(Consultor__c consultor : consultorList){
            RepresentanteRequest corpoRequisicao       = new RepresentanteRequest();
            // corpoRequisicao.SalesEmployeeCode          = Integer.valueOf(consultor.IDSAP__c);
            corpoRequisicao.U_Alfa_IdIntegracao        = consultor.SeCPFOuCNPJ__c;
            corpoRequisicao.SalesEmployeeName          = consultor.Name;
            corpoRequisicao.Remarks                    = consultor.Observacoes__c;
            corpoRequisicao.CommissionForSalesEmployee = consultor.Comissao__c;
            corpoRequisicao.CommissionGroup            = null;
            corpoRequisicao.Active                     = consultor.Ativo__c ? 'tYES' : 'tNO';
            corpoRequisicao.Telephone                  = consultor.Telefone__c;
            corpoRequisicao.Mobile                     = consultor.Celular__c;
            corpoRequisicao.Fax                        = consultor.Fax__c;
            corpoRequisicao.Email                      = consultor.Email__c;

            try{
                HttpResponse response = chamadaIntegracao(JSON.serialize(corpoRequisicao), 'RepresentanteSAP');
                Utils.createLog('IntegracaoSAPRepresentante', 'sendRepresentante ' + consultor.Id, response);

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
                Utils.createLog('IntegracaoSAPRepresentante', 'sendRepresentante ' + consultor.Id, e);
                
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

    public class RepresentanteRequest{
        // public Integer SalesEmployeeCode;            // ID do representante - 12,
        public String  U_Alfa_IdIntegracao;          // ID que será convertido pro SalesEmployeeCode
        public String  SalesEmployeeName;            // Nome - "teste service layer",
        public String  Remarks;                      // Observações - "observacao",
        public Double  CommissionForSalesEmployee;   // Percentual de comissão - 1.0,
        public Integer CommissionGroup;              // ID do grupo de Comissão do representante - 0,
        public String  Active;                       // Status - "tYES",
        public String  Telephone;                    // Telefone - "telefone",
        public String  Mobile;                       // Celular - "celular",
        public String  Fax;                          // Fax - "fax",
        public String  Email;                        // Email - "email"
    }
}