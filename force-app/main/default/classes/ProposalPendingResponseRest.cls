@RestResource(urlMapping='/ProposalPendingResponse/*')
global with sharing class ProposalPendingResponseRest {

    @HttpPost
    global static ResponseWrapper handleResponse() {
        RestRequest request = RestContext.request;
        ResponseWrapper responseWrapper = new ResponseWrapper();

        try{
            if(request == null || request.requestBody == null){
                throw new PendingApiException('Corpo da requisição não encontrado.');
            }

            ResponsePayload payload = (ResponsePayload) JSON.deserialize(request.requestBody.toString(), ResponsePayload.class);
            validatePayload(payload);

            ProposalPending__c pending = [
                SELECT  Id,
                        Name,
                        Status__c,
                        Opportunity__c,
                        Opportunity__r.OwnerId,
                        Opportunity__r.IdVirtualOffice__c
                FROM    ProposalPending__c
                WHERE   Id = :payload.PendingId
                AND     Opportunity__r.IdVirtualOffice__c = :payload.ProposalId
                LIMIT 1
            ];

            pending.Response__c     = payload.Response;
            pending.FileUrl__c      = payload.UrlArquivo;
            pending.RespondedDate__c= System.now();
            pending.Status__c       = payload.Status != null
                ? EzeeConnectProposalPendingService.getStatusLabel(payload.Status)
                : 'Respondido';

            update pending;

            notifyOwner(pending);

            responseWrapper.success = true;
            responseWrapper.message = 'Pendência atualizada com sucesso.';
            RestContext.response.statusCode = 200;

        } catch(QueryException qe){
            RestContext.response.statusCode = 404;
            responseWrapper.success = false;
            responseWrapper.message = 'Pendência não encontrada para a proposta informada.';
            Utils.createLog('ProposalPendingResponseRest', 'handleResponse - not found', qe.getMessage());
        } catch(PendingApiException pae){
            RestContext.response.statusCode = 400;
            responseWrapper.success = false;
            responseWrapper.message = pae.getMessage();
            Utils.createLog('ProposalPendingResponseRest', 'handleResponse - validation', pae.getMessage());
        } catch(AuraHandledException ahe){
            RestContext.response.statusCode = 400;
            responseWrapper.success = false;
            responseWrapper.message = ahe.getMessage();
            Utils.createLog('ProposalPendingResponseRest', 'handleResponse - business', ahe.getMessage());
        } catch(Exception e){
            RestContext.response.statusCode = 500;
            responseWrapper.success = false;
            responseWrapper.message = 'Erro interno ao atualizar a pendência.';
            Utils.createLog('ProposalPendingResponseRest', 'handleResponse - exception', e);
        }

        return responseWrapper;
    }

    private static void validatePayload(ResponsePayload payload){
        if(payload == null){
            throw new PendingApiException('JSON inválido.');
        }

        if(String.isBlank(payload.ProposalId)){
            throw new PendingApiException('O campo proposalId é obrigatório.');
        }

        if(String.isBlank(payload.PendingId)){
            throw new PendingApiException('O campo pendingId é obrigatório.');
        }
    }

    private static void notifyOwner(ProposalPending__c pending){
        if(pending.Opportunity__r == null || String.isBlank(String.valueOf(pending.Opportunity__r.OwnerId))){
            return;
        }

        try{
            String message = 'A pendência ' + pending.Name + ' foi respondida pelo aplicativo.';
            Utils.notificacaoPersonalizada(
                message,
                'Pendência respondida',
                pending.Opportunity__r.OwnerId,
                pending.Opportunity__c
            );
        } catch (Exception e){
            Utils.createLog('ProposalPendingResponseRest', 'notifyOwner', e);
        }
    }

    global class ResponsePayload {
        public String ProposalId {get; set;}
        public String Description {get; set;}
        public Integer DocumentType {get; set;}
        public Integer Status {get; set;}
        public String PendingId {get; set;}
        public String Response {get; set;}
        public String UrlArquivo {get; set;}
    }

    global class ResponseWrapper {
        public Boolean success {get; set;}
        public String message {get; set;}
    }

    public class PendingApiException extends Exception {}
}
