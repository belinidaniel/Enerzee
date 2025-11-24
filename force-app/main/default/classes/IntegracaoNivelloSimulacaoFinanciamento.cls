public without sharing class IntegracaoNivelloSimulacaoFinanciamento {

    @future(callout=true)
    public static void updateFinancingSimulation(Set<Id> triggerIds){
        List<Opportunity> opplist = [
            SELECT  Id, IdVirtualOffice__c, FinancingProcessDetails__c
            FROM    Opportunity
            WHERE   Id IN :triggerIds
        ];

        for(Opportunity opp : oppList){
            Request corpoRequisicao = new Request();
            corpoRequisicao.id = opp.IdVirtualOffice__c;
            corpoRequisicao.financingProcessDetails = opp.FinancingProcessDetails__c;

            try{
                HttpResponse response = chamadaIntegracao(JSON.serialize(corpoRequisicao), 'AtualizaSimulacaoFinanciamento', opp.Id, 'AtualizaSimulacaoFinanciamento');

                //Sucesso
                if(response.getStatusCode() == 200){

                    System.debug('SUCCESS');
                    opp.SucessoIntegracaoNivello__c = true;
                }
                //Erro
                else{
                    System.debug('ERROR');
                    opp.SucessoIntegracaoNivello__c = false;

                }
                opp.StatusBodyIntegracaoNivello__c = response.getStatusCode() + ' ' + response.getBody();
            } catch (Exception e){
                Utils.createLog('IntegracaoNivelloSimulacaoFinanciamento', 'AtualizaSimulacaoFinanciamento', e, opp.Id);
                
                opp.SucessoIntegracaoNivello__c = false;
                opp.StatusBodyIntegracaoNivello__c = e.getMessage() + ' ' + e.getStackTraceString();
            }
        }
        OpportunityTriggerHandler.disableTrigger();
        update oppList;
        OpportunityTriggerHandler.enableTrigger();
    }

    private static HttpResponse chamadaIntegracao(String body, String endpointName, Id relatedId, String logMethodName){
        Integrador__mdt parametrosIntegracao = [
            SELECT  Id, URL__c
            FROM    Integrador__mdt 
            WHERE   DeveloperName = :endpointName
        ];

        Http httpObj = new Http();
        HttpRequest request = new HttpRequest();
        
        request.setEndpoint(parametrosIntegracao.URL__c);
        request.setMethod('PATCH');
        request.setHeader('Content-Type', 'application/json');
        request.setBody(body);
        
        HttpResponse response = Utils.callIntegrationNivello(request);

        Utils.LogDTO logDTO = new Utils.LogDTO();
        logDTO.className = 'IntegracaoNivelloSimulacaoFinanciamento';
        logDTO.methodName = logMethodName;
        logDTO.relatedId = relatedId;
        logDTO.httpMethod = request.getMethod();
        logDTO.requestBody = body;
        logDTO.requestURI = parametrosIntegracao.URL__c;
        if(response != null){
            logDTO.statusCode = response.getStatusCode();
            logDTO.status = response.getStatus();
            logDTO.responseBody = response.getBody();
        }
        Utils.createLog(logDTO);
        
        return response;
    }

    public class Request{
        public String id;
        public String financingProcessDetails;
    }

}
