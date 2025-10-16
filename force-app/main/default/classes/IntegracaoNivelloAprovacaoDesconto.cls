/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 10-13-2025
 * @last modified by  : Daniel Belini
**/
public with sharing class IntegracaoNivelloAprovacaoDesconto {
    @future(callout=true)
    public static void enviarStatusAprovacaoDesconto(Set<Id> triggerIds) {
        List<Opportunity> opplist = [
            SELECT  Id, IdVirtualOffice__c, StatusAprovacaoDesconto__c, ObservacaoAprovacao__c, DescontoUFV__c,
                    BDI__c, Rede3750__c, Pontos__c, Direct__c
            FROM    Opportunity
            WHERE   Id IN :triggerIds
        ];

        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        for(Opportunity opportunity : opplist){
            try {
                // Prepara a requisição de aprovação do desconto
                DiscountApprovalRequest request = new DiscountApprovalRequest();
                request.id = opportunity.IdVirtualOffice__c;
                request.statusDiscount = (opportunity.StatusAprovacaoDesconto__c == null)  ? 0 : (opportunity.StatusAprovacaoDesconto__c == 'Pendente') ? 1 : (opportunity.StatusAprovacaoDesconto__c == 'Aprovado') ? 2 : 3;
                request.discountReturnApprovalComments = opportunity.ObservacaoAprovacao__c; 
                
                if(opportunity.StatusAprovacaoDesconto__c == 'Aprovado'){
                    request.returnRequestDiscount = opportunity.DescontoUFV__c;
                }else{
                    request.returnRequestDiscount = 0;
                    opportunity.DescontoUFV__c = 0;
                    //oppsToUpdate.add(opportunity);
                }
                
                // Chama a API da Nivello para enviar o status de aprovação do desconto
                HttpResponse response = chamadaIntegracao(JSON.serialize(request), 'Aprovacao_Desconto');
                Utils.createLog('IntegracaoNivelloAprovacaoDesconto', 'aprovacaoDesconto ' + opportunity.Id, response);

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
                Utils.createLog('IntegracaoNivelloAprovacaoDesconto', 'aprovacaoDesconto ' + opportunity.Id, ex);
            }   
        }

        if (!oppsToUpdate.isEmpty()) {
            OpportunityTriggerHandler.disableTrigger();
            //update oppsToUpdate;
            OpportunityTriggerHandler.enableTrigger();
        }
    }

    private static HttpResponse chamadaIntegracao(String body, String developerName) {
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
        
        return Utils.callIntegrationNivello(request);
    }

    public class DiscountApprovalRequest {
        public String  id;			
        public Integer statusDiscount;		
        public String  discountReturnApprovalComments;	
        public Decimal returnRequestDiscount;	
    }
}