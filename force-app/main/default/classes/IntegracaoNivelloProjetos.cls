public with sharing class IntegracaoNivelloProjetos {
    @future(callout=true)
    public static void sendProjetos(Set<Id> triggerIds, Boolean isInsert){
        List<Log__c> logs = new List<Log__c>();

        List<Projeto__c> projectList = [
            SELECT  Id, Oportunidade__c, Oportunidade__r.IdVirtualOffice__c, Status__c, RecordType.Name,
                    DiasFaltantes__c, LastModifiedDate, NumeroProjeto__c, Name, Oportunidade__r.StageName,
                    DataInicioContrato__c, PrazoContratoDias__c, DataContagemPrazo__c, Oportunidade__r.Status__c,
                    DataTermino__c, PotenciaSistema__c, Projetista__c, Projetista__r.Name, 
                    GestorObra__c, GestorObra__r.Name, Oportunidade__r.RecordType.Name
            FROM    Projeto__c
            WHERE   Id IN :triggerIds
        ];

        Integer statusEnum;
        Integer substatusId;

        for(Projeto__c project : projectList){

            statusEnum = StatusEnumMap.getStatusEnum(project.Oportunidade__r.RecordType.Name, project.Oportunidade__r.StageName);
            substatusId = StatusEnumMap.getSubstatusEnum(statusEnum, project.Oportunidade__r.Status__c);

            GORecordsTO request = new GORecordsTO();
            //request.ProposalID              = project.Oportunidade__r.IdVirtualOffice__c;
            request.IdSalesForce            = project.Oportunidade__r.Id;
            request.Status                  = statusEnum;
            request.SubStatus               = substatusId;
            request.StatusProjeto           = project.Status__c;
            request.Category                = project.RecordType.Name;
            request.codigoRegistroProjetoSF = project.Id;
            request.numeroProjeto           = project.NumeroProjeto__c;
            request.nomeProjeto             = project.Name;
            request.dataInicioContrato      = project.DataInicioContrato__c != null ? String.valueOf(project.DataInicioContrato__c).replace(' ', 'T') : null; 
            request.prazoContrato           = project.PrazoContratoDias__c != null ? Integer.valueOf(project.PrazoContratoDias__c) : null;
            request.dataContagemdoPrazo     = project.DataContagemPrazo__c != null ? String.valueOf(project.DataContagemPrazo__c).replace(' ', 'T') : null;
            request.dataTermino             = project.DataTermino__c != null ? String.valueOf(project.DataTermino__c).replace(' ', 'T') : null;
            request.diasFaltantes           = Integer.valueOf(project.DiasFaltantes__c);
            request.potenciaDoSistema       = project.PotenciaSistema__c;
            request.projetista              = project.Projetista__c != null ? project.Projetista__r.Name : null;
            request.gestordaObra            = project.GestorObra__c != null ? project.GestorObra__r.Name : null;
            request.dataUltimaModificacao   = String.valueOf(project.LastModifiedDate).replace(' ', 'T');
            
            try{
                String endpointUrl = getEndpointUrl('ProposalStatus');
                String requestBody = JSON.serialize(request);
                HttpResponse response = chamadaIntegracao(requestBody, endpointUrl);

                Utils.LogDTO logDTO = new Utils.LogDTO();
                logDTO.className = 'IntegracaoNivelloProjetos';
                logDTO.methodName = isInsert ? 'sendProjetosInsert' : 'sendProjetosUpdate';
                logDTO.relatedId = project.Oportunidade__c;
                logDTO.httpMethod = 'POST';
                logDTO.requestBody = requestBody;
                logDTO.requestURI = endpointUrl;
                if(response != null){
                    logDTO.statusCode = response.getStatusCode();
                    logDTO.status = response.getStatus();
                    logDTO.responseBody = response.getBody();
                }
                logs.add(Utils.createLogNoInsert(logDTO));

                //Sucesso
                if(response.getStatusCode() == 200){

                    System.debug('SUCCESS');
                    project.SucessoIntegracaoNivello__c = true;
                }
                //Erro
                else{
                    System.debug('ERROR');
                    project.SucessoIntegracaoNivello__c = false;

                }
                project.StatusBodyIntegracaoNivello__c = response.getStatusCode() + ' ' + response.getBody();
            } catch (Exception e){
                logs.add(Utils.createLogNoInsert('IntegracaoNivelloProjetos', (isInsert ? 'sendProjetosInsert' : 'sendProjetosUpdate'), e, project.Oportunidade__c));
                
                project.SucessoIntegracaoNivello__c = false;
                project.StatusBodyIntegracaoNivello__c = e.getMessage() + ' ' + e.getStackTraceString();
            }
        }

        
        ProjetoTriggerHandler.disableTrigger();
        update projectList;
        ProjetoTriggerHandler.enableTrigger();

        insert logs;
    }

    private static HttpResponse chamadaIntegracao(String body, String endpointUrl){
        Http httpObj = new Http();
        HttpRequest request = new HttpRequest();
        
        request.setEndpoint(endpointUrl);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setBody(body);
        
        return Utils.callIntegrationNivello(request);
    }

    private static String getEndpointUrl(String endpointName){
        Integrador__mdt parametrosIntegracao = [
            SELECT  URL__c
            FROM    Integrador__mdt 
            WHERE   DeveloperName = :endpointName
        ];
        return parametrosIntegracao.URL__c;
    }

    
    /*public class ProjetoRequestInsert{
        public String  ProposalID;              //  "e4297852-0ebb-47c0-b0ce-f135ffebde3e",
        public String  Category;                //  Nome do Tipo de Registro 
        public String  StatusProjeto;                  //  StatusProjeto
        public Integer diasFaltantes;           //  Dias Faltantes
        public String  dataUltimaModificacao;   //  "2022-01-10T23:59:00"
        public String  codigoRegistroProjetoSF; //  ID Salesforce (apenas insert)
        public String  numeroProjeto;           //  Número do projeto (apenas insert)
        public String  nomeProjeto;             //  Nome do registro (apenas insert)
        public String  dataInicioContrato;      //  "2022-01-10T23:59:00" (apenas insert)
        public Integer prazoContrato;           //  Prazo contrato (apenas insert)
        public String  dataContagemdoPrazo;     //  "2022-01-10T23:59:00" (apenas insert)
        public String  dataTermino;             //  "2022-01-10T23:59:00" (apenas insert)
        public String  potenciaDoSistema;       //  "25 kw" (apenas insert)
        public String  projetista;              //  Nome do usuário (apenas insert)
        public String  gestordaObra;            //  Nome do usuário (apenas insert)
    }
    
    public class ProjetoRequestUpdate{
        public String  ProposalID;              //  "e4297852-0ebb-47c0-b0ce-f135ffebde3e",
        public String  Category;                //  Nome do Tipo de Registro 
        public String  StatusProjeto;                  //  StatusProjeto
        public Integer diasFaltantes;           //  Dias Faltantes
        public String  dataUltimaModificacao;   //  "2022-01-10T23:59:00"
        public String  dataInicioContrato;      //  "2022-01-10T23:59:00" (apenas insert)
        public Integer prazoContrato;           //  Prazo contrato (apenas insert)
        public String  dataContagemdoPrazo;     //  "2022-01-10T23:59:00" (apenas insert)
        public String  dataTermino;             //  "2022-01-10T23:59:00" (apenas insert)
        public String  potenciaDoSistema;       //  "25 kw" (apenas insert)
        public String  projetista;              //  Nome do usuário (apenas insert)
        public String  gestordaObra;            //  Nome do usuário (apenas insert)
    }*/
}
