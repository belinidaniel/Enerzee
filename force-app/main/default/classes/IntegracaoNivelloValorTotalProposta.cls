public with sharing class IntegracaoNivelloValorTotalProposta {

    @future(callout=true)
    public static void updateOpportunityTotalValue(Set<Id> triggerIds) {

        List<Opportunity> opplist = [
            SELECT Id, IdVirtualOffice__c, ValorTotalProposta__c, CustoAdicional__c,
            BDI__c, Rede3750__c, Pontos__c, Direct__c
            FROM Opportunity
            WHERE Id IN :triggerIds
        ];

        for(Opportunity opp : oppList){
            UpdateTotalValueRequest request = new UpdateTotalValueRequest();
            request.id = opp.IdVirtualOffice__c;
            request.additionalCost = opp.CustoAdicional__c;
            //request.originalTotalValue = opp.ValorTotalProposta__c - opp.CustoAdicional__c;
            //request.totalValue = opp.ValorTotalProposta__c;

            try {
                HttpResponse res = chamadaIntegracao(JSON.serialize(request), opp.Id, 'updateOpportunityTotalValue');
                
                if (res.getStatusCode() != 200) {
                    System.debug('Error in response: ' + res.getBody());
                } else {
                    System.debug('Response: ' + res.getBody());
                    // Parsing the response
                    Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    if (resMap.containsKey('data')) {
                        Map<String, Object> dataMap = (Map<String, Object>) resMap.get('data');
                        
                        opp.BDI__c = (Decimal) dataMap.get('discountedBdi');
                        opp.Rede3750__c = (Decimal) dataMap.get('discountedRede');
                        opp.Pontos__c = (Decimal) dataMap.get('discountedPontos');
                        opp.Direct__c = (Decimal) dataMap.get('discountedDirect');
                    }
                }
            } catch (Exception e) {
                Utils.createLog('IntegracaoNivelloValorTotalProposta', 'updateOpportunityTotalValue', e, opp.Id);
                System.debug('Error in HTTP request: ' + e.getMessage());
            }
        }
        
        if (!opplist.isEmpty()) {
            OpportunityTriggerHandler.disableTrigger();
            update opplist;
            OpportunityTriggerHandler.enableTrigger();
        }
    }

    private static HttpResponse chamadaIntegracao(String body, Id relatedId, String logMethodName){

        Http httpObj = new Http();
        HttpRequest request = new HttpRequest();

        String endpoint = 'https://geradorpropostas.azurewebsites.net/api/proposal/update-opportunity-total-value';
        request.setEndpoint(endpoint);
        request.setMethod('PATCH');
        request.setHeader('Content-Type', 'application/json');
        request.setBody(body);

        HttpResponse response = Utils.callIntegrationNivello(request);

        Utils.LogDTO logDTO = new Utils.LogDTO();
        logDTO.className = 'IntegracaoNivelloValorTotalProposta';
        logDTO.methodName = logMethodName;
        logDTO.relatedId = relatedId;
        logDTO.httpMethod = request.getMethod();
        logDTO.requestBody = body;
        logDTO.requestURI = endpoint;
        if(response != null){
            logDTO.statusCode = response.getStatusCode();
            logDTO.status = response.getStatus();
            logDTO.responseBody = response.getBody();
        }
        Utils.createLog(logDTO);

        return response;
    }

    public class UpdateTotalValueRequest{
        public String id;
        public Decimal additionalCost;
    }
}