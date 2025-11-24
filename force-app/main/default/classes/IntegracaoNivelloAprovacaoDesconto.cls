/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 11-08-2025
 * @last modified by  : Daniel Belini
**/
public with sharing class IntegracaoNivelloAprovacaoDesconto {
    @future(callout=true)
    public static void enviarStatusAprovacaoDesconto(Set<Id> triggerIds) {
        List<Opportunity> opplist = [
            SELECT  Id, IdVirtualOffice__c, StatusAprovacaoDesconto__c, ObservacaoAprovacao__c, DescontoUFV__c,
                    ValorPropostoBDI__c, ValorPropostoRede3750__c, ValorPropostoPontos__c, ValorPropostoDirect__c,
                    BDI__c, Rede3750__c, Pontos__c, Direct__c
            FROM    Opportunity
            WHERE   Id IN :triggerIds
        ];

        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        for(Opportunity opportunity : opplist){
            try {
                // Prepara a requisição de aprovação do desconto
                DiscountApprovalRequest payload = new DiscountApprovalRequest();
                payload.id = opportunity.IdVirtualOffice__c;
                payload.statusDiscount = (opportunity.StatusAprovacaoDesconto__c == null)  ? 0 : (opportunity.StatusAprovacaoDesconto__c == 'Pendente') ? 1 : (opportunity.StatusAprovacaoDesconto__c == 'Aprovado') ? 2 : 3;
                payload.discountReturnApprovalComments = opportunity.ObservacaoAprovacao__c;
                payload.request = getDecimalOrZero(opportunity.DescontoUFV__c);
                payload.Bdi = getDecimalOrZero(opportunity.ValorPropostoBDI__c);
                payload.Direct = getDecimalOrZero(opportunity.ValorPropostoDirect__c);
                payload.Rede = getDecimalOrZero(opportunity.ValorPropostoRede3750__c);
                payload.Pontos = getDecimalOrZero(opportunity.ValorPropostoPontos__c);
                
                if(opportunity.StatusAprovacaoDesconto__c == 'Aprovado'){
                    payload.returnRequestDiscount = payload.request;
                }else{
                    payload.returnRequestDiscount = 0;
                    opportunity.DescontoUFV__c = 0;
                    oppsToUpdate.add(opportunity);
                }
                
                // Chama a API da Nivello para enviar o status de aprovação do desconto
                HttpResponse response = chamadaIntegracao(JSON.serialize(payload), 'Aprovacao_Desconto', opportunity.Id, 'aprovacaoDesconto');

                if (response.getStatusCode() == 200) {
                    // Parsing the response
                    Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                    if (resMap.containsKey('data')) {
                        Map<String, Object> dataMap = (Map<String, Object>) resMap.get('data');

                        opportunity.BDI__c = (Decimal) dataMap.get('discountedBdi');
                        opportunity.Rede3750__c = (Decimal) dataMap.get('discountedRede');
                        opportunity.Pontos__c = (Decimal) dataMap.get('discountedPontos');
                        opportunity.Direct__c = (Decimal) dataMap.get('discountedDirect');

                        oppsToUpdate.add(opportunity);
                    }
                } else {
                    System.debug('Error in response: ' + response.getBody());
                }
            } catch(Exception ex) {
                Utils.createLog('IntegracaoNivelloAprovacaoDesconto', 'aprovacaoDesconto', ex, opportunity.Id);
            }   
        }

        if (!oppsToUpdate.isEmpty()) {
            OpportunityTriggerHandler.disableTrigger();
            //update oppsToUpdate;
            OpportunityTriggerHandler.enableTrigger();
        }
    }

    private static HttpResponse chamadaIntegracao(String body, String developerName, Id relatedId, String logMethodName) {
        Integrador__mdt parametrosIntegracao = [
            SELECT  Id, URL__c
            FROM    Integrador__mdt 
            WHERE   DeveloperName = :developerName
        ];

        Http httpObj = new Http();
        HttpRequest request = new HttpRequest();
            
        request.setEndpoint(parametrosIntegracao.URL__c);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setBody(body);
        
        HttpResponse response = Utils.callIntegrationNivello(request);

        Utils.LogDTO logDTO = new Utils.LogDTO();
        logDTO.className = 'IntegracaoNivelloAprovacaoDesconto';
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

    private static Decimal getDecimalOrZero(Decimal value){
        return value == null ? 0 : value;
    }

    public class DiscountApprovalRequest {
        public String  id;			
        public Integer statusDiscount;		
        public String  discountReturnApprovalComments;
        public Decimal request;	
        public Decimal returnRequestDiscount;	
        public Decimal Bdi;
        public Decimal Direct;
        public Decimal Rede;
        public Decimal Pontos;
    }
}
