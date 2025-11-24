public class IntegracaoNivelloDataVisitaTecnica {
    public static void sendTechnicalVisitDate(Set<Id> triggerIds, Boolean isFromServiceAppointment){
        if(isFromServiceAppointment){
            sendTechnicalVisitDateFromServiceAppointment(triggerIds);
        } else {
            sendTechnicalVisitDateFromDateChanging(triggerIds);
        }
    }

    @future(callout=true)
    public static void sendTechnicalVisitDateFromDateChanging(Set<Id> triggerIds){
        List<Opportunity> oppList = [
            SELECT  Id, IdVirtualOffice__c, PrazoAprovacaoViabilidade__c
            FROM    Opportunity
            WHERE   Id IN :triggerIds
        ];

        for(Opportunity opp : oppList){
            TechnicalVisitDateRequest corpoRequisicao = new TechnicalVisitDateRequest();
            corpoRequisicao.id                 = opp.IdVirtualOffice__c;
            corpoRequisicao.TechnicalVisitDate = String.valueOf(opp.PrazoAprovacaoViabilidade__c);

            try{
                HttpResponse response = chamadaIntegracao(JSON.serialize(corpoRequisicao), 'DataVisitaTecnica');
                Utils.createLog('IntegracaoNivelloDataVisitaTecnica', 'sendTechnicalVisitDate ' + opp.Id, response, opp.Id);

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
                Utils.createLog('IntegracaoNivelloDataVisitaTecnica', 'sendTechnicalVisitDate ' + opp.Id, e, opp.Id);
                
                opp.SucessoIntegracaoNivello__c = false;
                opp.StatusBodyIntegracaoNivello__c = e.getMessage() + ' ' + e.getStackTraceString();
            }
        }
        OpportunityTriggerHandler.disableTrigger();
        update oppList;
        OpportunityTriggerHandler.enableTrigger();
    }

    @future(callout=true)
    public static void sendTechnicalVisitDateFromServiceAppointment(Set<Id> triggerIds){
        List<ServiceAppointment> appointmentList = [
            SELECT  Id, Oportunidade__c, Oportunidade__r.IdVirtualOffice__c, SchedStartTime
            FROM    ServiceAppointment
            WHERE   Id IN :triggerIds
        ];

        for(ServiceAppointment appointment : appointmentList){
            TechnicalVisitDateRequest corpoRequisicao = new TechnicalVisitDateRequest();
            corpoRequisicao.id                 = appointment.Oportunidade__r.IdVirtualOffice__c;
            corpoRequisicao.TechnicalVisitDate = 
                appointment.SchedStartTime != null ?
                String.valueOf(appointment.SchedStartTime.addHours(-3)) : null;

            try{
                HttpResponse response = chamadaIntegracao(JSON.serialize(corpoRequisicao), 'DataVisitaTecnica');
                Utils.createLog('IntegracaoNivelloDataVisitaTecnica', 'sendTechnicalVisitDate ' + appointment.Id, response, appointment.Oportunidade__c);

                //Sucesso
                if(response.getStatusCode() == 200){

                    System.debug('SUCCESS');
                    appointment.SucessoIntegracaoNivello__c = true;
                }
                //Erro
                else{
                    System.debug('ERROR');
                    appointment.SucessoIntegracaoNivello__c = false;

                }
                appointment.StatusBodyIntegracaoNivello__c = response.getStatusCode() + ' ' + response.getBody();
            } catch (Exception e){
                Utils.createLog('IntegracaoNivelloDataVisitaTecnica', 'sendTechnicalVisitDate ' + appointment.Id, e, appointment.Oportunidade__c);
                
                appointment.SucessoIntegracaoNivello__c = false;
                appointment.StatusBodyIntegracaoNivello__c = e.getMessage() + ' ' + e.getStackTraceString();
            }
        }
        ServiceAppointmentTriggerHandler.disableTrigger();
        update appointmentList;
        ServiceAppointmentTriggerHandler.enableTrigger();
    }

    private static HttpResponse chamadaIntegracao(String body, String metadataDeveloperName){
        Integrador__mdt parametrosIntegracao = [
            SELECT  Id, URL__c
            FROM    Integrador__mdt 
            WHERE   DeveloperName = :metadataDeveloperName
        ];

        Http httpObj = new Http();
        HttpRequest request = new HttpRequest();
        
        request.setEndpoint(parametrosIntegracao.URL__c);
        request.setMethod('PUT');
        request.setHeader('Content-Type', 'application/json');
        request.setBody(body);
        
        return Utils.callIntegrationNivello(request);
    }

    public class TechnicalVisitDateRequest{
        public String id;
        public String TechnicalVisitDate;
    }
}
