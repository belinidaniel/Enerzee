/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 11-21-2025
 * @last modified by  : Daniel Belini
**/
public with sharing class IntegracaoNivelloProposta {

    //Por razões de tamanho de pilha, esta classe processa apenas uma Oportunidade por vez
    private static final String CONTRACT_DATA_PREFIX = 'data:application/pdf;base64,';
    private static final Map<String, ProposalIntegrationResult> integrationCache = new Map<String, ProposalIntegrationResult>();
    private static final Set<String> integrationInProgress = new Set<String>();

    @future(callout=true)
    public static void gerandoProposta(Id oppId){
        processGeracaoProposta(oppId, null, false, false);
    }

    public static ProposalIntegrationResult gerandoPropostaSincrona(Id oppId){
        return processGeracaoProposta(oppId, null, true, false);
    }

    public static ProposalIntegrationResult gerandoPropostaSincrona(Id oppId, Id contentVersionId){
        return processGeracaoProposta(oppId, contentVersionId, true, true);
    }

    private static ProposalIntegrationResult processGeracaoProposta(Id oppId, Id contentVersionId, Boolean captureResult, Boolean skipCache){
        ProposalIntegrationResult result = new ProposalIntegrationResult();
        String cacheKey = oppId + ':' + String.valueOf(contentVersionId);

        if(!skipCache && integrationCache.containsKey(cacheKey)){
            return integrationCache.get(cacheKey);
        }

        if(!skipCache && integrationInProgress.contains(cacheKey)){
            return result;
        }

        if(oppId == null){
            result.message = 'Oportunidade inválida.';
            return result;
        }

        try{
            List<Opportunity> oppList = [
                SELECT  Id, Name, IdVirtualOffice__c, OwnerId, StatusBodyIntegracaoNivello__c,
                        SucessoIntegracaoNivello__c, StageName, ValorTotalProposta__c, RecordType.Name
                FROM    Opportunity
                WHERE   Id = :oppId
                LIMIT   1
            ];

            if(oppList.isEmpty()){
                result.message = 'Oportunidade não encontrada.';
                return result;
            }

            Opportunity opp = oppList[0];

            List<ContentVersion> propostaPDFList;

            if(contentVersionId != null){
                propostaPDFList = [
                    SELECT      Id, VersionData, FileType, ContentSize, CreatedDate
                    FROM        ContentVersion
                    WHERE       Id = :contentVersionId
                    LIMIT       1
                ];
            } else {
                List<ContentDocumentLink> cdlList = [
                    SELECT  Id, ContentDocumentId
                    FROM    ContentDocumentLink
                    WHERE   LinkedEntityId = :oppId
                ];
    
                if(cdlList.isEmpty()){
                    result.message = 'Nenhum arquivo de proposta encontrado.';
                    return result;
                }
    
                List<Id> cdcIds = new List<Id>();
    
                for(ContentDocumentLink cdl : cdlList){
                    cdcIds.add(cdl.contentDocumentId);
                }

                if(
                    OpportunityUtils.isStatusAwaitingAcceptance(opp)
                    && OpportunityUtils.hasProposalReadjustment(opp)
                ){
                    propostaPDFList = [
                        SELECT      Id, VersionData, FileType, ContentSize, CreatedDate
                        FROM        ContentVersion 
                        WHERE       ContentDocumentId IN :cdcIds 
                                    AND FileType = 'PDF' 
                                    AND IsProposal__c = true
                                    AND (Title like '%READEQUACAO%' OR Title like '%READEQUAÇÃO%')
                        ORDER BY    CreatedDate DESC    
                        LIMIT       1
                    ];
                } else {
                propostaPDFList = [
                    SELECT      Id, VersionData, FileType, ContentSize, CreatedDate
                    FROM        ContentVersion 
                    WHERE       ContentDocumentId IN :cdcIds AND
                                FileType = 'PDF' AND IsProposal__c = true /*AND
                                (
                                    NomePaginaPDF__c = 'ModeloPropostaA' OR
                                    NomePaginaPDF__c = 'ModeloPropostaB'
                                )*/
                    ORDER BY    CreatedDate DESC    
                    LIMIT       1
                ];
                }
            }
            
            if(propostaPDFList.isEmpty()){
                result.message = 'Nenhum PDF válido foi localizado para envio.';
                return result;
            }

            if(!skipCache){
                integrationInProgress.add(cacheKey);
            }

            String contractPayload;
            try{
                contractPayload = CONTRACT_DATA_PREFIX + EncodingUtil.base64Encode(propostaPDFList[0].VersionData);
            } catch(Exception encodeEx){
                if(isMaxStringSizeException(encodeEx)){
                    handleContractTooLarge(opp, result);
                    integrationCache.put(cacheKey, result);
                    return result;
                } else {
                    throw encodeEx;
                }
            }

            JSONGenerator gen = JSON.createGenerator(true);
            gen.writeStartObject();
            gen.writeStringField('id', opp.IdVirtualOffice__c);
            gen.writeBooleanField('approved', true);
            gen.writeNumberField('opportunityPhase', StatusEnumMap.getStatusEnum(opp.recordType.Name, opp.StageName));
            System.debug('StatusEnumMap.getStatusEnum(opp.recordType.Name, opp.StageName');
            System.debug( 'integracaoNivelloProposta - opportunityPhase: ' + opp.ValorTotalProposta__c);
            gen.writeNumberField('proposalValue', opp.ValorTotalProposta__c );
            gen.writeStringField('contract', contractPayload);
            gen.writeEndObject();
            
            HttpResponse response = chamadaIntegracao(gen.getAsString(), 'Gerando_Proposta','POST');
                    
            if(response.getStatusCode() == 200){
                opp.VerificarCamposElaboracao__c = false;
                opp.PropostaGerada__c = true;
                result.attachmentUrl = saveExternalProposalAttachment(opp, response);
                if(String.isBlank(result.attachmentUrl)){
                    result.success = false;
                    result.message = 'Integração concluída, porém o anexo externo não foi criado.';
                    opp.SucessoIntegracaoNivello__c = false;
                } else {
                    result.success = true;
                    opp.SucessoIntegracaoNivello__c = true;
                    if(String.isBlank(result.message)){
                        result.message = 'Proposta enviada e anexo criado com sucesso.';
                    }
                }
            }else{ 
                opp.SucessoIntegracaoNivello__c = false;
                result.success = false;
                if(String.isBlank(result.message)){
                    result.message = buildIntegrationErrorMessage(response);
                }
            }
                    
            Utils.createLog('IntegracaoNivelloProposta', 'gerandoProposta ' + oppId, response);
                    
            opp.StatusBodyIntegracaoNivello__c = response.getStatusCode() + ' ' + response.getBody();
                    
            OpportunityTriggerHandler.disableTrigger();
            update opp;
            OpportunityTriggerHandler.enableTrigger();
        }catch(Exception e){
            Utils.createLog('IntegracaoNivelloProposta', 'gerandoProposta ' + oppId, e);
            if(captureResult){
                result.message = String.isNotBlank(e.getMessage()) ? e.getMessage() : 'Erro inesperado na integração.';
            }
        } finally {
            integrationInProgress.remove(cacheKey);
        }

        integrationCache.put(cacheKey, result);
        return result;
    }

    @future(callout=true)
    public static void finalizacaoProposta(Set<Id> triggerIds){
        Set<Id> contentDocumentIds = new Set<Id>();
        Map<Id, String> mapaArquivos64 = new Map<Id, String>();
        
        //Buscar os campos das Oportunidades a serem enviadas
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([
            SELECT  Id, IdVirtualOffice__c, LastModifiedDate
            FROM    Opportunity
            WHERE   Id IN :triggerIds
        ]);

        //Buscar o conteúdo dos arquivos - apenas a última versão dos mesmos
        List<ContentVersion> arquivos = [
            SELECT      Id, VersionData, FileType, FirstPublishLocationId
            FROM        ContentVersion 
            WHERE       FirstPublishLocationId IN :triggerIds AND
                        FileType = 'PDF'
            ORDER BY    CreatedDate DESC
            LIMIT       1
        ];
        
        //Montar o mapa contendo a chave Id da Oportunidade e o conteúdo base64 VersionData
        for(ContentVersion arquivo : arquivos){

            //Pegar apenas o primeiro arquivo, no caso de haver mais de um
            if(!mapaArquivos64.keySet().contains(arquivo.FirstPublishLocationId)){
                mapaArquivos64.put(arquivo.FirstPublishLocationId, EncodingUtil.base64Encode(arquivo.VersionData));
            }
        }

        for(Opportunity opp : oppMap.values()){

            //Garantir que há um arquivo a ser enviado
            if(mapaArquivos64.get(opp.Id) != null){

                FinalizacaoPropostaRequest corpoRequisicao = new FinalizacaoPropostaRequest();
                corpoRequisicao.id                 = opp.IdVirtualOffice__c;
                corpoRequisicao.proposta           = mapaArquivos64.get(opp.Id);
                
                String implementationDateAux = String.valueOf(opp.LastModifiedDate);
                implementationDateAux = implementationDateAux.replace(' ', 'T');
                implementationDateAux += '.' + opp.LastModifiedDate.millisecond() + 'Z';

                corpoRequisicao.implementationDate = implementationDateAux;
                HttpResponse response = chamadaIntegracao(JSON.serialize(corpoRequisicao), 'Finalizacao_Proposta','POST');

                
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
            }
        }
        OpportunityTriggerHandler.disableTrigger();
        update oppMap.values();
        OpportunityTriggerHandler.enableTrigger();
    }

    @future(callout=true)
    public static void sendUrlSimulation(Set<Id> opportunityIds) {
        // Buscar os campos das Oportunidades a serem enviadas
        List<Opportunity> oppList = [SELECT Id, IdVirtualOffice__c,URLSimulation__c FROM Opportunity WHERE Id IN :opportunityIds];

        for (Opportunity opp : oppList) {
            try {
                URLSimulationRequest request = new URLSimulationRequest();
                request.Id = opp.IdVirtualOffice__c;
                request.urlSimulation = opp.URLSimulation__c;

                HttpResponse res = chamadaIntegracao(JSON.serialize(request), 'Envia_URLSimulacao','PATCH');

                // Handle the response
                if (res.getStatusCode() == 200) {
                    //System.debug('Request successful');
                    Utils.createLog('IntegracaoNivelloProposta', 'sendUrlSimulation ' + opp.Id, res);
                } else {
                    Utils.createLog('IntegracaoNivelloProposta', 'sendUrlSimulation failed ' + opp.Id, res);
                    //System.debug('Request failed: ' + res.getStatus());
                }
            }catch (Exception e) {
                Utils.createLog('IntegracaoNivelloProposta', 'Exception in sendUrlSimulation ' + opp.Id, e.getMessage());
            }
        }
    }

    private static HttpResponse chamadaIntegracao(String body, String integracaoProposta, String method){
        Integrador__mdt parametrosIntegracao = [
            SELECT  Id, URL__c
            FROM    Integrador__mdt 
            WHERE   DeveloperName = :integracaoProposta
        ];

        Http httpObj = new Http();
        HttpRequest request = new HttpRequest();
        
        System.debug('parametrosIntegracao');
        System.debug(parametrosIntegracao.URL__c);
        System.debug(body);
        request.setEndpoint(parametrosIntegracao.URL__c);
        request.setMethod(method);
        request.setTimeout(120000);
        request.setHeader('Content-Type', 'application/json');
        request.setBody(body);

        return Utils.callIntegrationNivello(request);
    }

    /*public static integer getStatusEnum(String stageName){
        if(stageName == OpportunityUtils.STATUS_ELABORACAO_DE_PROPOSTA){
            return 4;
        }else if (  stageName == OpportunityUtils.STATUS_AGENDAMENTO_DA_VISITA_TECNICA || 
                    stageName == OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE){
            return 6;
        }else if(stageName == OpportunityUtils.STATUS_READEQUACAO_DE_PROPOSTA){
            return 7;
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
        }else if(stageName == OpportunityUtils.STATUS_CONTRATO_ENVIADO){
            return 7;
        }else if(stageName == OpportunityUtils.STATUS_CONTRATO_FIRMADO_ASSINADO){
            return 4;
        }else{
            return 0;
        }
    }*/

    public class ProposalIntegrationResult{
        public Boolean success = false;
        public Integer statusCode;
        public String message;
        public String responseBody;
        public String attachmentUrl;
    }

    public class GerandoPropostaRequest{
        public Boolean approved;            //	true
        public String  id;		        	//	"3fa85f64-5717-4562-b3fc-2c963f66afa6"
        public String  description;         //  "string"
        public String  contract;            //  Blob da proposta. O nome é "contract" mesmo pois a API foi criada assim
    }

    public class FinalizacaoPropostaRequest{
        public String  id;		        	//	"3fa85f64-5717-4562-b3fc-2c963f66afa6"
        public String  implementationDate;  //	"2022-06-09T00:19:29.477Z"
        public String  proposta;            //  Blob da proposta
    }

    public class URLSimulationRequest {
        public String Id { get; set; }
        public String urlSimulation { get; set; }
    }
    
    private static String saveExternalProposalAttachment(Opportunity opp, HttpResponse response){
        if(opp == null || response == null || String.isBlank(response.getBody())){
            return null;
        }

        try{
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            if(body == null){
                return null;
            }
            if(body.containsKey('data') && body.get('data') instanceof Map<String, Object>){
                body = (Map<String, Object>) body.get('data');
            }

            String attachmentUrl = getFirstString(body, new List<String>{
                'attachmentUrl', 'urlAttachment', 'attachment_url', 'url', 'urlFile'
            });

            if(String.isBlank(attachmentUrl)){
                return null;
            }

            String attachmentDescription = getFirstString(body, new List<String>{
                'attachmentDescription', 'description', 'fileName', 'nome'
            });
            String attachmentExternalId = getFirstString(body, new List<String>{
                'attachmentExternalId', 'externalId', 'id'
            });

            OpportunityAttachmentLinkService.AttachmentInput input =
                new OpportunityAttachmentLinkService.AttachmentInput();
            input.opportunityId = opp.Id;
            input.attachmentUrl = attachmentUrl;
            input.description = String.isNotBlank(attachmentDescription)
                ? attachmentDescription
                : 'Proposta ' + opp.Name;
            input.externalId = attachmentExternalId;
            input.type = 'Proposal';

            OpportunityAttachmentLinkService.upsertAttachment(input);
            return attachmentUrl;
        } catch (Exception ex){
            Utils.createLog('IntegracaoNivelloProposta', 'saveExternalProposalAttachment', ex);
            return null;
        }
    }

    private static String getFirstString(Map<String, Object> data, List<String> keys){
        if(data == null || keys == null){
            return null;
        }
        for(String key : keys){
            if(data.containsKey(key)){
                Object value = data.get(key);
                if(value instanceof String && !String.isBlank((String)value)){
                    return (String)value;
                }
            }
        }
        return null;
    }

    private static String buildIntegrationErrorMessage(HttpResponse response){
        if(response == null){
            return 'Falha na integração da proposta.';
        }
        String body = response.getBody();
        String status = String.valueOf(response.getStatusCode());
        if(String.isNotBlank(body)){
            return 'Falha na integração: ' + status + ' - ' + body;
        }
        return 'Falha na integração: ' + status;
    }

    private static void handleContractTooLarge(Opportunity opp, ProposalIntegrationResult result){
        result.success = false;
        result.message = 'O arquivo da proposta excede o limite suportado pelo Salesforce (aprox. 4,5 MB) e não pode ser enviado.';
        result.statusCode = null;
        result.responseBody = result.message;
        opp.SucessoIntegracaoNivello__c = false;
        opp.StatusBodyIntegracaoNivello__c = result.message;
        try{
            OpportunityTriggerHandler.disableTrigger();
            update opp;
        } catch(Exception e){
            Utils.createLog('IntegracaoNivelloProposta', 'handleContractTooLarge', e);
        } finally {
            OpportunityTriggerHandler.enableTrigger();
        }
    }

    private static Boolean isMaxStringSizeException(Exception ex){
        return ex instanceof System.StringException
            && ex.getMessage() != null
            && ex.getMessage().contains('String length exceeds maximum');
    }
}
