public with sharing class IntegracaoNivelloViabilidade {
    @future(callout=true)
    public static void etapaViabilidade(Set<Id> triggerIds){
        List<Opportunity> opplist = [
            SELECT  Id, IdVirtualOffice__c, EtapaViabilidade__c, Description
            FROM    Opportunity
            WHERE   Id IN :triggerIds
        ];

        for(Opportunity opp : oppList){
            EtapaViabilidadeRequest corpoRequisicao = new EtapaViabilidadeRequest();
            corpoRequisicao.id = opp.IdVirtualOffice__c;
            corpoRequisicao.status = 
                opp.EtapaViabilidade__c == null                         ? 0 :
                opp.EtapaViabilidade__c.equalsIgnoreCase('Agendamento') ? 1 : 
                opp.EtapaViabilidade__c.equalsIgnoreCase('Visita') 		? 2 : 
                opp.EtapaViabilidade__c.equalsIgnoreCase('Estudo') 		? 3 : 0;
            corpoRequisicao.description = opp.Description;

            try{
                HttpResponse response = chamadaIntegracao(JSON.serialize(corpoRequisicao), 'Etapa_Viabilidade');
                Utils.createLog('IntegracaoNivelloViabilidade', 'etapaViabilidade ' + opp.Id, response, opp.Id);
        
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
                Utils.createLog('IntegracaoNivelloViabilidade', 'etapaViabilidade ' + opp.Id, e, opp.Id);
                
                opp.SucessoIntegracaoNivello__c = false;
                opp.StatusBodyIntegracaoNivello__c = e.getMessage() + ' ' + e.getStackTraceString();
            }
        }
        OpportunityTriggerHandler.disableTrigger();
        update oppList;
        OpportunityTriggerHandler.enableTrigger();
    }

    @future(callout=true)
    public static void conclusaoViabilidade(Set<Id> triggerIds){
        List<Opportunity> opplist = [
            SELECT  Id, IdVirtualOffice__c, PrazoAprovacaoViabilidade__c
            FROM    Opportunity
            WHERE   Id IN :triggerIds
        ];

        for(Opportunity opp : oppList){
            ConclusaoViabilidadeRequest corpoRequisicao = new ConclusaoViabilidadeRequest();
            corpoRequisicao.id = opp.IdVirtualOffice__c;

            String deadlineAux = String.valueOf(opp.PrazoAprovacaoViabilidade__c);
            deadlineAux = deadlineAux.replace(' ', 'T');
            deadlineAux += '.' + opp.PrazoAprovacaoViabilidade__c.millisecond() + 'Z';
            corpoRequisicao.deadline = deadlineAux;

            try{
                HttpResponse response = chamadaIntegracao(JSON.serialize(corpoRequisicao), 'Conclusao_Viabilidade');
                Utils.createLog('IntegracaoNivelloViabilidade', 'conclusaoViabilidade ' + opp.Id, response, opp.Id);
                
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
                Utils.createLog('IntegracaoNivelloViabilidade', 'conclusaoViabilidade ' + opp.Id, e, opp.Id);
                
                opp.SucessoIntegracaoNivello__c = false;
                opp.StatusBodyIntegracaoNivello__c = e.getMessage() + ' ' + e.getStackTraceString();
            }
        }
        OpportunityTriggerHandler.disableTrigger();
        update oppList;
        OpportunityTriggerHandler.enableTrigger();
    }

    private static HttpResponse chamadaIntegracao(String body, String integracaoViabilidade){
        Integrador__mdt parametrosIntegracao = [
            SELECT  Id, URL__c
            FROM    Integrador__mdt 
            WHERE   DeveloperName = :integracaoViabilidade
        ];

        Http httpObj = new Http();
        HttpRequest request = new HttpRequest();
        
        request.setEndpoint(parametrosIntegracao.URL__c);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setBody(body);
        
        return Utils.callIntegrationNivello(request);
    }

    public class EtapaViabilidadeRequest{
        public String  id;			//	"3fa85f64-5717-4562-b3fc-2c963f66afa6"
        public Integer status;		//	0
        public String  description;	//	"string"
    }

    public class ConclusaoViabilidadeRequest{
        public String  id;			//	"3fa85f64-5717-4562-b3fc-2c963f66afa6"
        public String  deadline;    //  "2022-06-09T00:18:43.102Z"
    }
}
