/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-11-2025
 * @last modified by  : Daniel Belini
**/
public class ProposalService {

    @future(callout=true)
    public static void updateOpportunityPhase(Set<Id> opportunityIds) {
        String endpointUrl = getEndpointUrl();
        if (String.isEmpty(endpointUrl)) {
            // Tratar o caso onde o endpoint não está configurado
            return;
        }

        List<Opportunity> opportunities = [ 
            SELECT IdVirtualOffice__c, StageName, Observacoes__c, recordType.Name, Status__c, Categoria__c, ValorTotalProposta__c, Rede__c, DataHoraAgendamento__c, Loss_Reason__c, DescricaoMotivoPerda__c
            FROM Opportunity 
            WHERE Id IN :opportunityIds
        ];

        Integer statusEnum;
        Integer substatusId;
        for (Opportunity opportunity : opportunities) {
            
            statusEnum = StatusEnumMap.getStatusEnum(opportunity.recordType.Name,opportunity.StageName);
            substatusId = StatusEnumMap.getSubstatusEnum(statusEnum, opportunity.Status__c);
            System.debug('statusEnum');
            System.debug(statusEnum);

            GORecordsTO request = new GORecordsTO();
            request.IdSalesForce        = opportunity.Id;
            request.Status              = statusEnum;
            request.SubStatus           = substatusId;
            request.Category            = opportunity.Categoria__c;
            request.AppointmentDateTime = opportunity.DataHoraAgendamento__c;
            request.Value                = opportunity.ValorTotalProposta__c;

            if (OpportunityUtils.STATUS_FECHADO_PERDIDO.equalsIgnoreCase(opportunity.StageName)) {
                request.LossReason = getLossReasonAsInteger(opportunity.Loss_Reason__c);
                request.DescriptionReasonLoss = opportunity.DescricaoMotivoPerda__c;
            }


            if (OpportunityUtils.isRecordTypeEzeeLivre(opportunity)){
                request.Value       = opportunity.Rede__c;
            } else {
                request.Value       = opportunity.ValorTotalProposta__c;
            }

            String jsonBody = JSON.serialize(request);
            System.debug(jsonBody);
            try{
                HttpResponse response = sendCallout(endpointUrl, jsonBody, opportunity.Id, 'updateOpportunityPhase');

                //Sucesso
                if(response.getStatusCode() == 200){

                    System.debug('SUCCESS');
                    opportunity.SucessoIntegracaoNivello__c = true;
                }
                //Erro
                else{
                    System.debug('ERROR');
                    opportunity.SucessoIntegracaoNivello__c = false;
                }

                OpportunityTriggerHandler.disableTrigger();
                update opportunity;
                OpportunityTriggerHandler.enableTrigger();

                opportunity.StatusBodyIntegracaoNivello__c = response.getStatusCode() + ' ' + response.getBody();
            } catch (Exception e){
                Utils.createLog('ProposalService', 'updateOpportunityPhase', e, opportunity.Id);
                
                opportunity.SucessoIntegracaoNivello__c = false;
                opportunity.StatusBodyIntegracaoNivello__c = e.getMessage() + ' ' + e.getStackTraceString();
                OpportunityTriggerHandler.disableTrigger();
                update opportunity;
                OpportunityTriggerHandler.enableTrigger();
            }


        }
    }

    private static String getEndpointUrl() {
        Integrador__mdt parametrosIntegracao = [
            SELECT  Id, URL__c
            FROM    Integrador__mdt 
            WHERE   DeveloperName = 'ProposalStatus'
        ];
        return (parametrosIntegracao != null) ? parametrosIntegracao.URL__c : null;
    }

    private static HttpResponse sendCallout(String endpointUrl, String jsonBody, Id relatedId, String logMethodName) {
        HttpRequest req = new HttpRequest();
        
        req.setEndpoint(endpointUrl);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);

        HttpResponse response = Utils.callIntegrationNivello(req);

        Utils.LogDTO logDTO = new Utils.LogDTO();
        logDTO.className = 'ProposalService';
        logDTO.methodName = logMethodName;
        logDTO.relatedId = relatedId;
        logDTO.httpMethod = req.getMethod();
        logDTO.requestBody = jsonBody;
        logDTO.requestURI = endpointUrl;
        if(response != null){
            logDTO.statusCode = response.getStatusCode();
            logDTO.status = response.getStatus();
            logDTO.responseBody = response.getBody();
        }
        Utils.createLog(logDTO);

        return response;
    }

    private static final Map<String, Integer> LOSS_REASON_MAP = new Map<String, Integer>{
        'inviabilidade financeira' => 1,
        'inviabilidade técnica' => 2,
        'sem área para instalação' => 3,
        'parado por 30 dias' => 4,
        'sem contato com o cliente ou consultor' => 5,
        'cliente fechou com outra empresa' => 6,
        'consultor/cliente recusou a proposta' => 7,
        'cliente desistiu' => 8,
        'cliente retomará a negociação em outra data' => 9,
        'cliente prosseguiu com outra proposta, duplicata' => 10,
        'outro' => 11
    };

    private static Integer getLossReasonAsInteger(String lossReasonValue) {
        if (String.isBlank(lossReasonValue)) {
            return null;
        }

        String normalizedValue = lossReasonValue.trim().toLowerCase();
        return LOSS_REASON_MAP.get(normalizedValue);
    }

    /*private static integer getStatusEnum(String stageName){
        if(stageName == OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA){
            return 2;
        }else if (  stageName == OpportunityUtils.STATUS_AGENDAMENTO_DA_VISITA_TECNICA || 
                    stageName == OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE){
            return 6;
        }else if(stageName == OpportunityUtils.STATUS_READEQUACAO_DE_PROPOSTA){
            return 3;
        }else if(stageName == OpportunityUtils.STATUS_METODO_DE_PAGAMENTO){
            return 5;
        }else if(stageName == OpportunityUtils.STATUS_GANHO_FECHADO){
            return 10;
        }else if(stageName == OpportunityUtils.STATUS_VALIDACAO_DO_METODO_DE_PAGAMENTO){
            return 13;
        }else if(stageName == OpportunityUtils.STATUS_PROPOSTA_ENVIADA_AGUARDANDO_ACEITE){
            return 4;
        }else if(stageName == OpportunityUtils.STATUS_GANHO_FECHADO){
            return 4;
        }else if(stageName == OpportunityUtils.STATUS_CONTRATO_ENVIADO || stageName == OpportunityUtils.STATUS_GERACAO_DE_CONTRATO){
            return 7;
        }else if(stageName == OpportunityUtils.STATUS_CONTRATO_FIRMADO_ASSINADO){
            return 4;
        }else{
            return 0;
        }
    }*/

    /*public class ProposalUpdateRequest {
        public String IdSalesForce;      
        public Integer Status;   
        public Integer SubStatus;
    
        public ProposalUpdateRequest(String IdSalesForce, Integer Status, Integer SubStatus) {
            this.IdSalesForce = IdSalesForce;
            this.Status = Status;
            this.SubStatus = SubStatus;
        }
    }*/

}
