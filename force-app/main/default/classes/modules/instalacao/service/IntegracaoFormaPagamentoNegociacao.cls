/**
 * @description       : Envia atualização de recusa da aprovação de forma de pagamento (Negociação)
 * @author            : Codex
**/
public with sharing class IntegracaoFormaPagamentoNegociacao {

    @future(callout=true)
    public static void enviarStatusReprovacao(Set<Id> opportunityIds) {
        if (opportunityIds == null || opportunityIds.isEmpty()) {
            return;
        }

        List<Opportunity> oportunidades = [
            SELECT Id, IdVirtualOffice__c, FormaPagamento__c, StageName,
                   NotePaymentMethod__c
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ];

        for (Opportunity opp : oportunidades) {
            try {
                PaymentNegotiationPayload payload = new PaymentNegotiationPayload();
                payload.id = String.isNotBlank(opp.IdVirtualOffice__c) ? opp.IdVirtualOffice__c : (String)opp.Id;
                payload.opportunityId = opp.Id;
                payload.paymentMethod = opp.FormaPagamento__c;
                payload.stage = opp.StageName;
                payload.comment = opp.NotePaymentMethod__c;

                HttpResponse response = callIntegration(JSON.serialize(payload), opp.Id);
                Utils.createLog('IntegracaoFormaPagamentoNegociacao', 'enviarStatusReprovacao ' + opp.Id, response, opp.Id);
            } catch (Exception ex) {
                Utils.createLog('IntegracaoFormaPagamentoNegociacao', 'enviarStatusReprovacao ' + opp.Id, ex, opp.Id);
            }
        }
    }

    private static HttpResponse callIntegration(String body, Id relatedId) {
        Integrador__mdt parametrosIntegracao = [
            SELECT URL__c
            FROM Integrador__mdt
            WHERE DeveloperName = 'Pagamento'
            LIMIT 1
        ];

        if (parametrosIntegracao == null || String.isBlank(parametrosIntegracao.URL__c)) {
            return null;
        }

        HttpRequest request = new HttpRequest();
        request.setEndpoint(parametrosIntegracao.URL__c);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setBody(body);

        HttpResponse response = Utils.callIntegrationNivello(request);

        if (response != null) {
            Utils.LogDTO logDTO = new Utils.LogDTO();
            logDTO.className = 'IntegracaoFormaPagamentoNegociacao';
            logDTO.methodName = 'callIntegration';
            logDTO.relatedId = relatedId;
            logDTO.httpMethod = request.getMethod();
            logDTO.requestURI = parametrosIntegracao.URL__c;
            logDTO.requestBody = body;
            logDTO.statusCode = response.getStatusCode();
            logDTO.status = response.getStatus();
            logDTO.responseBody = response.getBody();
            Utils.createLog(logDTO);
        }

        return response;
    }

    public class PaymentNegotiationPayload {
        public String id;
        public String opportunityId;
        public String paymentMethod;
        public String stage;
        public String status;
        public String comment;
    }
}